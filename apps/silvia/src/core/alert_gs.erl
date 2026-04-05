-module(alert_gs).
-behaviour(gen_server).

-include_lib("kernel/include/logger.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({send_alert, {AlertType, Message}}, State) ->
    _ = send_alert(AlertType, Message),
    {noreply, State};
handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

send_alert(AlertType, Message) ->
    AlertChannels = gen_server:call(silvia_gs, get_alert_channels),
    BotToken = gen_server:call(silvia_gs, get_bot_token),
    case maps:get(AlertType, AlertChannels, undefined) of
        undefined ->
            ?LOG_WARNING("no channel configured for alert type ~p", [AlertType]),
            {error, no_channel_configured};
        ChannelId ->
            discordclient:send_channel_message(
                to_list(ChannelId),
                to_list(BotToken),
                to_list(Message)
            )
    end.

to_list(Value) when is_list(Value) -> Value;
to_list(Value) when is_binary(Value) -> binary_to_list(Value).
