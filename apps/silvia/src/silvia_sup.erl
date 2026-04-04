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
    AppId = os:getenv("DISCORD_APP_ID"),
    DiscordBotToken = os:getenv("DISCORD_BOT_TOKEN"),
    ?LOG_INFO("app_id=~p bot_token_prefix=~p",
              [AppId, lists:sublist(DiscordBotToken, 8)]),
    OptsMap = #{
        app_id=>AppId,
        bot_token=>DiscordBotToken,
        event_handler=>{event_handler, handle_event}
    },

    SupFlags = #{strategy => one_for_all,
                 intensity => 0,
                 period => 1},
    ChildSpecs = [
        #{id => discordclient,
        start => {discordclient, start_link, [OptsMap]},
        restart => permanent,  
        type => worker,
        modules => [discordclient]},

        #{id => silvia_gs,
        start => {silvia_gs, start_link, [OptsMap]},
        restart => permanent,  
        type => worker,
        modules => [silvia_gs]}
    ],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
