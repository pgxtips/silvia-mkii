-module(gateway_statem).

-export([send_heartbeat_payload/3]).


-export([open_gateway/1]).
-export([parse_wss_url/1]).

-include_lib("kernel/include/logger.hrl").
-behaviour(gen_statem).

%%% gen_statem callbacks
-export([init/1]).
-export([callback_mode/0]).
-export([terminate/3]).
-export([start_link/0]).
-export([establish_gateway/3]).
-export([connected/3]).

start_link() ->
    gen_statem:start({local, ?MODULE}, ?MODULE, [], []).

%%% gen_statem callbacks
init([]) ->
    BotToken = os:getenv("DISCORD_BOT_TOKEN"),
    {ok, WSSUrl} = open_gateway(BotToken),
    ?LOG_DEBUG("WSS Url: ~p", [WSSUrl]),
    Data = #{bot_token=> BotToken, wss_url => WSSUrl},
    {ok, establish_gateway, Data, [{next_event, internal, connect}]}.

callback_mode() -> state_functions.

terminate(Reason, State, Data) ->
    ?LOG_ERROR("Reason: ~p, State: ~p, Data: ~p", [Reason, State, Data]),
    ok.

%% ---------------
%% state functions
%% ---------------

%% ---------------
%% state: establish_gateway
%% attempts to make successful websocket connection to discord gateway
%% ---------------
establish_gateway(internal, connect, Data) ->
    Url = maps:get(wss_url, Data),
    ?LOG_DEBUG("Connecting to ~p", [Url]),

    #{host := Host, port := Port, path := Path, qs := Qs} = parse_wss_url(Url),
    ?LOG_DEBUG("Connecting to ~p:~p~s~s", [Host, Port, Path, Qs]),

    GunOpts = #{ 
        transport => tls, 
        protocols => [http], 
        tls_opts => [{verify, verify_none}]     
    },
    
    case gun:open(Host, Port, GunOpts) of
        {ok, ConnPid} ->
            NewData = Data#{
                conn_pid => ConnPid,
                host => Host,
                port => Port,
                path => Path,
                qs => Qs
            },
            {keep_state, NewData};
        {error, Reason} ->
            ?LOG_ERROR("gun:open failed: ~p", [Reason]),
            {keep_state, Data, [{state_timeout, 5000, retry_connect}]}
    end;

