-module(host_monitor_gs).
-behaviour(gen_server).

-export([start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(DEFAULT_CHECK_INTERVAL_MS, 10000).

start_link(HostSpec, NotifyPid) ->
    gen_server:start_link(?MODULE, {HostSpec, NotifyPid}, []).

init({{HostName, {HostIp, HostPort}}, NotifyPid}) ->
    State = #{
        name => HostName,
        ip => HostIp,
        notify_pid => NotifyPid,
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
    NotifyPid = maps:get(notify_pid, State),
    HostName = maps:get(name, State),
    maybe_notify_transition(NotifyPid, HostName, PrevStatus, NewStatus),
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

maybe_notify_transition(NotifyPid, HostName, PrevStatus, NewStatus) ->
    case {PrevStatus, NewStatus} of
        {unknown, _} ->
            NotifyPid ! {host_status_changed, HostName, NewStatus};
        {Prev, New} when Prev =/= New ->
            NotifyPid ! {host_status_changed, HostName, NewStatus};
        _ ->
            ok
    end.
