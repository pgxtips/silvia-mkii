-module(host_oper_status_alert).
-behaviour(alert).

-export([id/0, metric_id/0, eval/3]).

id() ->
    host_oper_status_alert.

metric_id() ->
    host_oper_status.

eval(Points, PrevState, _Config) ->
    State0 = ensure_state(PrevState),
    HostMap = host_lookup_map(),
    {NewState, Alerts} = lists:foldl(
      fun(Point, Acc) -> eval_point(Point, Acc, HostMap) end,
      {State0, []},
      Points
    ),
    {ok, NewState, lists:reverse(Alerts)}.

ensure_state(State) when is_map(State) -> State;
ensure_state(_) -> #{}.

eval_point(Point, {State, Alerts}, HostMap) ->
    {_Ts, Host, Iface, NewStatus} = Point,
    Key = {Host, Iface},
    PrevStatus = maps:get(Key, State, unknown),
    NewState = maps:put(Key, NewStatus, State),
    case transition_alert(Key, PrevStatus, NewStatus, HostMap) of
        none ->
            {NewState, Alerts};
        Alert ->
            {NewState, [Alert | Alerts]}
    end.

transition_alert(Key, unknown, up, HostMap) ->
    #{severity => info, message => format_message(Key, "is UP", HostMap)};
transition_alert(Key, unknown, down, HostMap) ->
    #{severity => critical, message => format_message(Key, "is DOWN", HostMap)};
transition_alert(Key, down, up, HostMap) ->
    #{severity => recovery, message => format_message(Key, "recovered (UP)", HostMap)};
transition_alert(Key, up, down, HostMap) ->
    #{severity => critical, message => format_message(Key, "went DOWN", HostMap)};
transition_alert(_, _, _, _) ->
    none.

format_message(Key, Suffix, HostMap) ->
    {Host, Iface} = Key,
    io_lib:format("host ~s interface ~s ~s", [
        display_host(Host, HostMap),
        to_list(Iface),
        Suffix
    ]).

host_lookup_map() ->
    Hosts = gen_server:call(silvia_gs, get_hosts),
    maps:from_list([
        {Ip, Name}
     || {Name, {Ip, _Port}} <- Hosts
    ]).

display_host(Host, HostMap) ->
    HostStr = to_list(Host),
    case maps:get(HostStr, HostMap, undefined) of
        undefined ->
            HostStr;
        Name ->
            to_list(Name)
    end.

to_list(Value) when is_binary(Value) -> binary_to_list(Value);
to_list(Value) when is_list(Value) -> Value;
to_list(Value) -> lists:flatten(io_lib:format("~p", [Value])).
