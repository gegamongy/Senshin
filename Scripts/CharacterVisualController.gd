extends Node3D

# This script isolates the character visual for the inventory UI
# It sets all meshes to layer 20 and ensures proper visibility

func _ready():
	# Set all visual instances to layer 20 after scene is loaded
	call_deferred("_setup_layers")


func _setup_layers():
	set_visual_layer_recursive(self, 20)


func set_visual_layer_recursive(node: Node, layer: int):
	if node is VisualInstance3D:
		node.layers = 1 << (layer - 1)  # Set to only specified layer
	
	for child in node.get_children():
		set_visual_layer_recursive(child, layer)
