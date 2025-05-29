@tool
extends Resource
class_name NEFNConfiguration

# Nakama Configuration
@export_group("Nakama Settings")
@export var nakama_host: String = "127.0.0.1"
@export var nakama_port: int = 7350
@export var nakama_server_key: String = "defaultkey"
@export var nakama_use_ssl: bool = false

# ENet Configuration
@export_group("ENet Settings")
@export var enet_port: int = 7351
@export var enet_max_clients: int = 32
@export var enet_channels: int = 2
@export var enet_compression: bool = true

# NetFox Configuration
@export_group("NetFox Settings")
@export var netfox_tick_rate: float = 60.0
@export var netfox_interpolation: bool = true
@export var netfox_extrapolation: bool = true

# Noray Configuration
@export_group("Noray Settings")
@export var noray_enabled: bool = true
@export var noray_quality: int = 5 # 1-10
@export var noray_port: int = 7352

# Debug Settings
@export_group("Debug Settings")
@export var debug_console_enabled: bool = true
@export var debug_logging_enabled: bool = true 