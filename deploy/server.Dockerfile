# Headless Godot 4.6 dedicated game server for Rooftop Rush.
# Build context = repo root:  docker build -f deploy/server.Dockerfile -t rooftop-server .
#
# The binary is a single embedded-pck export with the `dedicated_server` feature, so it
# auto-starts as the WebSocket server (no --server arg needed) and binds 0.0.0.0:$PORT.
FROM ubuntu:24.04

# glibc base (NOT Alpine — official Godot binaries link glibc). ca-certificates for TLS-
# adjacent libs; libfreetype6 is the one shared lib the headless template still wants.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates libfreetype6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY build/server/rooftop_server.x86_64 /app/rooftop_server
RUN chmod +x /app/rooftop_server

# Shell form so $PORT (injected by Railway) expands; GDScript reads it via OS.get_environment.
CMD ./rooftop_server --headless
