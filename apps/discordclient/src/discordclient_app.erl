%%%-------------------------------------------------------------------
%% @doc discordclient public API
%% @end
%%%-------------------------------------------------------------------

-module(discordclient_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    ssl:start(),
    {ok, _} = application:ensure_all_started(gun),
    discordclient_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
