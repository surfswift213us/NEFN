# Docker Setup Guide for NEFN Framework

## Overview

This guide covers Docker deployment for all NEFN framework components:
- Game Server (Godot)
- Nakama Server
- Noray Server
- Database (PostgreSQL)

## Prerequisites

- Docker Engine 20.10.0+
- Docker Compose 2.0.0+
- At least 4GB RAM
- 20GB disk space

## Quick Start

1. Clone the repository and navigate to it:
```bash
git clone https://github.com/yourusername/nefn-framework.git
cd nefn-framework
```

2. Start all services:
```bash
docker-compose up -d
```

## Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  # Game Server
  nefn-server:
    build:
      context: .
      dockerfile: Dockerfile.server
    ports:
      - "7350:7350/udp"  # Game server port
    environment:
      - GODOT_SERVER_MODE=true
      - NAKAMA_HOST=nakama
      - NAKAMA_PORT=7350
      - NORAY_HOST=noray
      - NORAY_PORT=7000
    depends_on:
      - nakama
      - noray
    volumes:
      - ./server_data:/app/data
    restart: unless-stopped

  # Nakama Server
  nakama:
    image: heroiclabs/nakama:3.17.0
    ports:
      - "7349:7349"  # API
      - "7351:7351"  # gRPC
    environment:
      - NAKAMA_NAME=nefn-nakama
      - NAKAMA_DATABASE_HOST=postgres
      - NAKAMA_DATABASE_USER=postgres
      - NAKAMA_DATABASE_PASSWORD=your_password
    depends_on:
      - postgres
    volumes:
      - ./nakama_data:/nakama/data
    restart: unless-stopped

  # Noray Server
  noray:
    build:
      context: .
      dockerfile: Dockerfile.noray
    ports:
      - "7000:7000/udp"  # Noray port
    environment:
      - NORAY_MAX_CLIENTS=1000
      - NORAY_TIMEOUT=30
    restart: unless-stopped

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=nakama
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=your_password
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
```

## Dockerfile for Game Server

Create `Dockerfile.server`:

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Godot Headless
RUN wget https://downloads.tuxfamily.org/godotengine/4.2/Godot_v4.2-stable_linux_headless.64.zip \
    && unzip Godot_v4.2-stable_linux_headless.64.zip \
    && mv Godot_v4.2-stable_linux_headless.64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm Godot_v4.2-stable_linux_headless.64.zip

# Create app directory
WORKDIR /app

# Copy game files
COPY ./game_server .
COPY ./addons/nefn ./addons/nefn

# Export variables
ENV GODOT_SERVER_MODE=true

# Start server
CMD ["godot", "--headless", "--main-pack", "server.pck"]
```

## Dockerfile for Noray Server

Create `Dockerfile.noray`:

```dockerfile
FROM golang:1.21-alpine

WORKDIR /app

# Copy Noray source
COPY ./noray .

# Build Noray
RUN go build -o noray cmd/noray/main.go

# Expose port
EXPOSE 7000/udp

# Start server
CMD ["./noray"]
```

## Environment Configuration

Create `.env` file:

```env
# Game Server
GODOT_SERVER_MODE=true
SERVER_PORT=7350
MAX_CLIENTS=1000

# Nakama
NAKAMA_HOST=nakama
NAKAMA_PORT=7350
NAKAMA_SERVER_KEY=your_server_key
NAKAMA_ADMIN_USER=admin
NAKAMA_ADMIN_PASSWORD=your_admin_password

# Noray
NORAY_HOST=noray
NORAY_PORT=7000
NORAY_MAX_CLIENTS=1000
NORAY_TIMEOUT=30

# Database
POSTGRES_DB=nakama
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_password
```

## Production Deployment

### System Requirements

- CPU: 4+ cores
- RAM: 8GB+ recommended
- Storage: SSD recommended
- Network: 100Mbps+ recommended

### Security Configuration

1. Update passwords in `.env`
2. Configure firewalls to only allow necessary ports
3. Set up SSL/TLS for Nakama admin console
4. Use Docker secrets for sensitive data

### Monitoring Setup

1. Configure logging:
```yaml
# In docker-compose.yml
services:
  nefn-server:
    logging:
      driver: "json-file"
      options:
        max-size: "200m"
        max-file: "10"
```

2. Set up monitoring tools:
```yaml
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
```

### Backup Configuration

1. Create backup script:
```bash
#!/bin/bash
# backup.sh

# Backup PostgreSQL
docker exec postgres pg_dump -U postgres nakama > backup/nakama_$(date +%Y%m%d).sql

# Backup game data
docker exec nefn-server tar czf /backup/game_$(date +%Y%m%d).tar.gz /app/data
```

2. Set up cron job:
```bash
0 0 * * * /path/to/backup.sh
```

## Scaling

### Horizontal Scaling

1. Update docker-compose for scaling:
```yaml
services:
  nefn-server:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '2'
          memory: 4G
```

2. Add load balancer:
```yaml
  traefik:
    image: traefik:v2.10
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
    ports:
      - "80:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

## Troubleshooting

### Common Issues

1. Container won't start:
```bash
# Check logs
docker-compose logs [service_name]

# Check resource usage
docker stats
```

2. Network issues:
```bash
# Check network
docker network ls
docker network inspect nefn_default
```

3. Database connection issues:
```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Connect to database
docker exec -it postgres psql -U postgres nakama
```

### Maintenance Commands

```bash
# Update containers
docker-compose pull
docker-compose up -d

# Clean up
docker system prune -a

# View logs
docker-compose logs -f --tail=100

# Restart service
docker-compose restart [service_name]
```

## Development Setup

For local development:

1. Create development compose file:
```yaml
# docker-compose.dev.yml
version: '3.8'
services:
  nefn-server:
    build:
      target: development
    volumes:
      - .:/app
    environment:
      - GODOT_DEBUG=true
```

2. Run development environment:
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
``` 