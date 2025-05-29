extends Resource
class_name NEFNServerConfig

# Network Settings
@export_group("Network")
@export var server_ip: String = "0.0.0.0"  # Bind to all interfaces by default
@export_range(1, 65535) var port: int = 7350
@export var max_clients: int = 32
@export var use_ssl: bool = false
@export var ssl_certificate: String = ""
@export var ssl_key: String = ""
@export var tick_rate: int = 64
@export var use_tcp_fallback: bool = true
@export var connection_timeout: float = 10.0

# Performance Settings
@export_group("Performance")
@export var enable_multithreading: bool = true
@export_range(1, 32) var thread_count: int = 4
@export var enable_dynamic_threading: bool = true
@export var min_threads: int = 2
@export var max_threads: int = 16
@export var cpu_threshold_high: float = 80.0  # Reduce threads above this CPU %
@export var cpu_threshold_low: float = 40.0   # Increase threads below this CPU %
@export var max_memory_mb: float = 1024.0     # Max memory usage in MB
@export var enable_packet_batching: bool = true
@export var batch_interval: float = 0.05      # 50ms batching window

# Rollback & Netcode Settings
@export_group("Netcode")
@export var enable_rollback: bool = true
@export var rollback_frames: int = 7          # Number of frames to roll back
@export var input_delay_frames: int = 2       # Input delay for prediction
@export var max_rollback_frames: int = 10     # Maximum allowed rollback
@export var sync_interval_ms: int = 100       # State sync interval
@export var interpolation_delay: int = 2      # Frame delay for interpolation
@export var extrapolation_limit: int = 5      # Max frames to extrapolate
@export var jitter_buffer_ms: int = 100       # Jitter buffer size

# Anti-Cheat Settings
@export_group("Security")
@export var enable_anti_cheat: bool = true
@export var validate_movement: bool = true
@export var max_player_speed: float = 1000.0
@export var position_error_threshold: float = 100.0
@export var enable_speed_hack_detection: bool = true
@export var enable_wall_hack_detection: bool = true
@export var packet_validation: bool = true
@export var max_packets_per_second: int = 100
@export var enable_encryption: bool = true
@export var encryption_key: String = ""

# Admin Settings
@export_group("Admin")
@export var enable_admin_system: bool = true
@export var admin_password: String = ""  # Set this in production!
@export var admin_roles: Dictionary = {
	"owner": {"level": 100, "commands": ["*"]},  # All commands
	"admin": {"level": 80, "commands": ["kick", "ban", "mute", "teleport", "give", "take"]},
	"moderator": {"level": 50, "commands": ["kick", "mute", "teleport"]},
	"helper": {"level": 20, "commands": ["mute"]}
}
@export var admin_command_cooldown: float = 1.0  # Seconds between commands
@export var admin_log_commands: bool = true
@export var admin_log_file: String = "user://logs/admin.log"
@export var max_ban_duration_hours: int = 720  # 30 days
@export var max_mute_duration_hours: int = 168  # 7 days
@export var admin_audit_enabled: bool = true
@export var admin_audit_retention_days: int = 30
@export var admin_webhook_url: String = ""  # Discord/Slack webhook for notifications
@export var admin_require_2fa: bool = false
@export var admin_session_timeout: int = 3600  # 1 hour
@export var admin_max_failed_logins: int = 5
@export var admin_lockout_duration: int = 1800  # 30 minutes
@export var admin_ip_whitelist: Array[String] = []

# Monitoring & Logging
@export_group("Monitoring")
@export var enable_metrics: bool = true
@export var metrics_interval: float = 1.0
@export var log_level: int = 2  # 0=None, 1=Error, 2=Warning, 3=Info, 4=Debug
@export var enable_performance_logging: bool = true
@export var log_to_file: bool = true
@export var log_file_path: String = "user://server_logs/"
@export var max_log_size_mb: float = 10.0
@export var max_log_files: int = 5

# Server Management
@export_group("Management")
@export var enable_auto_restart: bool = true
@export var restart_interval_hours: float = 24.0
@export var enable_auto_backup: bool = true
@export var backup_interval_hours: float = 1.0
@export var max_backups: int = 24
@export var enable_maintenance_mode: bool = false
@export var maintenance_message: String = "Server is under maintenance"

# DNS & Discovery
@export_group("Discovery")
@export var register_with_dns: bool = true
@export var server_name: String = "NEFN Game Server"
@export var server_region: String = "us-west"
@export var server_tags: Array[String] = []
@export var heartbeat_interval: float = 30.0

# Custom Properties
var _custom_properties: Dictionary = {}

func set_custom_property(key: String, value: Variant) -> void:
	_custom_properties[key] = value

func get_custom_property(key: String, default: Variant = null) -> Variant:
	return _custom_properties.get(key, default)

func _init() -> void:
	# Generate a random encryption key if none is set
	if encryption_key.is_empty() and enable_encryption:
		# Generate a secure random key
		var rb = RandomNumberGenerator.new()
		rb.randomize()
		var key = PackedByteArray()
		for i in range(32):  # 256-bit key
			key.append(rb.randi() % 256)
		encryption_key = key.hex_encode()
		
	# Generate default admin password if none set
	if admin_password.is_empty() and enable_admin_system:
		var rb = RandomNumberGenerator.new()
		rb.randomize()
		var chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
		var password = ""
		for i in range(16):
			password += chars[rb.randi() % chars.length()]
		admin_password = password
		print("WARNING: Generated default admin password: " + password)
		print("Please change this password in production!") 
