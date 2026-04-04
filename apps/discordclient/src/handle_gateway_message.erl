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

% HELLO event
internal_parse(StatemPid, StatemData, #{<<"op">> := 10, <<"d">> := #{<<"heartbeat_interval">> := HBInterval}}) ->
    ?LOG_INFO("HELLO event received, with heartbeat interval: ~p", [HBInterval]),
    SeqOrNull = maps:get(last_seq, StatemData, null),
    Payload = #{op=>1, d=>SeqOrNull},
    JsonPayload = jsx:encode(Payload),
    gen_statem:cast(StatemPid, {send_heartbeat, HBInterval, JsonPayload}),
    ok; 
internal_parse(StatemPid, StatemData, #{<<"op">> := 11}) ->
    ?LOG_INFO("HEARTBEART ACK event received"),
    SeqOrNull = maps:get(last_seq, StatemData, null),
    Payload = #{op=>1, d=>SeqOrNull},
    JsonPayload = jsx:encode(Payload),
    gen_statem:cast(StatemPid, {send_heartbeat, JsonPayload}),
    ok;
internal_parse(StatemPid, _StatemData, #{<<"s">> := Seq}) when is_integer(Seq) ->
    gen_statem:cast(StatemPid, {update_last_seq, Seq}),
    ok;
internal_parse(StatemPid, StatemData, Msg) ->
    ?LOG_WARNING("unexpected message to parse: ~p", [Msg]),
    ok.
