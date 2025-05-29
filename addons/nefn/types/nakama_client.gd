class_name NEFNNakamaClient
extends RefCounted

var _client: NakamaClient
var _session: NakamaSession
var server_key: String
var host: String
var port: int
var scheme: String

func initialize(p_server_key: String, p_host: String, p_port: int, p_scheme: String) -> void:
	server_key = p_server_key
	host = p_host
	port = p_port
	scheme = p_scheme
	var adapter = NakamaHTTPAdapter.new()
	adapter.logger = NakamaLogger.new()
	_client = NakamaClient.new(adapter, p_server_key, p_scheme, p_host, p_port, 10)

func authenticate_device_async(device_id: String) -> NakamaSession:
	_session = await _client.authenticate_device_async(device_id)
	return _session

func authenticate_email_async(email: String, password: String) -> NakamaSession:
	_session = await _client.authenticate_email_async(email, password)
	return _session

func session_logout_async(session: NakamaSession) -> void:
	if session and _client:
		await _client.session_logout_async(session)
