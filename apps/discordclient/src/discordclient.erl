-module(discordclient).

-export([start_link/1, stop/0]).

%% Opts example:
%% #{bot_token => "...", event_handler => {silvia_gateway_handler, []}}
-spec start_link(OptsMap :: map()) -> term().
start_link(OptsMap) ->
    gateway_statem:start_link(OptsMap).

stop() ->
    gen_statem:stop(gateway_statem).

