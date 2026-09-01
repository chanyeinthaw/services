# Friday runtime

Runs Friday as a persistent Docker service managed by Supervisor inside the container.

## Runtime

The image contains a verified bootstrap Friday release, Supervisor, Pi `0.84.1`, Bun, Node.js, pnpm, Git, and GitHub CLI. The active Friday binary lives at:

```text
/home/friday/.friday/bin/friday
```

That path is persistent, so Friday can update independently of the image. On container startup the entrypoint checks the configured update channel, verifies the selected GitHub release against `SHA256SUMS`, atomically installs it, and then starts Supervisor. If GitHub is unavailable, startup continues with the existing persistent binary. A new installation falls back to the bootstrap binary packaged in the image.

At startup the entrypoint also refreshes `git@github.com:chanyeinthaw/pi-setup.git`, installs its dependencies, and disables the Pi subagents extension by renaming `extensions/subagents.ts` to `extensions/subagents.txt`. Friday owns background orchestration itself.

## Self-management

Inside the container, Friday can restart its process without restarting the container:

```bash
friday-restart
```

It can install the latest nightly release and restart into it:

```bash
friday-update
```

An exact release may be selected explicitly:

```bash
friday-update v0.0.0-nightly.13
```

Updates retain the previous binary and use atomic replacement. The health check clears the pending-update marker after Supervisor reports Friday as running. Repeated early startup failures restore the previous binary.

A Supervisor restart reuses the installed binary and does not perform another update check. Container startup performs the update check when `FRIDAY_UPDATE_ON_START=true`.

## Persistent data

```text
data/home/friday → /home/friday/.friday
data/home/pi     → /home/friday/.pi
data/home/gh     → /home/friday/.config/gh
data/home/ssh    → /home/friday/.ssh
secrets/runtime  → /run/secrets, read-only
```

The deployment has an isolated `friday` user and service home. It does not mount or reference the `orbs-at-home` development checkout.

## Discord policy

```text
guild allowlist: 1021288369327706153
channel access: all
user allowlist: 435482941515104257
invocation default: all-messages
management channel: 1543786249888727060
```

The management channel is a system channel. Friday replies directly there, uses `/home/friday/.friday` as its workspace, and does not create Discord child threads.

## Host commands

From `/home/chan/Services`:

```bash
mise run friday:build
mise run friday:up
mise run friday:status
mise run friday:logs
mise run friday:restart
mise run friday:down
```

The `.env` file contains Discord application credentials and is ignored by Git. Provider authentication is retained under `data/pi`.
