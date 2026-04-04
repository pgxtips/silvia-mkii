-module(handle_gateway_message).
-include_lib("kernel/include/logger.hrl").
-export([parse/3]).

-spec parse(StatemPid :: pid(), StatemData :: term(), Msg :: string()) -> term().
parse(StatemPid, StatemData, Msg) when is_list(Msg) ->
    MapData = jsx:decode(list_to_binary(Msg)),
    internal_parse(StatemPid, StatemData, MapData);
parse(StatemPid, StatemData, Msg) when is_binary(Msg) ->
    MapData = jsx:decode(Msg),
    internal_parse(StatemPid, StatemData, MapData).

% INTERACTION_CREATE event
internal_parse(StatemPid, _StatemData, #{<<"op">> := 0, <<"t">> := <<"INTERACTION_CREATE">>, <<"d">>
:= InteractionData}) ->
    gen_statem:cast(StatemPid, {dispatch_event, interaction_create, InteractionData}),
    ok;
% RECONNECT event
internal_parse(StatemPid, _StatemData, #{<<"op">> := 7}) ->
    gen_statem:cast(StatemPid, {gateway_reconnect}),
    ok;
% INVALID SESSION event
internal_parse(StatemPid, StatemData, #{<<"op">> := 9, <<"d">> := IsInvalid }) ->
    gen_statem:cast(StatemPid, {invalid_session, IsInvalid}),
    ok;
% HELLO event
internal_parse(StatemPid, StatemData, #{<<"op">> := 10, <<"d">> := #{<<"heartbeat_interval">> := HBInterval}}) ->
    ?LOG_INFO("HELLO event received, with heartbeat interval: ~p", [HBInterval]),
    SeqOrNull = maps:get(last_seq, StatemData, null),
    BotToken = maps:get(bot_token, StatemData, undefined),

    HeartbeatPayload = #{op=>1, d=>SeqOrNull},
    JsonHeartbeatPayload = jsx:encode(HeartbeatPayload),

    IdentifyPayload = #{op=>2, d=>#{
        token=>list_to_binary(BotToken),
        intents=>513,
        properties=> #{
                <<"$os">> => <<"linux">>,
                <<"$browser">> => <<"discordclient">>,
                <<"$device">> => <<"discordclient">>
        }
    }},
    JsonIdentifyPayload = jsx:encode(IdentifyPayload),

    gen_statem:cast(StatemPid, {send_heartbeat, HBInterval, JsonHeartbeatPayload}),
    gen_statem:cast(StatemPid, {send_payload, JsonIdentifyPayload}),
    ok; 
% HEARTBEAT ACK EVENT
internal_parse(StatemPid, StatemData, #{<<"op">> := 11}) ->
    ?LOG_INFO("HEARTBEAT ACK event received"),
    SeqOrNull = maps:get(last_seq, StatemData, null),
    Payload = #{op=>1, d=>SeqOrNull},
    JsonPayload = jsx:encode(Payload),
    gen_statem:cast(StatemPid, {send_heartbeat, JsonPayload}),
    ok;
% READY EVENT
internal_parse(StatemPid, _StatemData, #{<<"op">> := 0, <<"t">> := <<"READY">>, <<"d">> := ReadyData}) ->
    gen_statem:cast(StatemPid, {ready, ReadyData}),
    ok;
internal_parse(StatemPid, _StatemData, #{<<"s">> := Seq}) when is_integer(Seq) ->
    gen_statem:cast(StatemPid, {update_last_seq, Seq}),
    ok;
internal_parse(StatemPid, StatemData, Msg) ->
    ?LOG_WARNING("unexpected message to parse: ~p", [Msg]),
    ok.
