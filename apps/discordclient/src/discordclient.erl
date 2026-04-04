-module(discordclient).

-include_lib("kernel/include/logger.hrl").

-export([start_link/1, stop/0, register_guild_command/4, interaction_callback/3, interaction_reply_message/3]).

%% Opts example:
%% #{bot_token => "...", event_handler => {silvia_gateway_handler, []}}
-spec start_link(OptsMap :: map()) -> term().
start_link(OptsMap) ->
    gateway_statem:start_link(OptsMap).

stop() ->
    gen_statem:stop(gateway_statem).


-spec register_guild_command(string(), string(), string(), map()) -> {ok, map()} | {error, term()}.
register_guild_command(AppId, BotToken, GuildId, CommandDef) ->
    ?LOG_DEBUG("registering guild command: ~p ~p - ~p", [AppId, GuildId, CommandDef]),
    case whereis(gateway_statem) of
        undefined ->
            ?LOG_DEBUG("error finding statem"),
            {error, not_started};
        _Pid ->
            %% token already supplied at start_link
            ?LOG_DEBUG("found statem, register_guild_command"),
            discord_rest:register_guild_command(AppId, BotToken, GuildId, CommandDef)
    end.

-spec interaction_callback(string(), string(), map()) -> {ok, map()} | {error, term()}.
interaction_callback(InteractionId, InteractionToken, Payload) ->
    discord_rest:interaction_callback(InteractionId, InteractionToken, Payload).

interaction_reply_message(InteractionId, InteractionToken, Payload) ->
    ReplyPayload = #{
        type => 4,
        data => #{content => to_bin(Payload)} 
    },
    ?LOG_INFO("Interacton reply (~p): ~p", [InteractionId, Payload]),
    discord_rest:interaction_callback(InteractionId, InteractionToken, ReplyPayload).

to_bin(Payload) when is_binary(Payload) -> Payload;
to_bin(Payload) when is_list(Payload) -> list_to_binary(Payload).
