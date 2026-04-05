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
    Hosts = gen_server:call(silvia_gs, get_hosts),
    case gen_server:call(
           silvia_gs,
           {get_metric, {host_oper_status, get_host_statuses, [Hosts]}}
         ) of
        {ok, Statuses} ->
            reply(InteractionIdBin, InteractionTokenBin, format_host_list(Statuses));
        {error, _} ->
            reply(InteractionIdBin, InteractionTokenBin, "Unable to fetch host statuses")
    end;
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
    Hosts = gen_server:call(silvia_gs, get_hosts),
    ReplyMsg = case resolve_host_key(HostValue, Hosts) of
        {ok, HostKey} -> format_host_status(HostKey, Hosts);
        error -> "Host not found"
    end,
    reply(InteractionIdBin, InteractionTokenBin, ReplyMsg);
handle_event(interaction_create,
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
    ok.

reply(InteractionIdBin, InteractionTokenBin, Payload) ->
    InteractionId = binary_to_list(InteractionIdBin),
    InteractionToken = binary_to_list(InteractionTokenBin),
    discordclient:interaction_reply_message(InteractionId, InteractionToken, Payload).

resolve_host_key(HostValue, Hosts) when is_binary(HostValue) ->
    resolve_host_key(binary_to_list(HostValue), Hosts);
resolve_host_key(HostValue, Hosts) when is_list(HostValue) ->
    case lists:keyfind(HostValue, 1, [{host_name_to_string(Name), Name} || {Name, _} <- Hosts]) of
        {_, HostKey} -> {ok, HostKey};
        false -> error
    end;
resolve_host_key(_, _) ->
    error.

format_host_status(HostKey, Hosts) ->
    case gen_server:call(
           silvia_gs,
           {get_metric, {host_oper_status, get_host_status, [HostKey, Hosts]}}
         ) of
        {ok, HostStatus} when is_map(HostStatus), map_size(HostStatus) =:= 0 ->
            "No interfaces found";
        {ok, HostStatus} when is_map(HostStatus) ->
            Lines = lists:map(
              fun({Iface, Status}) ->
                  lists:flatten(io_lib:format("~s: ~p", [interface_to_string(Iface), Status]))
              end,
              maps:to_list(HostStatus)),
            string:join(Lines, "\n");
        {error, _} -> "Host not found"
    end.

format_host_list(Statuses) when map_size(Statuses) =:= 0 ->
    "No hosts configured";
format_host_list(Statuses) ->
    Lines = lists:map(
              fun({Host, Status}) ->
                  lists:flatten(io_lib:format("~s: ~p", [host_name_to_string(Host), Status]))
              end,
              maps:to_list(Statuses)),
    string:join(Lines, "\n").

host_name_to_string(Name) when is_atom(Name) ->
    atom_to_list(Name);
host_name_to_string(Name) when is_binary(Name) ->
    binary_to_list(Name);
host_name_to_string(Name) when is_list(Name) ->
    Name;
host_name_to_string(Name) ->
    lists:flatten(io_lib:format("~p", [Name])).

interface_to_string(Iface) when is_binary(Iface) ->
    binary_to_list(Iface);
interface_to_string(Iface) when is_list(Iface) ->
    Iface;
interface_to_string(Iface) ->
    lists:flatten(io_lib:format("~p", [Iface])).
