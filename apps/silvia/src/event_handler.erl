-module(event_handler).

-include_lib("kernel/include/logger.hrl").

-export([handle_event/2]).

handle_event(
    interaction_create,
    #{
        command_name := <<"ping">>,
        interaction_id := InteractionIdBin,
        interaction_token := InteractionTokenBin
    }
) ->
    reply(InteractionIdBin, InteractionTokenBin, "Pong!");
handle_event(
    interaction_create,
    #{
        command_name := <<"host">>,
        command_data := #{<<"options">> := [#{<<"name">> := <<"list">>}]},
        interaction_id := InteractionIdBin,
        interaction_token := InteractionTokenBin
    }
) ->
    Statuses = gen_server:call(silvia_gs, get_host_statuses),
    reply(InteractionIdBin, InteractionTokenBin, format_host_list(Statuses));
handle_event(
    interaction_create,
    #{
        command_name := <<"host">>,
        command_data := #{
            <<"options">> := [
                #{
                    <<"name">> := <<"status">>,
                    <<"options">> := [
                        #{<<"name">> := <<"host">>, <<"value">> := HostValue} | _
                    ]
                }
            ]
        },
        interaction_id := InteractionIdBin,
        interaction_token := InteractionTokenBin
    }
) ->
    Statuses = gen_server:call(silvia_gs, get_host_statuses),
    case resolve_host_key(HostValue, Statuses) of
        {ok, HostKey} ->
            case gen_server:call(silvia_gs, {get_host_status, HostKey}) of
                {ok, HostStatus} ->
                    Reply = io_lib:format("~p: ~p", [HostKey, HostStatus]),
                    reply(InteractionIdBin, InteractionTokenBin, lists:flatten(Reply));
                {error, _} ->
                    reply(InteractionIdBin, InteractionTokenBin, "Host not found")
            end;
        error ->
            reply(InteractionIdBin, InteractionTokenBin, "Host not found")
    end;
handle_event(
    interaction_create,
    #{
        command_name := <<"host">>,
        interaction_id := InteractionIdBin,
        interaction_token := InteractionTokenBin
    }
) ->
    reply(InteractionIdBin, InteractionTokenBin, "Usage: /host list or /host status <host>");
handle_event(interaction_create, InteractionMap) ->
    ?LOG_DEBUG("Interaction data: ~p", [InteractionMap]),
    case maps:get(command_name, InteractionMap, undefined) of
        undefined ->
            ok;
        _ ->
            InteractionIdBin = maps:get(interaction_id, InteractionMap),
            InteractionTokenBin = maps:get(interaction_token, InteractionMap),
            reply(InteractionIdBin, InteractionTokenBin, "Unknown command")
    end;
handle_event(guild_create, GuildData) ->
    GuildId = binary_to_list(maps:get(<<"id">>, GuildData)),
    GuildName = maps:get(<<"name">>, GuildData, <<"unknown">>),
    ?LOG_INFO("guild_create: ~s (~s)", [GuildName, GuildId]),
    AppId = gen_server:call(silvia_gs, get_app_id),
    BotToken = gen_server:call(silvia_gs, get_bot_token),
    reg_events:register_events(AppId, BotToken, GuildId),

    event_undefined.

reply(InteractionIdBin, InteractionTokenBin, Payload) ->
    InteractionId = binary_to_list(InteractionIdBin),
    InteractionToken = binary_to_list(InteractionTokenBin),
    discordclient:interaction_reply_message(InteractionId, InteractionToken, Payload).

resolve_host_key(HostValue, Statuses) when is_binary(HostValue) ->
    resolve_host_key(binary_to_list(HostValue), Statuses);
resolve_host_key(HostValue, Statuses) when is_list(HostValue) ->
    Pairs = maps:to_list(Statuses),
    case lists:filter(
           fun({Key, _}) ->
               string:lowercase(host_key_to_string(Key)) =:= string:lowercase(HostValue)
           end,
           Pairs) of
        [{HostKey, _}] -> {ok, HostKey};
        _ -> error
    end.

host_key_to_string(Key) when is_atom(Key) ->
    atom_to_list(Key);
host_key_to_string(Key) when is_list(Key) ->
    Key;
host_key_to_string(Key) when is_binary(Key) ->
    binary_to_list(Key);
host_key_to_string(Key) ->
    lists:flatten(io_lib:format("~p", [Key])).

format_host_list(Statuses) when map_size(Statuses) =:= 0 ->
    "No hosts configured";
format_host_list(Statuses) ->
    Lines = lists:map(
              fun({Host, Status}) ->
                  lists:flatten(io_lib:format("~p: ~p", [Host, Status]))
              end,
              maps:to_list(Statuses)),
    string:join(Lines, "\n").
