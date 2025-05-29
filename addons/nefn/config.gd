class_name NEFNConfiguration
extends Resource

# Nakama Configuration
@export var nakama_server_key: String = "defaultkey"
@export var nakama_host: String = "127.0.0.1"
@export var nakama_port: int = 7350
@export var nakama_use_ssl: bool = false

# ENet Configuration
@export var enet_port: int = 7777
@export var enet_max_clients: int = 32

# Noray Configuration
@export var noray_enabled: bool = true
@export var noray_quality: int = 5
@export var noray_port: int = 7778

# Debug Configuration
@export var debug_console_enabled: bool = true 
