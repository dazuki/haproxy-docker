# HAProxy Docker/Podman Container

Senast uppdaterad: 2026-11-19

HAProxy 3.4 LTS för `https://mcp.domain.se/<tjänst>/`.

```
compose.yaml                 Specifik image - Nätverk `mcp-net`
reload.sh                    haproxy -c, Omladdning utan avbrott för config filer - `haproxy -c -f conf.d -f services`
haproxy/conf.d/00-main.cfg   Global, TLS, Frontend :443, Filter
haproxy/acl/*.lst.example    Tillåtna Källor, Värdnamn, Origin
haproxy/services/*.disabled  Exempel: `webservice`, `mcpservice`
haproxy/ssl/*                Gitignorerad SSL mapp
```

## Certifikat

```bash
{ cat <leaf>.crt; echo; cat <intermediate>.crt; } > haproxy/ssl/fullchain.pem
cp <key> haproxy/ssl/privkey.pem && chmod 600 haproxy/ssl/privkey.pem
./reload.sh
openssl s_client -connect mcp.domain.se:443 -servername mcp.domain.se </dev/null 2>/dev/null | grep "Verify return"
```

Saknad intermediate syns inte i webbläsare men får MCP-klienter att fallera.

## Starta HAProxy Container

```bash
podman network create mcp-net                                              # !! Görs en gång endast !!
for f in haproxy/acl/*.lst.example; do cp -n "$f" "${f%.example}"; done    # !! Görs en gång endast !!
podman-compose up -d
podman exec haproxy-proxy wget -qO- http://127.0.0.1:8405/healthz          # Se hälsa på container
podman logs -f haproxy-proxy                                               # Loggar
```

Saknat certifikat eller saknad `.lst` stoppar start.

## Lägg Till Ny MCP Eller Webtjänst

```bash
cp haproxy/services/mcpservice.cfg.disabled haproxy/services/nymcpservice.cfg  # Mall för ny MCP tjänst
sed -i 's/mcpservice/nymcpservice/g' haproxy/services/nymcpservice.cfg         # Rätta till server-raden
./reload.sh                                                                    # Felaktig config avvisas
```

Upstream ligger på `mcp-net` utan publicerad port (`expose`), i drop-in `server app <containernamn>:3000`. MCP-tjänster måste själva kräva token.

## Allowlistor

Redigera `haproxy/acl/*.lst`, sedan `./reload.sh`.

- `allow-src.lst`: IP/subnet.
- `allow-host.lst`: `mcp.domain.se`.
- `allow-origin.lst`: `https://ai.domain.se`, `https://mcp.domain.se`.

## Uppdatera HAProxy Image

```bash
TAG=3.4.9-alpine
curl -s "https://hub.docker.com/v2/repositories/library/haproxy/tags/$TAG" | jq -r .digest
# sätt docker.io/library/haproxy:$TAG@<digest> i compose.yaml, sedan:
podman-compose up -d --force-recreate
```

## Drift På Servern

Alla `podman`-kommandon och `./reload.sh` körs som root (`sudo`). Utan root ser HAProxy inte klientens IP och källfiltret blockerar allt.

```bash
sudo systemctl enable --now podman-restart     # Startar containrar efter omstart av servern
sudo podman logs haproxy-proxy | tail          # Första fältet = klientens maskerade IP (t.ex. 198.51.100.0), inte 10.89.x.x
```
