-module(silvia_gs).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

%% Callbacks for `gen_server`
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, start_link/1]).

start_link(Args) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Args, []).

init(Args) ->
    Hosts = maps:get(hosts, Args, []),
    ok = host_monitor_sup:start_monitors(Hosts),
    {ok, Args}.

handle_call(get_app_id, _From, State) ->
    Response = maps:get(app_id, State),
    {reply, Response, State};
handle_call(get_bot_token, _From, State) ->
    Response = maps:get(bot_token, State),
    {reply, Response, State};
handle_call(get_alert_channels, _From, State) ->
    Response = maps:get(alert_channels, State, #{}),
    {reply, Response, State};
handle_call(get_host_statuses, _From, State) ->
    {reply, host_monitor_sup:get_host_statuses(), State};
handle_call({get_host_status, HostName}, _From, State) ->
    {reply, host_monitor_sup:get_host_status(HostName), State};
handle_call(_Request, _From, State) ->
    {reply, not_implemented, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.
