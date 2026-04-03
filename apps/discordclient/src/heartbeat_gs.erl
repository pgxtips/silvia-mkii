-module(heartbeat_gs).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

%% Callbacks for `gen_server`
-export([init/1, handle_call/3, handle_cast/2, start_link/1, create_heartbeat_timer/1]).

start_link(Args) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Args, []).

init([]) ->
    {ok, []}.

handle_call({start_heartbeat, Request=#{name:=Name, interval:=Interval, gateway_pid:=GPid}}, _From, State) ->
    ?LOG_DEBUG("attempting to create new heartbeat: ~p", [Request]),
    NewState = case heartbeat_exists(Name, State) of 
        false -> 
            Jitter = rand:uniform(),
            Time = max(1, trunc(Interval * Jitter)),
            {ok, TRef} = timer:apply_interval(Time, ?MODULE, create_heartbeat_timer, [GPid]),
            make_entry(Name, Interval, Jitter, Time, TRef, State);
        _ -> State
    end,
    {reply, ok, NewState};
handle_call(Request, _From, State) ->
    ?LOG_ERROR("unknown request: ~p", [Request]),
    {reply, unknown_request, State}.

handle_cast(Request,State) ->
    ?LOG_ERROR("cast not implemented: ~p", [Request]),
    {noreply, State}.

create_heartbeat_timer(GPid) ->
    ?LOG_DEBUG("sending heartbeat: ~p", [GPid]).

make_entry(Name, Interval, Jitter, Time, TRef, State) ->
    NewEntry = {Name, #{
        interval => Interval,
        jitter => Jitter,
        time => Time,
        tref => TRef
    }},
    ?LOG_DEBUG("created new entry: ~p", [NewEntry]),
    State ++ [NewEntry].

heartbeat_exists(Name, State) ->
    lists:keymember(Name, 1, State). 
        
