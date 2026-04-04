-module(silvia_alerts).

-include_lib("kernel/include/logger.hrl").

-export([handle_host_transition/3]).

handle_host_transition(HostName, PrevStatus, NewStatus) ->
    case {PrevStatus, NewStatus} of
        {unknown, up} ->
            ?LOG_INFO("host ~p is UP", [HostName]);
        {unknown, down} ->
            ?LOG_WARNING("host ~p is DOWN", [HostName]);
        {down, up} ->
            ?LOG_INFO("host ~p recovered (UP)", [HostName]);
        {up, down} ->
            ?LOG_ERROR("host ~p went DOWN", [HostName]);
        _ ->
            ok
    end.
