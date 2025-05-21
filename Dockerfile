# 1.87.0-alpine3.21
FROM rust@sha256:fa7c28576553c431224a85c897c38f3a6443bd831be37061ab3560d9e797dc82 AS base
RUN apk add --no-cache musl-dev=1.2.5-r9 \
    && cargo install cargo-chef@0.1.71

RUN addgroup -g 10001 \
             -S nonroot \
    && adduser -G nonroot \
               -h /home/nonroot \
               -S \
               -u 10000 nonroot
USER nonroot:nonroot
WORKDIR /home/nonroot

FROM base AS prepare
COPY --chmod=0644 \
     --chown=nonroot:nonroot . .
RUN cargo chef prepare --recipe-path recipe.json

FROM base AS build
ENV CARGO_HOME=/home/nonroot/.cargo

COPY --chmod=0644 \
     --chown=nonroot:nonroot \
     --from=prepare /home/nonroot/recipe.json .
RUN cargo chef cook --recipe-path recipe.json \
                    --release \
                    --target x86_64-unknown-linux-musl

COPY --chmod=0755 \
     --chown=nonroot:nonroot . .
RUN --mount=type=cache,target=/home/nonroot/.cargo/.crates.toml,uid=10000,gid=10001,mode=0755 \
    --mount=type=cache,target=/home/nonroot/.cargo/.crates2.json,uid=10000,gid=10001,mode=0755 \
    --mount=type=cache,target=/home/nonroot/.cargo/bin,uid=10000,gid=10001,mode=0755 \
    --mount=type=cache,target=/home/nonroot/.cargo/git/db,uid=10000,gid=10001,mode=0755 \
    --mount=type=cache,target=/home/nonroot/.cargo/registry/cache,uid=10000,gid=10001,mode=0755 \
    --mount=type=cache,target=/home/nonroot/.cargo/registry/index,uid=10000,gid=10001,mode=0755 cargo build --bin nayud-pos \
                                                                                                            -r \
                                                                                                            --target x86_64-unknown-linux-musl

FROM scratch
LABEL name="nayud-pos" \
      version="1.0.0"

ARG TINI_VERSION=v0.19.0
ADD --checksum=sha256:c5b0666b4cb676901f90dfcb37106783c5fe2077b04590973b885950611b30ee \
    --chmod=0755 https://github.com/krallin/tini/releases/download/$TINI_VERSION/tini-static \
                 /tini

COPY --chmod=0755 \
     --from=build /home/nonroot/target/x86_64-unknown-linux-musl/release/nayud-pos .

EXPOSE 8080

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/tini", "--", "./nayud-pos"]