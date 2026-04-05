-module(host_monitor_gs).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(DEFAULT_CHECK_INTERVAL_MS, 10000).

start_link(HostSpec) ->
    gen_server:start_link(?MODULE, HostSpec, []).

init({HostName, {HostIp, _HostPort}}) ->
    State = #{
        name => HostName,
        ip => HostIp,
        check_interval_ms => ?DEFAULT_CHECK_INTERVAL_MS,
        status => unknown
    },
    self() ! check_liveness,
    {ok, State}.

handle_call(get_status, _From, State) ->
    {reply, maps:get(status, State, unknown), State};
handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(check_liveness, State) ->
    HostIp = maps:get(ip, State),
    PrevStatus = maps:get(status, State),
    NewStatus = check_host(HostIp),
    HostName = maps:get(name, State),
    maybe_alert_transition(HostName, PrevStatus, NewStatus),
    IntervalMs = maps:get(check_interval_ms, State),
    erlang:send_after(IntervalMs, self(), check_liveness),
    {noreply, State#{status => NewStatus}};
handle_info(_Info, State) ->
    {noreply, State}.

check_host(HostIp) ->
    Cmd = "ping -c 1 -W 1 " ++ HostIp ++ " >/dev/null 2>&1 ; echo $?",
    case string:trim(os:cmd(Cmd)) of
        "0" -> up;
        _ -> down
    end.

maybe_alert_transition(HostName, PrevStatus, NewStatus) ->
    case {PrevStatus, NewStatus} of
        {unknown, up} ->
            gen_server:cast(alert_gs, {send_alert, {info, host_up_message(HostName)}});
        {unknown, down} ->
            gen_server:cast(alert_gs, {send_alert, {critical, host_down_message(HostName)}});
        {down, up} ->
            gen_server:cast(alert_gs, {send_alert, {recovery, host_recovered_message(HostName)}});
        {Prev, New} when Prev =/= New ->
            gen_server:cast(alert_gs, {send_alert, {critical, host_transition_message(HostName, Prev, New)}});
        _ ->
            ok
    end.

host_up_message(HostName) ->
    lists:flatten(io_lib:format("host ~p is UP", [HostName])).

host_down_message(HostName) ->
    lists:flatten(io_lib:format("host ~p is DOWN", [HostName])).

host_recovered_message(HostName) ->
    lists:flatten(io_lib:format("host ~p recovered (UP)", [HostName])).

host_transition_message(HostName, Prev, New) ->
    lists:flatten(io_lib:format("host ~p transition: ~p -> ~p", [HostName, Prev, New])).
