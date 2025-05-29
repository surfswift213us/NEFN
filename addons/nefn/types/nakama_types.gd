class_name NakamaTypes
extends RefCounted

# Client class
class Client extends RefCounted:
	func authenticate_device_async(device_id: String) -> Session:
		return Session.new()
	
	func authenticate_email_async(email: String, password: String) -> Session:
		return Session.new()
	
	func session_logout_async(session: Session) -> void:
		pass

# Session class
class Session extends RefCounted:
	var token: String
	var refresh_token: String
	var user_id: String
	var username: String
	var create_time: int
	var expire_time: int
	var is_expired: bool
	var vars: Dictionary
	
	func is_exception() -> bool:
		return false
	
	func get_exception() -> Dictionary:
		return {}

# Socket class
class Socket extends RefCounted:
	signal connected
	signal closed
	signal received_error(p_exception)
	signal received_notification(p_notification)
	
	func close() -> void:
		pass

# API Response types
class ApiAccount extends RefCounted:
	var user: Dictionary
	var wallet: String
	var email: String
	var devices: Array
	var custom_id: String
	var verify_time: int

class ApiSession extends RefCounted:
	var token: String
	var refresh_token: String
	var created: bool

class ApiNotification extends RefCounted:
	var id: String
	var subject: String
	var content: Dictionary
	var code: int
	var sender_id: String
	var create_time: int
	var persistent: bool

# Static methods
static func create_client(
	p_server_key: String = "defaultkey",
	p_host: String = "127.0.0.1",
	p_port: int = 7350,
	p_scheme: String = "http"
) -> Client:
	return Client.new() 
