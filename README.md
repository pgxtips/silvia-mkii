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
- `/host list`
  - Purpose: list all monitored hosts and current state.
- `/host status <host>`
  - Params:
    - `<host>`: host identifier from config.
  - Purpose: show status for one host.

### Planned

- `/alerts ack <incident_id>`
  - Params:
    - `<incident_id>`: active incident identifier.
  - Purpose: acknowledge an alert.

- `/silvia config show`
  - Purpose: show non-secret monitoring configuration.

## Silvia Config Shape

Create `config/silvia.config` with your monitored hosts.

Path:
- `config/silvia.config`

Example:

```erlang
{log_level, info}.

{hosts, [
    {hosta, {"10.0.0.1", 80}},
    {hostb, {"10.0.0.2", 80}},
    {hostc, {"10.0.0.3", 80}}
]}.
```

Notes:
- This file is loaded by Silvia on startup.
- Host keys (`hosta`, `hostb`, `hostc`) are what you use in `/host status <host>`.

## Build

```bash
rebar3 compile
```

## Run (Dev Shell)

```bash
DISCORD_BOT_TOKEN=<your_bot_token> DISCORD_APP_ID=<your_app_id> rebar3 as dev shell
```
