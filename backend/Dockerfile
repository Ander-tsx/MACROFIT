# Imagen del backend. El contexto de build es la raíz del repositorio (no backend/):
# el aviso de privacidad se embebe desde docs/legal con include_str!.
#
#   docker build -f backend/Dockerfile -t macrofit-backend .

FROM rust:1-slim-bookworm AS build
WORKDIR /repo

# Dependencias primero, para que la caché de capas sobreviva a los cambios de código.
COPY backend/Cargo.toml backend/Cargo.lock backend/
RUN mkdir -p backend/src/bin \
    && echo "fn main() {}" > backend/src/main.rs \
    && echo "" > backend/src/lib.rs \
    && echo "fn main() {}" > backend/src/bin/seed_exercises.rs \
    && cargo build --release --manifest-path backend/Cargo.toml --bin backend

COPY backend/src backend/src
COPY docs docs
RUN touch backend/src/main.rs backend/src/lib.rs \
    && cargo build --release --manifest-path backend/Cargo.toml --bin backend

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /repo/backend/target/release/backend /usr/local/bin/backend

# La plataforma inyecta PORT; el servidor ya escucha en 0.0.0.0.
CMD ["backend"]
