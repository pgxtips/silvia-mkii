-module(alert).

-callback id() -> atom().
-callback metric_id() -> atom().
-callback eval([map()], term(), map()) ->
    {ok, term(), [#{severity := atom(), message := iodata()}]} | {error, term()}.
