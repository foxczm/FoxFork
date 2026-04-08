extends Node
class_name ServerLogic

var lobby_container : LobbyContainer = null

func _ready() -> void:
	name = "NetworkConnection"
	var peer = ENetMultiplayerPeer.new()
	
	var error = peer.create_server(ServerDatabase.port)
	if error != OK:
		print("Failed to start server, error code: ", error)
		return
	
	#plugging the battery into the walkie talkie
	multiplayer.multiplayer_peer = peer
	print('server started :D on port ', ServerDatabase.port)
	
	multiplayer.peer_connected.connect(_on_client_connected)
	multiplayer.peer_disconnected.connect(_on_client_disconnected)
	


func create_new_lobby(id : String): #TODO delete this?
	lobby_container.create_new_lobby(id, []) #not exactly needed, you could call it local since we know this zastard is the server but idk this could do some cool stuff lol

func _on_client_connected(peer_id : int):
	print(' :} client connected with id ', str(peer_id))
	ServerDatabase.add_player(peer_id)

func _on_client_disconnected(peer_id : int):
	print('>:( client disconnced with id ', str(peer_id))
	ServerDatabase.remove_player(peer_id)
