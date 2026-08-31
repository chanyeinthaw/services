# Friday runtime

Runs the pinned Friday release as a persistent Docker service.

## Runtime

The image contains Friday `v0.0.0-nightly.2`, Pi `0.84.1`, Bun, Node.js, pnpm, Git, and GitHub CLI. At startup it refreshes `git@github.com:chanyeinthaw/pi-setup.git`, installs its dependencies, and disables the Pi subagents extension by renaming `extensions/subagents.ts` to `extensions/subagents.txt`. Friday owns background orchestration itself.

## Persistent data

```text
data/friday → /home/chan/Code/orbs-at-home/.friday
data/pi     → /home/chan/.pi
data/gh     → /home/chan/.config/gh
data/ssh    → /home/chan/.ssh
secrets/runtime → /run/secrets, read-only
```

The container preserves `/home/chan/Code/orbs-at-home/.friday` and `/home/chan/.pi` so durable Friday workspaces and Pi session paths remain valid after migration from the host development runtime.

## Discord policy

```text
guild allowlist: 1021288369327706153
channel access: all
user allowlist: 435482941515104257
invocation default: all-messages
management channel: 1543786249888727060
```

The management channel is a system channel. Friday replies directly there, uses `/home/chan/Code/orbs-at-home/.friday` as its workspace, and does not create Discord child threads.

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
