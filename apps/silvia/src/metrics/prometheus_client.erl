-module(prometheus_client).

-export([query/2]).

query(BaseUrl, PromQl) ->
    _ = application:ensure_all_started(inets),
    _ = application:ensure_all_started(ssl),
    QueryString = uri_string:compose_query([{"query", PromQl}]),
    Url = BaseUrl ++ "/api/v1/query?" ++ QueryString,
    HttpOpts = [{timeout, 10000}],
    case httpc:request(get, {Url, []}, HttpOpts, []) of
        {ok, {{_, 200, _}, _Headers, RespBody}} ->
            decode_query_response(RespBody);
        {ok, {{_, Status, _}, _Headers, RespBody}} ->
            {error, {http_error, Status, iolist_to_binary(RespBody)}};
        {error, Reason} ->
            {error, Reason}
    end.

decode_query_response(RespBody) ->
    RespMap = jsx:decode(iolist_to_binary(RespBody), [return_maps]),
    case RespMap of
        #{<<"status">> := <<"success">>, <<"data">> := #{<<"result">> := Result}} ->
            {ok, Result};
        _ ->
            {error, {invalid_response, RespMap}}
    end.
