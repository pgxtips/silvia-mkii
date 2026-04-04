-module(host_monitor_sup).
-behaviour(supervisor).

-export([start_link/0, start_child/2]).
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_child(HostSpec, NotifyPid) ->
    HostName = element(1, HostSpec),
    ChildSpec = #{
        id => {host_monitor_gs, HostName},
        start => {host_monitor_gs, start_link, [HostSpec, NotifyPid]},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [host_monitor_gs]
    },
    supervisor:start_child(?MODULE, ChildSpec).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},
    {ok, {SupFlags, []}}.
