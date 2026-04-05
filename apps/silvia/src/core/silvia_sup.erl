%%%-------------------------------------------------------------------
%% @doc silvia top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(silvia_sup).

-behaviour(supervisor).

-include_lib("kernel/include/logger.hrl").

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    FileConfig = load_silvia_config("config/silvia.config"),
    LoggerLevel = maps:get(log_level, FileConfig),
    logger:set_primary_config(level, LoggerLevel),

    AppId = os:getenv("DISCORD_APP_ID"),
    DiscordBotToken = os:getenv("DISCORD_BOT_TOKEN"),
    OptsMap0 = #{
        app_id=>AppId,
        bot_token=>DiscordBotToken,
        event_handler=>{event_handler, handle_event},
        metric_modules=>[prometheus_host_oper_status_metric],
        alert_modules=>[#{module => host_oper_status_alert, config => #{}}]
    },
    OptsMap = maps:merge(OptsMap0, FileConfig),

    SupFlags = #{strategy => one_for_all,
                 intensity => 0,
                 period => 1},
    ChildSpecs = [
        #{id => discordclient,
        start => {discordclient, start_link, [OptsMap]},
        restart => permanent,  
        type => worker,
        modules => [discordclient]},

        #{id => alert_gs,
        start => {alert_gs, start_link, []},
        restart => permanent,
        type => worker,
        modules => [alert_gs]},

        #{id => metrics_gs,
        start => {metrics_gs, start_link, [OptsMap]},
        restart => permanent,
        type => worker,
        modules => [metrics_gs]},

        #{id => silvia_gs,
        start => {silvia_gs, start_link, [OptsMap]},
        restart => permanent,  
        type => worker,
        modules => [silvia_gs]}
    ],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
load_silvia_config(Path) ->
    case file:consult(Path) of
        {ok, Terms} when is_list(Terms) ->
            maps:from_list(Terms);
        {error, Reason} ->
            ?LOG_ERROR("failed to load silvia config ~s: ~p", [Path, Reason]),
            #{}
    end.
