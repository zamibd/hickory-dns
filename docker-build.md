# Hickory DNS Docker Build Guide

This guide provides step-by-step instructions on how to build, run, and configure **Hickory DNS** using Docker.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed on your system.
- [Docker Compose](https://docs.docker.com/compose/install/) (optional, but recommended).

## 1. Build the Docker Image

To build the Docker image from source using the provided `Dockerfile`, run the following command in the root of the repository:

```bash
docker build -t hickory-dns .
```

This process uses a multi-stage build:
- **Builder Stage**: Uses `rust:alpine` to compile the source code with all modern features enabled (DoT, DoH, DoQ, DNSSEC).
- **Runtime Stage**: Uses `alpine:latest` for a minimal, secure, and lightweight final image.

## 2. Running with Docker Compose (Recommended)

The easiest way to run the server is using Docker Compose. A `docker-compose.yml` file is provided.

1.  **Prepare Configuration**:
    Ensure you have your configuration files ready. By default, the compose file expects a `config` directory in the current folder.
    
    *Example logic:*
    ```bash
    mkdir -p config
    # Copy your config.toml and zone files into ./config/
    ```

2.  **Start the Service**:
    ```bash
    docker compose up -d
    ```

3.  **View Logs**:
    ```bash
    docker compose logs -f
    ```

4.  **Stop the Service**:
    ```bash
    docker compose down
    ```

## 3. Running Manually with Docker

If you prefer to run `docker` commands directly:

### Basic Run
```bash
docker run --rm hickory-dns --help
```

### Running with Configuration
Mount your configuration directory to `/config` inside the container:

```bash
docker run -d \
  --name hickory-dns \
  -p 53:53/udp \
  -p 53:53/tcp \
  -v $(pwd)/config:/config \
  hickory-dns \
  -c /config/example.toml -z /config/
```

## 4. Configuration Details

- **Ports**:
    - `53`: DNS (UDP/TCP)
    - `853`: DNS over TLS (DoT) / DNS over QUIC (DoQ)
    - `443`: DNS over HTTPS (DoH)

- **Volumes**:
    - `/config`: Mount your configuration files here.

## 5. Testing

You can test the server using `dig`:

```bash
dig @localhost -p 53 www.example.com
```

If configured correctly, you should receive a DNS response.
