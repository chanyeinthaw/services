# Friday runtime

Runs the pinned Friday release as a persistent Docker service.

## Runtime

The image contains Friday `v0.0.0-nightly.3`, Pi `0.84.1`, Bun, Node.js, pnpm, Git, and GitHub CLI. At startup it refreshes `git@github.com:chanyeinthaw/pi-setup.git`, installs its dependencies, and disables the Pi subagents extension by renaming `extensions/subagents.ts` to `extensions/subagents.txt`. Friday owns background orchestration itself.

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

## Commands

From `/home/chan/Services`:

```bash
mise run friday:build
mise run friday:up
mise run friday:status
mise run friday:logs
mise run friday:restart
mise run friday:down
```

The `.env` file contains the Discord application credentials and is ignored by Git. Provider authentication is retained under `data/pi`.
