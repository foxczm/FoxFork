extends Node
class_name ClientLogic


func _ready() -> void:
	name = "NetworkConnection"
	var peer = ENetMultiplayerPeer.new()
	
	var error = peer.create_client(ServerDatabase.address, ServerDatabase.port)
	if error != OK:
		print('error creating client with error code: ', error)
		return
		
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connection_success)
	
func _on_connection_success():
	
	print('Yay! we are connected to server yayyy :D')
