# Multica Docker Runtime

This service runs the Multica agent daemon inside a Docker container instead of
installing the daemon on the host.

The image includes:

- mise
- Node.js, Bun, pnpm, Go, and Pi installed through mise
- Pi's executable directory on PATH (`.../installs/pi/0.84.1/pi`), so the
  Multica daemon resolves the actual Pi binary instead of the mise command shim
- Git, GitHub CLI (`gh`), and a global Git identity
- passwordless sudo for the `multica` user
- OpenSSH server
- optional Tailscale support

The image builds the Multica CLI from the pinned commit in the fork's
`feat/pi-thinking-model-resolution` branch. The image currently pins:

```text
4dd2a04031ce32200212aeb960d14adec30d2e44
```

At startup it:

1. Clones or refreshes `git@github.com:chanyeinthaw/pi-setup.git` at `main` into
   `/home/multica/.pi/agent` and runs `pnpm install`.
2. Configures the built-in Multica CLI using `MULTICA_TOKEN`.
3. Starts `multica daemon` in the foreground.

Pi setup remains a runtime checkout because it owns the persistent model
configuration, settings, extensions, and authentication state. Multica source
and Go build dependencies are not present in the running container.

## Required first-time setup

The repositories use SSH URLs. The container needs GitHub SSH authentication.
For a long-lived service, mount a dedicated read-only deploy key rather than
sharing the host's private key or forwarding the host SSH agent.

The image build forwards the host SSH agent for the private Multica fork.
The Compose service also forwards the host SSH agent at
`/run/user/1000/gcr/ssh`, so the GitHub SSH identity stays on silicon for Pi
setup updates and agent tasks. The entrypoint installs GitHub's host key into
the persistent runtime SSH directory. Verify the agent has a GitHub-capable key
before building:

```bash
ssh-add -L
ssh -T git@github.com

DOCKER_BUILDKIT=1 docker compose -f apps/multica-daemon/compose.yaml build
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

- `data/home/multica`: `/home/multica/.multica`, including Multica CLI and daemon state
- `data/home/pi`: `/home/multica/.pi`, including Pi setup and authentication state
- `data/home/gh`: `/home/multica/.config/gh`, including GitHub CLI authentication
- `data/home/ssh`: `/home/multica/.ssh`, including incoming SSH keys and known hosts
- `data/workspace`: `/workspace`, the task workspace root
- `data/tailscale`: Tailscale node state
- `data/ssh-host-keys`: SSH host keys

These paths are ignored by Git.

The Multica CLI is updated by changing `MULTICA_COMMIT`, the related version
metadata, and rebuilding the image. `PI_SETUP_REF=main` is intentionally
refreshed at container startup.

## SSH access

SSH is published on the host's Tailscale IP at port `55222` in the current
`.env`:

```bash
ssh -p 55222 multica@100.68.212.40
```

The oxygen and silicon public keys are imported into the container's
`authorized_keys`. SSH login shells load the mise-managed toolchain, so
`mise`, `node`, `bun`, `pnpm`, `go`, `pi`, and `gh` are available directly
after SSH. To use localhost instead, set `SSH_BIND_ADDRESS=127.0.0.1`.

GitHub CLI stores its configuration in the persistent
`/home/multica/.config/gh` mount. To authenticate manually after connecting by
SSH, run:

```bash
gh auth login --hostname github.com --git-protocol ssh --web
```

The container setup does not initiate this flow automatically.

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
