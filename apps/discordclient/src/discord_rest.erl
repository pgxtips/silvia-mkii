-module(discord_rest).

-include_lib("kernel/include/logger.hrl").

-export([register_guild_command/4, interaction_callback/3, create_channel_message/3]).

-define(DISCORD_API_BASE, "https://discord.com/api/v10").

%% ===================
%% public api 
%% ===================
-spec register_guild_command(string(), string(), string(), map()) -> {ok, map()} | {error, term()}.
register_guild_command(AppId, BotToken, GuildId, CommandDef) ->
    ?LOG_DEBUG("AppId: ~p, BotToken: ~p", [AppId, BotToken]),
    URL = ?DISCORD_API_BASE ++
        "/applications/" ++ AppId ++
        "/guilds/" ++ GuildId ++
        "/commands",
    Headers = [
        {"Authorization", "Bot " ++ BotToken},
        {"Content-Type", "application/json"}
    ],
    ?LOG_DEBUG("POST ~s headers=~p payload=~p", [URL, Headers, CommandDef]),
    Response = post_json(URL, Headers, CommandDef),
    ?LOG_DEBUG("Response: ~p", [Response]),
    Response.

-spec interaction_callback(string(), string(), map()) -> {ok, map()} | {error, term()}.
interaction_callback(InteractionId, InteractionToken, CallbackPayload) ->
    URL = ?DISCORD_API_BASE ++
    "/interactions/" ++ InteractionId ++
    "/" ++ InteractionToken ++
    "/callback",
    Headers = [{"Content-Type", "application/json"}],
    post_json(URL, Headers, CallbackPayload).

-spec create_channel_message(string(), string(), binary() | string()) -> {ok, map()} | {error, term()}.
create_channel_message(ChannelId, BotToken, Content) ->
    URL = ?DISCORD_API_BASE ++ "/channels/" ++ ChannelId ++ "/messages",
    Headers = [
        {"Authorization", "Bot " ++ BotToken},
        {"Content-Type", "application/json"}
    ],
    Payload = #{content => to_bin(Content)},
    post_json(URL, Headers, Payload).


%% ===================
%% private functions
%% ===================
post_json(URL, Headers, Payload) ->
    _ = application:ensure_all_started(inets),
    _ = application:ensure_all_started(ssl),
    Body = jsx:encode(Payload),
    Request = {URL, Headers, "application/json", Body},
    HttpOpts = [{ssl, [{verify, verify_none}]}, {timeout, 10000}],
    case httpc:request(post, Request, HttpOpts, []) of
        {ok, {{_, Status, _}, _RespHeaders, RespBody}} when Status >= 200, Status < 300 ->
            decode_success(RespBody);
        {ok, {{_, Status, _}, _RespHeaders, RespBody}} ->
            {error, {http_error, Status, iolist_to_binary(RespBody)}};
        {error, Reason} ->
            {error, Reason}
    end.

decode_success(RespBody) ->
    RespBin = iolist_to_binary(RespBody),
    case RespBin of
        <<>> -> {ok, #{}};
        _ -> {ok, jsx:decode(RespBin)}
    end.

to_bin(Value) when is_binary(Value) -> Value;
to_bin(Value) when is_list(Value) -> list_to_binary(Value).
