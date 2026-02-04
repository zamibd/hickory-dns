# Builder stage
FROM rust:alpine AS builder

# Install build dependencies
# build-base: for gcc/compilation
# openssl-dev: for networking features
# perl: required by ring/openssl builds
RUN apk add --no-cache build-base openssl-dev perl

WORKDIR /app

# Copy the entire workspace
# We copy everything because it's a workspace and inter-crate dependencies might be complex
COPY . .

# Build the hickory-dns binary
# We explicitly enable features for a full-featured server
# release profile is used for optimization
RUN cargo build --release --bin hickory-dns --features sqlite,resolver,recursor,dnssec-ring,https-ring,tls-ring,quic-ring

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
# ca-certificates: for TLS validation
# openssl: library support
RUN apk add --no-cache ca-certificates openssl

# Create a non-root user for security (optional but recommended, though user didn't explicitly ask, good practice)
# But for simplicity and standard port usage (53 requires root or capabilities), we'll stick to root or user can configure.
# For now, let's keep it simple as requested, running as root to bind port 53 easily.

WORKDIR /usr/local/bin

# Copy the binary from builder
COPY --from=builder /app/target/release/hickory-dns .

# Create a directory for config
RUN mkdir -p /config

# Expose standard DNS ports
# 53: DNS (UDP/TCP)
# 853: DoT (TCP)
# 443: DoH (TCP - common)
# 853: DoQ (UDP - commonly shares with DoT port or uses 853/784)
EXPOSE 53/udp 53/tcp 853/tcp 443/tcp 853/udp

# Set volume for persistence/config if needed
VOLUME ["/config"]

# Entrypoint
ENTRYPOINT ["./hickory-dns"]
CMD ["--help"]
