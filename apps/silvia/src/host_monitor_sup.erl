-module(host_monitor_sup).
-behaviour(supervisor).

-include_lib("kernel/include/logger.hrl").

-export([start_link/0, start_monitors/1, start_child/1, get_host_statuses/0, get_host_status/1]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_child(HostSpec) ->
    HostName = element(1, HostSpec),
    ChildSpec = #{
        id => {host_monitor_gs, HostName},
        start => {host_monitor_gs, start_link, [HostSpec]},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [host_monitor_gs]
    },
    supervisor:start_child(?MODULE, ChildSpec).

start_monitors(Hosts) ->
    [start_host_monitor(HostSpec) || HostSpec <- Hosts],
    ok.

get_host_statuses() ->
    Children = supervisor:which_children(?MODULE),
    maps:from_list([
        {HostName, get_status_from_pid(Pid)}
     || {{host_monitor_gs, HostName}, Pid, worker, _} <- Children,
        is_pid(Pid)
    ]).

get_host_status(HostName) ->
    case find_host_pid(HostName, supervisor:which_children(?MODULE)) of
        {ok, Pid} ->
            {ok, get_status_from_pid(Pid)};
        error ->
            {error, host_not_found}
    end.

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    {ok, {SupFlags, []}}.

find_host_pid(HostName, [{{host_monitor_gs, HostName}, Pid, worker, _} | _]) when is_pid(Pid) ->
    {ok, Pid};
find_host_pid(HostName, [_ | Rest]) ->
    find_host_pid(HostName, Rest);
find_host_pid(_HostName, []) ->
    error.

get_status_from_pid(Pid) ->
    try
        gen_server:call(Pid, get_status)
    catch
        _:_ -> unknown
    end.

start_host_monitor({HostName, _} = HostSpec) ->
    case start_child(HostSpec) of
        {ok, _Pid} ->
            ok;
        {error, Reason} ->
            ?LOG_ERROR("failed to start host monitor ~p: ~p", [HostName, Reason]),
            error
    end.
