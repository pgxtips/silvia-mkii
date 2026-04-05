-module(host_oper_status).
-behaviour(metric).

-export([id/0, fetch/1, get_host_statuses/1, get_host_status/2]).

id() ->
    host_oper_status.

fetch(Opts) ->
    %% Datasource selection lives behind this module.
    prometheus_host_oper_status_metric:fetch(Opts).

get_host_statuses(Hosts) ->
    prometheus_host_oper_status_metric:get_host_statuses(Hosts).

get_host_status(HostName, Hosts) ->
    prometheus_host_oper_status_metric:get_host_status(HostName, Hosts).
