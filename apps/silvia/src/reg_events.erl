-module(reg_events).

-export([register_events/3]).

register_events(AppId, BotToken, GuildId) -> 
    PingCommand = #{
        name => <<"ping">>,
        description => <<"Check bot availability">>,
        type => 1
    },
    discordclient:register_guild_command(AppId, BotToken, GuildId, PingCommand),
    ok.
