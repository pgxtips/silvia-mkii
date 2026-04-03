-module(handle_gateway_message).
-include_lib("kernel/include/logger.hrl").
-export([parse/2]).

-spec parse(StatemPid :: pid(), Msg :: string()) -> term().
parse(StatemPid, Msg) when is_list(Msg) ->
    MapData = jsx:decode(list_to_binary(Msg)),
    internal_parse(StatemPid, MapData);
parse(StatemPid, Msg) when is_binary(Msg) ->
    MapData = jsx:decode(Msg),
    internal_parse(StatemPid, MapData).

% HELLO event
internal_parse(StatemPid, #{<<"op">> := 10, <<"d">> := #{<<"heartbeat_interval">> := HBInterval}}) ->
    ?LOG_INFO("HELLO event received, with heartbeat interval: ~p", [HBInterval]),
    Payload = #{op=>1, d=>null},
    JsonPayload = jsx:encode(Payload),
    gen_statem:cast(StatemPid, {send_heartbeat, HBInterval, JsonPayload}),
    ok;
internal_parse(StatemPid, #{<<"op">> := 11}) ->
    ?LOG_INFO("HEARTBEART ACK event received"),
    Payload = #{op=>1, d=>null},
    JsonPayload = jsx:encode(Payload),
    gen_statem:cast(StatemPid, {send_heartbeat, JsonPayload}),
    ok;
internal_parse(StatemPid, Msg) ->
    ?LOG_WARNING("unexpected message to parse: ~p", [Msg]),
    ok.