%% gun_up message is sent end upon successful connection to the source
establish_gateway(info, {gun_up, ConnPid, http}, Data = #{conn_pid := ConnPid}) ->
    ?LOG_DEBUG("Gun connection is up"),
    {keep_state, Data, [{next_event, internal, ws_upgrade}]};

%% once successful connection has been established (via gun_up message),
%% then perform a websocket upgrade
establish_gateway(internal, ws_upgrade, Data = #{conn_pid := ConnPid, path := Path, qs := Qs}) ->
    FullPath = Path ++ Qs,
    ?LOG_DEBUG("Upgrading websocket on path: ~s", [FullPath]),

    StreamRef = gun:ws_upgrade(ConnPid, FullPath),
    NewData = Data#{stream_ref => StreamRef},
    {keep_state, NewData};

%% gun_upgrade message is sent upon success
establish_gateway(info, {gun_upgrade, ConnPid, StreamRef, [<<"websocket">>], _Headers},
                    Data = #{conn_pid := ConnPid, stream_ref := StreamRef}) ->
    ?LOG_INFO("WebSocket upgrade successful"),
    {next_state, connected, Data};

%% receiving a message at this point means that the upgrade has failed
%% the best course of action is to close the connection and try again
establish_gateway(info, {gun_response, ConnPid, StreamRef, _Fin, Status, Headers},
                    Data = #{conn_pid := ConnPid, stream_ref := StreamRef}) ->
    ?LOG_ERROR("WebSocket upgrade failed, status=~p headers=~p", [Status, Headers]),
    gun:close(ConnPid),
    RetryData = clear_conn_data(Data),
    {keep_state, RetryData, [{state_timeout, 5000, retry_connect}]};

%% a gun_down means that the gun process as died at some point during this process
%% the best course of action is to close the connection and try again
establish_gateway(info, {gun_down, ConnPid, _Protocol, Reason, _KilledStreams}, Data) ->
    case maps:get(conn_pid, Data, undefined) of
        ConnPid ->
            ?LOG_WARNING("Connection went down during websocket establishment: ~p", [Reason]),
            RetryData = clear_conn_data(Data),
            {keep_state, RetryData, [{state_timeout, 5000, retry_connect}]};
        _ ->
            {keep_state, Data}
    end;

establish_gateway(state_timeout, retry_connect, Data) ->
    {keep_state, Data, [{next_event, internal, connect}]};

establish_gateway(info, Msg, Data) ->
    ?LOG_DEBUG("Unhandled establish_websocket info msg: ~p", [Msg]),
    {keep_state, Data};

establish_gateway(_EventType, _EventContent, Data) ->
    {keep_state, Data}.


%% ---------------
%% state: connected
%% handles requests via the socket connection
%% ---------------
%% handles outbound websocket messages
connected(cast, {send_payload, Payload}, Data = #{conn_pid := ConnPid, stream_ref := StreamRef}) ->
    ?LOG_DEBUG("Sending payload: ~p", [Payload]),
    ok = gun:ws_send(ConnPid, StreamRef, {text, Payload}),
    {keep_state, Data};
% this is called on the first heartbeat payload
connected(cast, {send_heartbeat, Interval, Payload}, Data = #{conn_pid := ConnPid, stream_ref := StreamRef}) ->
    Jitter = rand:uniform(),
    Time = max(1, trunc(Interval * Jitter)),
    ?LOG_DEBUG("Sending heartbeat in: ~p", [Time]), 
    timer:apply_after(Time, ?MODULE, send_heartbeat_payload, [Payload, ConnPid, StreamRef]),
    {keep_state, Data#{hb_interval=>Interval}};
% this is called on the heartbeat ack event (notice no interval param)
connected(cast, {send_heartbeat, Payload}, Data = #{conn_pid := ConnPid, stream_ref := StreamRef}) ->
    case maps:get(hb_interval, Data, undefined) of
        undefined -> 
            ?LOG_ERROR("Unable to retrieve heartbeat interval"), 
            RetryData = clear_conn_data(Data),
            {next_state, establish_gateway, RetryData,
            [{state_timeout, 5000, retry_connect}]};
        Time ->
            ?LOG_DEBUG("Sending heartbeat in: ~p", [Time]), 
            timer:apply_after(Time, ?MODULE, send_heartbeat_payload, [Payload, ConnPid, StreamRef]),
            {keep_state, Data}
    end;
connected(cast, {update_last_seq, Seq}, Data) ->
    {keep_state, Data#{last_seq => Seq}};
connected(cast, {ready, ReadyData}, Data) ->
      SessionId = maps:get(<<"session_id">>, ReadyData, undefined),
      ResumeUrl = maps:get(<<"resume_gateway_url">>, ReadyData, undefined),
      User = maps:get(<<"user">>, ReadyData, #{}),
      UserId = maps:get(<<"id">>, User, undefined),
      Username = maps:get(<<"username">>, User, undefined),
      ?LOG_INFO("READY received: session_id=~p user=~p (~p)", [SessionId, Username, UserId]),
      {keep_state, Data#{
          ready => true,
          session_id => SessionId,
          resume_gateway_url => ResumeUrl,
          bot_user => User
      }};
connected(cast, {gateway_reconnect}, Data) ->
    ?LOG_WARNING("Gateway requested reconnect"),
    RetryData = clear_conn_data(Data),
    {next_state, establish_gateway, RetryData, [{state_timeout, 0, retry_connect}]};
connected(cast, {invalid_session, IsInvalid}, Data) ->
    case IsInvalid of
        true ->
            BotToken = maps:get(bot_token, Data, undefined),
            SessionId = maps:get(session_id, Data, undefined),
            LastSeq = maps:get(last_seq, Data, undefined),
            Payload = #{
                 op => 6,
                 d => #{
                     token => BotToken,
                     session_id => SessionId,
                     seq => LastSeq
                 }
            },
            JsonPayload = jsx:encode(Payload),
            gen_statem:cast(self(), {send_payload, JsonPayload});
        false ->
           RetryData = clear_conn_data(Data),
           {next_state, establish_gateway, RetryData,
           [{state_timeout, 5000, retry_connect}]}
    end;
    
%% handles inbound websocket TEXT messages
connected(info, {gun_ws, ConnPid, StreamRef, {text, Msg}}, Data) ->
    ?LOG_DEBUG("Received ws text msg: ~s", [Msg]),
    handle_gateway_message:parse(self(), Data, Msg),
    {keep_state, Data};

%% handles inbound websocket CLOSE socket frames
connected(info, {gun_ws, ConnPid, StreamRef, {close, Code, Reason}},
    Data = #{conn_pid := ConnPid, stream_ref := StreamRef}) ->
    ?LOG_WARNING("WebSocket close frame received: code=~p reason=~p", [Code, Reason]),
    RetryData = clear_conn_data(Data),
    case Code of
      4004 ->  % auth failed, don't loop forever
            {stop, {discord_auth_failed, Reason}, RetryData};
      4010 ->  % invalid shard
            {stop, {discord_invalid_shard, Reason}, RetryData};
      4011 ->  % sharding required
            {stop, {discord_sharding_required, Reason}, RetryData};
      _ ->
           {next_state, establish_gateway, RetryData,
           [{state_timeout, 5000, retry_connect}]}
      end;
connected(info, {gun_ws, ConnPid, StreamRef, close},
          Data = #{conn_pid := ConnPid, stream_ref := StreamRef}) ->
    ?LOG_WARNING("Websocket close frame received"),
    RetryData = clear_conn_data(Data),
    {next_state, establish_gateway, RetryData,
    [{state_timeout, 5000, retry_connect}]};
 
%% handles the termination of a gun process for a given reason
connected(info, {gun_down, ConnPid, _Protocol, Reason, _KilledStreams}, Data) ->
    case maps:get(conn_pid, Data, undefined) of
        ConnPid ->
            ?LOG_WARNING("Connection down: ~p", [Reason]),
            RetryData = clear_conn_data(Data),
            {next_state, establish_gateway, RetryData,
            [{state_timeout, 5000, retry_connect}]};
        _ ->
            {keep_state, Data}
    end;

connected(info, Msg, Data) ->
    ?LOG_DEBUG("Unhandled connected info msg: ~p", [Msg]),
    {keep_state, Data};

connected(_EventType, _EventContent, Data) ->
    {keep_state, Data}.


%% ---------------
%% internal functions
%% ---------------
%% helper functions of the statem (could potentially be moved to own module)

send_heartbeat_payload(Payload, ConnPid, StreamRef) ->
    try
        ?LOG_DEBUG("Sending heartbeat payload: ~p", [Payload]),
        ok = gun:ws_send(ConnPid, StreamRef, {text, Payload})
    catch
        _:_ -> ?LOG_ERROR("there was an error sending heartbeart")
    end.

parse_wss_url(Url) ->
    Map = uri_string:parse(Url),

    Scheme = maps:get(scheme, Map),
    Host = maps:get(host, Map),
    RawPath = maps:get(path, Map, "/"),
    Path = case RawPath of
        undefined -> "/";
        "" -> "/";
        _ -> RawPath 
    end,

    Query = maps:get(query, Map, undefined),

    Port = case maps:get(port, Map, undefined) of
        undefined when Scheme =:= "wss" -> 443;
        undefined when Scheme =:= "ws" -> 80;
        P -> P
    end,

    Qs = case Query of
        undefined -> "?v=10&encoding=json";
        "" -> "";
        Q -> "?" ++ Q
    end,
    
    #{host => Host, port => Port, path => Path, qs => Qs}.

clear_conn_data(Data) ->
    maps:without([conn_pid, stream_ref], Data).

open_gateway(BotToken) ->
    RequestURL = "https://discord.com/api/v10/gateway/bot",
    RequestHeaders = [
        {"Authorization", io_lib:format("Bot ~s", [BotToken])}
    ],
    HttpOpts = [
        {ssl, [{verify, verify_none}]}
    ],
    Response = httpc:request(get, {RequestURL, RequestHeaders}, HttpOpts, []),
    case Response of
        {ok, {{_, 200, _}, _Headers, JsonBody}} -> 
            ?LOG_DEBUG("Response ok: ~p", [JsonBody]),
            DecodedBody = jsx:decode(list_to_binary(JsonBody)),
            GatewayUrl = maps:get(<<"url">>, DecodedBody),
            {ok, binary_to_list(GatewayUrl)};
        {ok, {{_, Status, _}, Headers, Body}} ->
            Error = io:format("HTTP error ~p~nHeaders: ~p~nBody: ~s~n", [Status, Headers, Body]),
            ?LOG_DEBUG("Response error: ~s", [Error]),
            {error, Error};
        {error, Reason} ->
            Error = io:format("Request failed: ~p~n", [Reason]),
            {error, Error}
    end.
