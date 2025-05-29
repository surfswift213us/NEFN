# NEFN Server

This is the server component of the NEFN framework, combining Nakama, ENet, and Noray services in a single Docker container.

## Services

- **Nakama** (Port 7350): Backend server and authentication
- **ENet** (Port 7351): Low-level networking server
- **Noray** (Port 7352): VOIP server

## Setup

1. Install Docker and Docker Compose
2. Clone this repository
3. Build and start the services:
   ```bash
   docker-compose up -d
   ```

## Configuration

- Nakama configuration: `config/nakama.yml`
- Supervisor configuration: `config/supervisord.conf`
- Environment variables in `docker-compose.yml`

## Default Ports

- Nakama API: 7350
- Nakama gRPC: 7349
- ENet Server: 7351
- Noray VOIP: 7352
- PostgreSQL: 5432

## Data Persistence

Data is stored in Docker volumes:
- Nakama data: `./data`
- Nakama modules: `./modules`
- PostgreSQL data: `postgres_data` volume

## Logs

Logs are available in the container at:
- `/var/log/supervisor/nakama.out.log`
- `/var/log/supervisor/enet.out.log`
- `/var/log/supervisor/noray.out.log`

View logs using:
```bash
docker-compose logs -f nefn-server
```

## Security

Default credentials:
- Nakama server key: "defaultkey"
- PostgreSQL password: "nefn_password"

**Important**: Change these values in production! 
