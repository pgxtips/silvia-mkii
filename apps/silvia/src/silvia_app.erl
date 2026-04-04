%%%-------------------------------------------------------------------
%% @doc silvia public API
%% @end
%%%-------------------------------------------------------------------
-module(silvia_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    DiscordBotToken = os:getenv("DISCORD_BOT_TOKEN"),
    discordclient:start_link(#{bot_token=>DiscordBotToken}),
    silvia_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
