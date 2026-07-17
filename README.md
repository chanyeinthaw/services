# Services

Development infrastructure managed with Docker Compose, mise tasks, and user-level systemd units.

## Endpoints

| Service | Address | User | Password | Database |
| --- | --- | --- | --- | --- |
| MySQL 8 | `mysql.database.internal` | `root` | `dev-mysql-root` | `development` |
| MySQL 8 | `mysql.database.internal` | `developer` | `dev-mysql` | `development` |
| PostgreSQL 18.4 | `pg.database.internal` | `postgres` | `dev-postgres` | `development` |
| Redis 8 | `redis.cache.internal` | — | `dev-redis` | — |
| LLM proxy (browser management) | `https://llm.app.internal` | API/management key | — | — |
| LLM proxy (API clients/harnesses) | `https://llm.tail****.ts.net` | API key | — | — |

The Compose ports bind only to localhost: MySQL on `127.0.0.1:3306`, PostgreSQL on `127.0.0.1:5432`, Redis on `127.0.0.1:6379`, and CLIProxyAPI on `127.0.0.1:8320`. Tailscale Services expose the database/cache endpoints and the LLM proxy to the tailnet. CoreDNS aliases the friendly database/cache names to their Tailscale Service MagicDNS names.

For browser-based management, Caddy terminates locally trusted TLS for `llm.app.internal` and reverse-proxies it to CLIProxyAPI at `127.0.0.1:8320`. CoreDNS resolves `llm.app.internal` to this host's Tailscale IP. For API clients and harnesses, the `svc:llm` Tailscale Service terminates HTTPS at `llm.tail****.ts.net:443` and forwards directly to `http://127.0.0.1:8320`.

## Tailscale Services

Each database/cache and the LLM proxy is a Tailscale Service with its own stable MagicDNS name and TailVIP. Tailscale forwards database/cache TCP traffic and LLM HTTPS traffic from each Service to the matching localhost-only Compose port:

| Tailscale Service | Public service endpoint | Local target |
| --- | --- | --- |
| `svc:mysql` | `mysql.tail****.ts.net:3306` | `127.0.0.1:3306` |
| `svc:pg` | `pg.tail****.ts.net:5432` | `127.0.0.1:5432` |
| `svc:redis` | `redis.tail****.ts.net:6379` | `127.0.0.1:6379` |
| `svc:llm` | `https://llm.tail****.ts.net:443` | `http://127.0.0.1:8320` |

The friendly CoreDNS aliases are:

```text
mysql.database.internal CNAME mysql.tail****.ts.net
pg.database.internal    CNAME pg.tail****.ts.net
redis.cache.internal    CNAME redis.tail****.ts.net
```

The service host must use a tag-based Tailscale identity. This host currently uses `tag:services`. The Services and host advertisements must also exist and be approved in the Tailscale admin console. Tailscale Serve configuration belongs to the host's system Tailscale daemon, so use `sudo` consistently when inspecting or changing it.

### Configure or update the endpoints

These are the commands used on this host. `--service` stores the configuration in Tailscale and runs it in background mode, so these commands do not need separate systemd units:

```bash
sudo tailscale serve \
  --service=svc:mysql \
  --tcp=3306 \
  tcp://127.0.0.1:3306

sudo tailscale serve \
  --service=svc:pg \
  --tcp=5432 \
  tcp://127.0.0.1:5432

sudo tailscale serve \
  --service=svc:redis \
  --tcp=6379 \
  tcp://127.0.0.1:6379

sudo tailscale serve \
  --service=svc:llm \
  --https=443 \
  http://127.0.0.1:8320
```

Running a command again updates that endpoint. Inspect all configured Services with:

```bash
sudo tailscale serve status
sudo tailscale serve status --json
```

The status command reports all Services together; it does not take `--service` to filter one Service.

### Remove an endpoint

Use the same Service and TCP port with `off`:

```bash
sudo tailscale serve --service=svc:mysql --tcp=3306 off
sudo tailscale serve --service=svc:pg --tcp=5432 off
sudo tailscale serve --service=svc:redis --tcp=6379 off
sudo tailscale serve --service=svc:llm --https=443 off
```

For graceful maintenance, drain the Service before removing or changing it so existing connections can finish:

```bash
sudo tailscale serve drain svc:mysql
sudo tailscale serve clear svc:mysql
```

`clear` removes all local endpoint mappings for that Service. Avoid `tailscale serve reset` unless you intend to remove the host configuration for every Service on this machine.

### Test connectivity

Clients use each protocol's default port, so no explicit port is required:

```bash
mysql -h mysql.database.internal -u developer -p development
psql -h pg.database.internal -U postgres -d development
redis-cli -h redis.cache.internal -a dev-redis ping
# Browser-based management endpoint
curl https://llm.app.internal/

# Tailnet endpoint for API clients and harnesses
curl https://llm.tail****.ts.net/
```

A Tailscale Service address is a TailVIP rather than a peer device. Therefore, `tailscale ping` can report `no matching peer` even when TCP connections to the Service work correctly. Test with the actual database client or with the appropriate TCP port.

Official documentation: <https://tailscale.com/docs/features/tailscale-services>

## Layout

```text
Services/
├── databases/
│   ├── compose.yaml
│   └── data/
│       ├── mysql8/
│       ├── postgres16/  # retained pre-upgrade data
│       └── postgres18/
├── cache/
│   ├── compose.yaml
│   └── data/redis/
├── apps/
│   └── llm-proxy/
│       ├── compose.yaml
│       ├── config.yaml
│       ├── scripts/init-database.sh
│       └── data/
└── mise.toml
```

Data directories are bind-mounted and are not deleted by `docker compose down`.
Container processes may own files in these directories using their internal numeric UIDs; that is expected.

## Commands

Run these from this directory:

```bash
mise run up
mise run down
mise run status
mise run logs
mise run pull

mise run databases:up
mise run databases:down
mise run databases:logs

mise run cache:up
mise run cache:down
mise run cache:logs

mise run llm-proxy:up
mise run llm-proxy:down
mise run llm-proxy:logs
```

CLIProxyAPI stores its authoritative configuration and authentication records in the local PostgreSQL `cli_proxy` database. `apps/llm-proxy/config.yaml` is copied from `~/Code/llm-proxy` and seeds PostgreSQL only when that database has no stored configuration. Runtime spool files are mirrored under `apps/llm-proxy/data/` and ignored by Git.

## systemd

The user units are:

```text
services-databases.service
services-cache.service
services-llm-proxy.service
```

Manage them with:

```bash
systemctl --user status services-databases services-cache services-llm-proxy
systemctl --user restart services-databases services-cache services-llm-proxy
journalctl --user -u services-databases -u services-cache -u services-llm-proxy
```

The units depend on the rootless user Docker daemon. User lingering is enabled so the services can start at boot without an interactive login.

## Changing initialized credentials

The image initialization variables only apply when a data directory is empty. Editing a password in `compose.yaml` does not change an existing database account. Either change the account inside the database or stop the stack and deliberately remove the corresponding data directory to initialize a fresh development database.
