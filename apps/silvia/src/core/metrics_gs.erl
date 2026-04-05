-module(metrics_gs).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(DEFAULT_POLL_MS, 15000).

start_link(Args) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Args, []).

init(Args) ->
    PollMs = maps:get(metric_poll_interval_ms, Args, ?DEFAULT_POLL_MS),
    MetricModules = maps:get(metric_modules, Args, [prometheus_host_oper_status_metric]),
    AlertModules = maps:get(alert_modules, Args, [#{module => host_oper_status_alert, config => #{}}]),
    State = #{
        poll_ms => PollMs,
        metric_modules => MetricModules,
        alert_modules => AlertModules,
        alert_states => #{}
    },
    self() ! poll_metrics,
    {ok, State}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(poll_metrics, State0) ->
    State1 = poll_all_metrics(State0),
    PollMs = maps:get(poll_ms, State1),
    erlang:send_after(PollMs, self(), poll_metrics),
    {noreply, State1};
handle_info(_Info, State) ->
    {noreply, State}.

poll_all_metrics(State0) ->
    MetricModules = maps:get(metric_modules, State0),
    lists:foldl(fun poll_metric/2, State0, MetricModules).

poll_metric(MetricMod, AccState) when is_atom(MetricMod) ->
    case MetricMod:fetch(#{} ) of
        {ok, #{metric_id := MetricId, points := Points}} ->
            evaluate_alerts(MetricId, Points, AccState);
        {error, Reason} ->
            ?LOG_ERROR("metric fetch failed (~p): ~p", [MetricMod, Reason]),
            AccState
    end;
poll_metric(Invalid, AccState) ->
    ?LOG_WARNING("invalid metric module entry: ~p", [Invalid]),
    AccState.

evaluate_alerts(MetricId, Points, State0) ->
    AlertModules = maps:get(alert_modules, State0),
    lists:foldl(
      fun(AlertSpec, AccState) ->
          evaluate_alert(MetricId, Points, AlertSpec, AccState)
      end,
      State0,
      AlertModules
    ).

evaluate_alert(MetricId, Points, #{module := AlertMod, config := AlertCfg}, State0) ->
    case AlertMod:metric_id() =:= MetricId of
        false ->
            State0;
        true ->
            AlertStates = maps:get(alert_states, State0),
            PrevState = maps:get(AlertMod, AlertStates, #{}),
            case AlertMod:eval(Points, PrevState, AlertCfg) of
                {ok, NextState, Alerts} ->
                    _ = emit_alerts(Alerts),
                    State0#{alert_states => maps:put(AlertMod, NextState, AlertStates)};
                {error, Reason} ->
                    ?LOG_ERROR("alert eval failed (~p): ~p", [AlertMod, Reason]),
                    State0
            end
    end;
evaluate_alert(_MetricId, _Points, Invalid, State0) ->
    ?LOG_WARNING("invalid alert module entry: ~p", [Invalid]),
    State0.

emit_alerts(Alerts) ->
    lists:foreach(
      fun(#{severity := Severity, message := Message}) ->
          gen_server:cast(alert_gs, {send_alert, {Severity, Message}});
         (_) ->
          ok
      end,
      Alerts
    ),
    ok.
