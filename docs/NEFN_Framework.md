# NEFN Framework Documentation
## A Modular Godot Multiplayer Framework (Nakama, ENet, NetFox, Noray)

## Table of Contents
1. [Introduction](#introduction)
2. [Core Components](#core-components)
3. [Server Implementation](#server-implementation)
4. [Features](#features)
5. [Usage Guide](#usage-guide)
6. [Configuration](#configuration)
7. [API Reference](#api-reference)

## Introduction
NEFN is a comprehensive multiplayer framework for Godot 4.x that integrates Nakama, ENet, NetFox, and Noray to provide a robust, scalable networking solution. The framework is designed for demanding multiplayer games requiring low-latency networking, large player counts, and persistent backend services.

## Core Components

### Server Manager (`NEFNServerManager`)
The central component handling server operations, networking, and game state management.

#### Key Features:
- Multiple server modes (Normal, Headless, Dedicated)
- Built-in anti-cheat system
- Rollback netcode support
- Performance monitoring and metrics
- Automatic backup system
- Command system for server administration

### Server Configuration (`NEFNServerConfig`)
Handles all server-side settings and configuration options.

#### Configurable Options:
- Network settings (IP, port, max clients)
- Performance options (multithreading, packet batching)
- Anti-cheat settings
- Rollback netcode parameters

## Server Implementation

### Server Modes
```gdscript
const MODE_NORMAL := 0    # Regular game server with UI
const MODE_HEADLESS := 1  # Command-line server
const MODE_DEDICATED := 2 # Dedicated server mode
```

### Networking Features
- Automatic headless mode detection
- Configurable tick rate
- Client connection management
- State synchronization
- Input validation

### Anti-Cheat System
- Speed hack detection
- Position validation
- Packet rate limiting
- Action validation
- Violation tracking and auto-banning

### Performance Monitoring
```gdscript
var server_metrics: Dictionary = {
    "start_time": 0,
    "uptime": 0,
    "total_connections": 0,
    "peak_players": 0,
    "total_bytes_sent": 0,
    "total_bytes_received": 0,
    "average_ping": 0.0,
    "cpu_usage": 0.0,
    "memory_usage": 0.0,
    "network_loss": 0.0
}
```

### Backup System
- Automatic state backups
- Configurable backup intervals
- Backup rotation
- JSON-based backup format

### Command System
Built-in commands:
- `help`: Show available commands
- `status`: Display server status
- `players`: List connected players
- `kick`: Kick a player
- `ban`: Ban a player
- `backup`: Create manual backup
- `restart`: Restart server

## Features

### Rollback Netcode
- State history management
- Input recording and replay
- State validation
- Automatic reconciliation

### Player Management
- Connection tracking
- State synchronization
- Action validation
- Ban system

### Action System
Supported action types:
- Attacks
- Interactions
- Abilities
- Item usage

## Usage Guide

### Starting the Server
```gdscript
var config = NEFNServerConfig.new()
config.server_ip = "0.0.0.0"
config.port = 7350
config.max_clients = 32

var server = NEFNServerManager.new(config)
server.start_server()
```

### Handling Players
```gdscript
# Connect to signals
server.player_connected.connect(_on_player_connected)
server.player_disconnected.connect(_on_player_disconnected)
server.player_violation.connect(_on_player_violation)
```

### Using the Command System
```gdscript
# Register custom command
server.register_command("custom", _custom_command, "Custom command description")

# Execute command
var result = server.execute_command("status")
print(result)
```

## Configuration

### Network Settings
```gdscript
# Server configuration example
var config = NEFNServerConfig.new()
config.server_ip = "0.0.0.0"
config.port = 7350
config.max_clients = 32
config.tick_rate = 64
config.use_tcp_fallback = true
```

### Anti-Cheat Settings
```gdscript
config.enable_anti_cheat = true
config.speed_hack_detection = true
config.position_validation = true
config.max_violations_before_ban = 5
```

### Performance Settings
```gdscript
config.enable_multithreading = true
config.thread_count = 4
config.enable_dynamic_threading = true
config.packet_batching = true
```

## API Reference

### Signals
```gdscript
signal server_started
signal server_stopped
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal player_violation(peer_id: int, violation: String, count: int)
signal player_banned(player_id: int, reason: String, duration: float)
signal performance_warning(type: String, details: String)
signal rollback_occurred(from_tick: int, to_tick: int, reason: String)
signal log_message(message: String)
```

### Public Methods
```gdscript
func start_server(server_config: NEFNServerConfig = null) -> Error
func stop_server() -> void
func is_server_running() -> bool
func get_connected_peer_count() -> int
func get_max_players() -> int
func get_active_thread_count() -> int
func get_banned_player_count() -> int
func execute_command(command: String) -> String
```

### Utility Methods
```gdscript
func register_command(name: String, callback: Callable, description: String) -> void
func _create_backup() -> void
func _auto_restart_server() -> void
```

## Best Practices

1. Server Configuration
   - Always set appropriate tick rates for your game type
   - Configure thread count based on available CPU cores
   - Enable packet batching for better performance

2. Anti-Cheat
   - Enable all validation features in production
   - Set appropriate thresholds for your game
   - Implement additional custom validations as needed

3. Backup System
   - Enable regular backups in production
   - Set appropriate backup intervals
   - Monitor backup disk usage

4. Performance
   - Monitor server metrics regularly
   - Use dynamic threading when possible
   - Implement proper cleanup in disconnection handlers

## Security Considerations

1. Network Security
   - Always validate client inputs
   - Implement rate limiting
   - Use appropriate encryption for sensitive data

2. Anti-Cheat
   - Implement server-side validation
   - Use multiple detection methods
   - Keep validation thresholds secret

3. Administration
   - Secure command system access
   - Log all administrative actions
   - Implement proper authentication

## Troubleshooting

Common issues and solutions:
1. Connection Issues
   - Check firewall settings
   - Verify port forwarding
   - Check network configuration

2. Performance Issues
   - Monitor server metrics
   - Adjust thread count
   - Check resource usage

3. State Synchronization
   - Verify tick rate settings
   - Check network conditions
   - Monitor rollback frequency 