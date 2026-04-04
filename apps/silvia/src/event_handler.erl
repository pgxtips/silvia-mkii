-module(event_handler).

-include_lib("kernel/include/logger.hrl").

-export([handle_event/2]).

handle_event(interaction_create, InteractionMap) ->
    ?LOG_DEBUG("Interaction data: ~p", [InteractionMap]),
    Name = maps:get(command_name, InteractionMap),
    InteractionId = binary_to_list(maps:get(interaction_id, InteractionMap)),
    InteractionToken = binary_to_list(maps:get(interaction_token, InteractionMap)),
    case Name of
        <<"ping">> ->
            Payload = "Pong!",
            discordclient:interaction_reply_message(InteractionId, InteractionToken, Payload),
            ok;
        _ ->
            ok
    end;
handle_event(guild_create, GuildData) ->
    GuildId = binary_to_list(maps:get(<<"id">>, GuildData)),
    GuildName = maps:get(<<"name">>, GuildData, <<"unknown">>),
    ?LOG_INFO("guild_create: ~s (~s)", [GuildName, GuildId]),
    AppId = gen_server:call(silvia_gs, get_app_id),
    BotToken = gen_server:call(silvia_gs, get_bot_token),
    reg_events:register_events(AppId, BotToken, GuildId),

    event_undefined.
