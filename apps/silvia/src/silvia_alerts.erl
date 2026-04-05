-module(silvia_alerts).

-include_lib("kernel/include/logger.hrl").

-export([handle_host_transition/3]).

handle_host_transition(HostName, PrevStatus, NewStatus) ->
    case {PrevStatus, NewStatus} of
        {unknown, up} ->
            ?LOG_INFO("host ~p is UP", [HostName]),
            send_alert_async(info, HostName, PrevStatus, NewStatus);
        {unknown, down} ->
            ?LOG_WARNING("host ~p is DOWN", [HostName]),
            send_alert_async(info, HostName, PrevStatus, NewStatus);
        {down, up} ->
            ?LOG_INFO("host ~p recovered (UP)", [HostName]),
            send_alert_async(recovery, HostName, PrevStatus, NewStatus);
        {up, down} ->
            ?LOG_ERROR("host ~p went DOWN", [HostName]),
            send_alert_async(critical, HostName, PrevStatus, NewStatus);
        _ ->
            ok
    end.

send_alert_async(AlertType, HostName, PrevStatus, NewStatus) ->
    _ = spawn(fun() ->
        send_alert(AlertType, HostName, PrevStatus, NewStatus)
    end),
    ok.

send_alert(AlertType, HostName, PrevStatus, NewStatus) ->
    AlertChannels = gen_server:call(silvia_gs, get_alert_channels),
    BotToken = gen_server:call(silvia_gs, get_bot_token),
    case maps:get(AlertType, AlertChannels, undefined) of
        undefined ->
            ?LOG_WARNING("no channel configured for alert type ~p", [AlertType]),
            ok;
        ChannelId ->
            Message = io_lib:format("host ~p transition: ~p -> ~p", [
                HostName, PrevStatus, NewStatus
            ]),
            case discordclient:send_channel_message(
                to_list(ChannelId),
                to_list(BotToken),
                lists:flatten(Message)
            ) of
                {ok, _} ->
                    ok;
                {error, Reason} ->
                    ?LOG_ERROR("failed to send alert ~p for host ~p: ~p", [AlertType, HostName, Reason]),
                    ok
            end
    end.

to_list(Value) when is_list(Value) -> Value;
to_list(Value) when is_binary(Value) -> binary_to_list(Value).
