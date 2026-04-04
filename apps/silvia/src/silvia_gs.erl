-module(silvia_gs).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

%% Callbacks for `gen_server`
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, start_link/1]).

start_link(Args) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Args, []).

init(Args) ->
    Hosts = maps:get(hosts, Args, []),
    {HostMonitors, InitialStatuses} = start_host_monitors(Hosts),
    {ok, Args#{
        host_monitors => HostMonitors,
        host_statuses => InitialStatuses
    }}.

handle_call(get_app_id, _From, State) ->
    Response = maps:get(app_id, State),
    {reply, Response, State};
handle_call(get_bot_token, _From, State) ->
    Response = maps:get(bot_token, State),
    {reply, Response, State};
handle_call(get_host_statuses, _From, State) ->
    {reply, maps:get(host_statuses, State, #{}), State};
handle_call({get_host_status, HostName}, _From, State) ->
    Monitors = maps:get(host_monitors, State, #{}),
    case maps:get(HostName, Monitors, undefined) of
        undefined ->
            {reply, {error, host_not_found}, State};
        Pid ->
            Status = gen_server:call(Pid, get_status),
            {reply, {ok, Status}, State}
    end;
handle_call(_Request, _From, State) ->
    {reply, not_implemented, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info({host_status_changed, HostName, NewStatus}, State) ->
    HostStatuses = maps:get(host_statuses, State, #{}),
    PrevStatus = maps:get(HostName, HostStatuses, unknown),
    NewHostStatuses = maps:put(HostName, NewStatus, HostStatuses),
    silvia_alerts:handle_host_transition(HostName, PrevStatus, NewStatus),
    {noreply, State#{host_statuses => NewHostStatuses}};
handle_info(_Info, State) ->
    {noreply, State}.

start_host_monitors(Hosts) ->
    lists:foldl(
      fun(HostSpec = {HostName, _}, {AccMonitors, AccStatuses}) ->
          case host_monitor_sup:start_child(HostSpec, self()) of
              {ok, Pid} ->
                  {
                      maps:put(HostName, Pid, AccMonitors),
                      maps:put(HostName, unknown, AccStatuses)
                  };
              {error, Reason} ->
                  ?LOG_ERROR("failed to start host monitor ~p: ~p", [HostName, Reason]),
                  {
                      AccMonitors,
                      maps:put(HostName, error, AccStatuses)
                  }
          end
      end,
      {#{}, #{}},
      Hosts
    ).

