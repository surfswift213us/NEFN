class_name Nakama
extends Node

const ClientClass = preload("res://addons/nefn/types/nakama_client.gd")

static func create_client(
	p_server_key: String = "defaultkey",
	p_host: String = "127.0.0.1",
	p_port: int = 7350,
	p_scheme: String = "http"
) -> NakamaClient:
	var client = ClientClass.new()
	return client 