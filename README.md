# Silvia MKII

Silvia is an Erlang/OTP Discord bot for homelab monitoring.

It connects to Discord Gateway via the `discordclient` app, receives events, and responds to slash commands.
Its current scope is host monitoring and alerting, with operational state published to Discord.

## What Silvia Does

- Tracks host health.
- Alerts on node down/up transitions.
- Alerts on pressing host-level errors (critical failures and severe degradation).
- Provides slash-command based interaction (for example, `ping`).
- Routes status and alert output into dedicated Discord channels.

## Discord Channel Requirements

Silvia currently expects channels to be created manually by the operator.
Create these channels and store their IDs in Silvia config.

- `#bot-commands`: slash command usage and bot replies.
- `#alerts-critical`: urgent alerts (node down, critical host incidents).
- `#alerts-warning`: warning-level alerts (degradation, non-critical failures).
- `#alerts-recovery`: recovery notifications (node back up).
- `#status-summary`: periodic summary of host fleet status.
- `#silvia-errors`: internal Silvia execution/runtime errors.

## Slash Commands

### Implemented

- `/ping`
  - Purpose: confirms bot availability.
  - Response: `Pong!`

### Planned

- `/host list`
  - Purpose: list all monitored hosts and current state.

- `/host status <host>`
  - Params:
    - `<host>`: host identifier or hostname.
  - Purpose: show detailed status for one host.

- `/alerts ack <incident_id>`
  - Params:
    - `<incident_id>`: active incident identifier.
  - Purpose: acknowledge an alert.

- `/silvia config show`
  - Purpose: show non-secret monitoring configuration.

## Silvia Config Shape

Silvia host config is expected to be shaped like this:

```erlang
{silvia, [
    {hosts, [
        {"host-a", {"10.0.0.10", 80}},
        {"host-b", {"10.0.0.20", 80}},
        {"host-c", {"10.0.0.30", 80}}
    ]}
]}.
```

## Build

```bash
rebar3 compile
```

## Run (Dev Shell)

```bash
DISCORD_BOT_TOKEN=<your_bot_token> DISCORD_APP_ID=<your_app_id> rebar3 as dev shell
```
