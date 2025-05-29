class_name NEFNNakamaSession
extends RefCounted

var token: String = ""
var refresh_token: String = ""
var user_id: String = ""
var username: String = ""
var create_time: int = 0
var expire_time: int = 0
var is_expired: bool = false
var vars: Dictionary = {}

func _init() -> void:
	create_time = Time.get_unix_time_from_system()
	expire_time = create_time + 3600  # Default 1 hour expiry

func is_exception() -> bool:
	return false

func get_exception() -> Dictionary:
	return {} 