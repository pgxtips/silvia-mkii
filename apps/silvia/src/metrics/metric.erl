-module(metric).

-callback id() -> atom().
-callback fetch(map()) ->
    {ok, #{metric_id := atom(), points := [map()]}} | {error, term()}.
