-module(prometheus_host_oper_status_metric).
-include_lib("kernel/include/logger.hrl").
-behaviour(metric).

-export([id/0, fetch/1, get_host_statuses/1, get_host_status/2]).

-define(PROM_URL, "http://192.168.0.50:9090").
-define(HOST_OPER_STATUS_QUERY,
    "ifOperStatus{job=\"snmp_if_mib\",ifName!~\"^(lo|docker0|br-.*|veth.*)$\"}"
).

id() ->
    host_oper_status.

fetch(Opts) ->
    _ = Opts,
    case prometheus_client:query(?PROM_URL, ?HOST_OPER_STATUS_QUERY) of
        {ok, Result} ->
            {ok, #{
                metric_id => id(),
                points => [to_point(Item) || Item <- Result]
            }};
        {error, Reason} ->
            {error, Reason}
    end.

to_point(#{<<"metric">> := Metric, <<"value">> := [Ts, ValueBin]}) ->
    {
        Ts,
        maps:get(<<"instance">>, Metric, <<"unknown">>),
        maps:get(<<"ifName">>, Metric, <<"unknown">>),
        to_status(ValueBin)
    }.

to_status(Bin) ->
    case to_number(Bin) of
        1 -> up;
        1.0 -> up;
        2 -> down;
        2.0 -> down;
        _ -> unknown
    end.

get_host_statuses(Hosts) ->
    case fetch(#{} ) of
        {ok, #{points := Points}} ->
            {ok, build_statuses(Hosts, Points)};
        {error, Reason} ->
            {error, Reason}
    end.

get_host_status(HostName, Hosts) ->
    case fetch(#{} ) of
        {ok, #{points := Points}} ->
            {ok, build_host_interface_statuses(HostName, Hosts, Points)};
        {error, Reason} ->
            {error, Reason}
    end.


build_statuses(Hosts, Points) ->
    TargetsByIp = maps:from_list([{list_to_binary(Ip), HostName} || {HostName, {Ip, _Port}} <- Hosts]),
    maps:from_list(
      [
        {lists:flatten(io_lib:format("~p (~s)", [HostName, binary_to_list(Iface)])), Status}
       || {_Ts, HostIp, Iface, Status} <- Points,
          {ok, HostName} <- [maps:find(HostIp, TargetsByIp)]
      ]).

build_host_interface_statuses(HostName, Hosts, Points) ->
    TargetsByIp = maps:from_list([
        {list_to_binary(Ip), Name} || {Name, {Ip, _Port}} <- Hosts
    ]),
    maps:from_list(
      [
        {Iface, Status}
       || {_Ts, HostIp, Iface, Status} <- Points,
          maps:get(HostIp, TargetsByIp, undefined) =:= HostName
      ]).

to_number(Bin) when is_binary(Bin) ->
    case string:to_float(binary_to_list(Bin)) of
        {error, no_float} ->
            list_to_integer(binary_to_list(Bin));
        {Float, _Rest} ->
            Float
    end;
to_number(Value) ->
    Value.
