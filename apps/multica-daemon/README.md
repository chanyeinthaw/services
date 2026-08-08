# Multica Docker Runtime

This service runs the Multica agent daemon inside a Docker container instead of
installing the daemon on the host.

The image includes:

- mise
- Node.js, Bun, pnpm, Go, and Pi installed through mise
- Pi's executable directory on PATH (`.../installs/pi/0.84.1/pi`), so the
  Multica daemon resolves the actual Pi binary instead of the mise command shim
- Git and a global Git identity
- passwordless sudo for the `multica` user
- OpenSSH server
- optional Tailscale support

At startup it:

1. Clones or refreshes `git@github.com:chanyeinthaw/pi-setup.git` at `main` into
   `/home/multica/.pi/agent` and runs `pnpm install`.
2. Clones or refreshes the Multica fork at
   `feat/pi-thinking-model-resolution` and runs `pnpm install`.
3. Builds `server/bin/multica` with `make build`.
4. Configures the CLI using `MULTICA_TOKEN`.
5. Starts `multica daemon` in the foreground.

## Required first-time setup

The repositories use SSH URLs. The container needs GitHub SSH authentication.
For a long-lived service, mount a dedicated read-only deploy key rather than
sharing the host's private key or forwarding the host SSH agent.

The Compose service forwards the host SSH agent at
`/run/user/1000/gcr/ssh`, so the GitHub SSH identity stays on silicon. The
entrypoint also installs GitHub's host key into the persistent runtime SSH
directory. Verify the agent has a GitHub-capable key before starting:

```bash
ssh-add -L
ssh -T git@github.com
```

The host's public keys from oxygen and silicon are imported into
`authorized_keys` for incoming SSH access; they are not copied as private keys.

Create the runtime env file:

```bash
cp apps/multica-daemon/.env.example apps/multica-daemon/.env
# Set MULTICA_TOKEN and TAILSCALE_AUTHKEY if required.
```

## Start

```bash
mise run multica-daemon:up
```

or:

```bash
docker compose -f apps/multica-daemon/compose.yaml up -d --build --wait
```

Follow logs:

```bash
mise run multica-daemon:logs
```

Stop without removing data:

```bash
mise run multica-daemon:down
```

## Persistent data

- `data/home`: `/home/multica`, including CLI auth, Pi state, and daemon state
- `data/workspace`: `/workspace`, the task workspace root
- `data/tailscale`: Tailscale node state
- `data/ssh-host-keys`: SSH host keys

These paths are ignored by Git.

## SSH access

SSH is published on the host's Tailscale IP at port `55222` in the current
`.env`:

```bash
ssh -p 55222 multica@100.68.212.40
```

The oxygen and silicon public keys are imported into the container's
`authorized_keys`. SSH login shells load the mise-managed toolchain, so
`mise`, `node`, `bun`, `pnpm`, `go`, and `pi` are available directly after SSH.
To use localhost instead, set `SSH_BIND_ADDRESS=127.0.0.1`.

## Tailscale

Tailscale is disabled by default. To enable it, set in `.env`:

```dotenv
TAILSCALE_ENABLED=true
TAILSCALE_AUTHKEY=tskey-auth-...
```

The container runs its own Tailscale node and persists its identity in
`data/tailscale`. It requires `/dev/net/tun`, `NET_ADMIN`, and `NET_RAW`, which
are already present in the Compose file. Prefer a tagged, reusable auth key
with an expiry and least privilege.

## Important security notes

- `MULTICA_TOKEN` is a bearer credential. Keep `.env` private and rotate the
  token if it is exposed.
- Passwordless sudo gives agent tasks root-equivalent access inside the
  container. This is intentional but is not a security boundary against a
  compromised host or a container escape.
- A Docker container does not automatically have the host's full network
  identity. Use the normal Docker network for outbound access, or enable the
  separate Tailscale node when the runtime needs tailnet identity.
- Do not mount the host Docker socket unless you explicitly want agents to
  control every container on the host.
