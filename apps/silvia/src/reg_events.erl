-module(reg_events).

-export([register_events/3]).

register_events(AppId, BotToken, GuildId) -> 
    PingCommand = #{
        name => <<"ping">>,
        description => <<"Check bot availability">>,
        type => 1
    },
    HostCommand = #{
        name => <<"host">>,
        description => <<"Host monitoring commands">>,
        type => 1,
        options => [
            #{
                type => 1,
                name => <<"list">>,
                description => <<"List host liveness states">>
            },
            #{
                type => 1,
                name => <<"status">>,
                description => <<"Show one host status">>,
                options => [
                    #{
                        type => 3,
                        name => <<"host">>,
                        description => <<"Host name">>,
                        required => true
                    }
                ]
            }
        ]
    },
    discordclient:register_guild_command(AppId, BotToken, GuildId, PingCommand),
    discordclient:register_guild_command(AppId, BotToken, GuildId, HostCommand),
    ok.
