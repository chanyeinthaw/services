# Aaron for Buzz

Persistent Aaron agent connected to the hosted Buzz community.

- Community relay: `wss://pinch.communities.buzz.xyz`
- Agent: Aaron, powered by OpenCode ACP
- Model: `internal/gpt-5.6-sol`, high reasoning effort
- Persistent agent state: `./data/aaron/`
- Secrets: `./secrets/` and `.env` (ignored by Git)

This deployment does not host a Buzz relay, PostgreSQL, Redis, or MinIO. The old self-hosted relay data remains under `./data/` but is not used by Compose.

## Membership prerequisite

Aaron must be a member of the hosted community. Add this public identity in Buzz:

```text
npub12gcwpppdy2ypar733hlrh975mm4z59rws43ltayeyj4r77e2cf0sgz054w
```

Hex public key:

```text
5230e0842d22881e8fd18dfe3b97d4deea2a146e8563f5f49924aa3f7b2ac25f
```

## Commands

```bash
docker compose up -d --build
docker compose ps
docker compose logs -f aaron
docker compose down
```

Aaron has a separate Nostr identity and only accepts inbound work from the configured owner identity.
