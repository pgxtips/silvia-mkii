-module(silvia_gs).
-behaviour(gen_server).

%% Callbacks for `gen_server`
-export([init/1, handle_call/3, handle_cast/2, start_link/1]).

start_link(Args) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Args, []).

init(Args) ->
    {ok, Args}.

handle_call(get_app_id,From,State) ->
    Response = maps:get(app_id, State),
    {reply, Response, State};
handle_call(get_bot_token,From,State) ->
    Response = maps:get(bot_token, State),
    {reply, Response, State};
handle_call(Request,From,State) ->
    {reply, not_implemented, State}.

handle_cast(Request,State) ->
    erlang:error(not_implemented).


