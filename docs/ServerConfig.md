# NEFN Server Configuration Guide

## Overview
The `NEFNServerConfig` resource provides comprehensive configuration options for the NEFN server. This guide details all available settings and their implications.

## Network Settings

### Basic Network Configuration
```gdscript
# Server binding
server_ip: String = "0.0.0.0"     # IP address to bind to
port: int = 7350                  # Port to listen on
bind_all_addresses: bool = false  # Whether to bind to all available network interfaces

# Connection limits
max_clients: int = 32            # Maximum number of concurrent clients
use_tcp_fallback: bool = true    # Whether to fall back to TCP if UDP fails
```

### Network Performance
```gdscript
tick_rate: int = 64              # Server tick rate (updates per second)
max_packets_per_second: int = 100 # Maximum packets allowed per client per second
packet_timeout: float = 5.0      # Time before considering a client disconnected
```

## Performance Settings

### Threading Configuration
```gdscript
enable_multithreading: bool = true   # Enable multi-threaded processing
thread_count: int = 4                # Number of worker threads
enable_dynamic_threading: bool = true # Dynamically adjust thread count
min_threads: int = 2                 # Minimum number of threads
max_threads: int = 16                # Maximum number of threads
```

### Resource Management
```gdscript
cpu_threshold_high: float = 80.0     # CPU usage threshold for reducing threads
cpu_threshold_low: float = 20.0      # CPU usage threshold for adding threads
max_memory_mb: float = 1024.0        # Maximum memory usage in MB
```

## Anti-Cheat Settings

### Detection Settings
```gdscript
enable_anti_cheat: bool = true       # Master switch for anti-cheat
speed_hack_detection: bool = true    # Detect speed hacking
position_validation: bool = true     # Validate player positions
damage_validation: bool = true       # Validate damage values
packet_validation: bool = true       # Validate packet rates
memory_validation: bool = true       # Validate memory modifications
input_validation: bool = true        # Validate player inputs
state_validation: bool = true        # Validate game state
```

### Thresholds
```gdscript
max_player_speed: float = 10.0       # Maximum allowed player speed
max_position_delta: float = 5.0      # Maximum position change per tick
max_damage_per_hit: float = 100.0    # Maximum damage per hit
max_input_rate: int = 60            # Maximum inputs per second
```

### Violation Handling
```gdscript
violation_tracking: bool = true           # Track player violations
max_violations_before_ban: int = 10      # Violations before auto-ban
violation_reset_time: float = 3600.0     # Time before violations reset (seconds)
```

## Logging Settings

### Basic Logging
```gdscript
enable_logging: bool = true          # Enable logging
log_to_file: bool = true            # Save logs to file
log_to_console: bool = true         # Output logs to console
```

### Log File Management
```gdscript
log_file_path: String = "user://server_logs/"  # Log file location
log_rotation_size_mb: float = 10.0             # Size before rotating logs
max_log_files: int = 5                         # Maximum number of log files
```

### Log Configuration
```gdscript
log_level: int = 2                   # 0=None, 1=Error, 2=Warning, 3=Info, 4=Debug
log_categories: Array[String] = [     # Categories to log
    "security",
    "network",
    "performance",
    "admin",
    "player"
]
log_format: String = "[{datetime}] [{category}] [{level}] {message}"
include_stack_traces: bool = true    # Include stack traces in error logs
```

## Server Authority Settings

### Administration
```gdscript
admin_enabled: bool = false          # Enable admin features
admin_password: String = ""          # Admin access password
headless_mode: bool = false         # Run in headless mode
```

### Admin Controls
```gdscript
max_admin_attempts: int = 3          # Maximum failed admin login attempts
admin_ban_duration: float = 3600.0   # Admin ban duration (seconds)
admin_command_cooldown: float = 0.5  # Cooldown between admin commands
```

## Best Practices

1. Network Configuration
   - Set appropriate tick rates for your game type
   - Configure max_clients based on server resources
   - Enable TCP fallback for reliability

2. Performance Tuning
   - Adjust thread count based on CPU cores
   - Set appropriate memory limits
   - Monitor and adjust thresholds

3. Anti-Cheat Configuration
   - Enable all validations in production
   - Set realistic thresholds for your game
   - Configure violation tracking

4. Logging Setup
   - Enable file logging in production
   - Set appropriate log rotation
   - Configure relevant categories

## Example Configurations

### High-Performance FPS Server
```gdscript
var config = NEFNServerConfig.new()
config.tick_rate = 128
config.enable_multithreading = true
config.thread_count = 8
config.max_clients = 32
config.enable_anti_cheat = true
config.speed_hack_detection = true
config.position_validation = true
```

### MMO Zone Server
```gdscript
var config = NEFNServerConfig.new()
config.tick_rate = 20
config.max_clients = 200
config.enable_dynamic_threading = true
config.packet_batching = true
config.violation_tracking = true
config.log_to_file = true
```

### Local Development Server
```gdscript
var config = NEFNServerConfig.new()
config.server_ip = "127.0.0.1"
config.port = 7350
config.max_clients = 4
config.enable_anti_cheat = false
config.log_level = 4  # Debug
config.log_to_console = true
``` 