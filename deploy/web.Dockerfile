# Static host for the Godot HTML5 client export.
# Build context = repo root:  docker build -f deploy/web.Dockerfile -t rooftop-web .
# Requires `build/web/` to exist (run the Web export first — see docs/SETUP.md).
FROM caddy:2-alpine
COPY deploy/Caddyfile /etc/caddy/Caddyfile
COPY build/web /usr/share/caddy
