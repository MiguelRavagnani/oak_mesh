@tool
extends MultiMeshInstance3D

@export var blade_width : Vector2 = Vector2(0.01, 0.02):
	set(value):
		blade_width = value
		rebuild()

@export var blade_height:Vector2 = Vector2(0.04, 0.08):
	set(value):
		blade_height = value
		rebuild()

@export var sway_yaw:Vector2 = Vector2(0.0, 10.0):
	set(value):
		sway_yaw = value
		rebuild()

@export var sway_pitch:Vector2 = Vector2(0.04, 0.08):
	set(value):
		sway_pitch = value
		rebuild()

@export var mesh:Mesh = null:
	set(value):
		mesh = value
		rebuild()

@export var density:float = 1.0:
	set(value):
		density = value
		if density < 1.0:
			density = 1.0
		rebuild()

@export var x_color:Color = Color.BLUE:
	set(value):
		x_color = value
		rebuild()

@export var y_color:Color = Color.BLUE:
	set(value):
		y_color = value
		rebuild()

@export var z_color:Color = Color.BLUE:
	set(value):
		z_color = value
		rebuild()

@export var weighted_texture:ImageTexture:
	set(value):
		weighted_texture = value
		rebuild()

var rust_factory

func _ready():
	create_factory()
	rebuild()

func create_factory():	
	if ClassDB.class_exists("MeshFactory"):
		rust_factory = MeshFactory.new()
		
		if rust_factory == null:
			print("ERROR: Failed to instantiate MeshFactory")
	else:
		print("ERROR: MeshFactory class not found in ClassDB")


func rebuild():
	# Early validation
	if mesh == null:
		print("ERROR: No mesh provided")
		return
	
	if !multimesh:
		multimesh = MultiMesh.new()
	
	# Reset multimesh
	multimesh.instance_count = 0
	multimesh.use_custom_data = true
	multimesh.use_colors = true  # Enable colors for mesh color data
	
	# Ensure we have a valid factory
	if rust_factory == null:
		create_factory()
		if rust_factory == null:
			print("ERROR: No valid factory available")
			return

	# Generate spawns
	var spawns = rust_factory.call(
		"generate_grass_with_uvs",
		mesh,
		density,
		blade_width,
		blade_height,
		sway_pitch,
		sway_yaw
	)

	if spawns == null:
		print("ERROR: spawns is null")
		return
	elif spawns.is_empty():
		print("ERROR: No spawns generated (empty array)")
		return
	
	# Generate mesh
	var blade_mesh = rust_factory.call("generate_mesh")
	if blade_mesh == null:
		print("ERROR: Failed to generate blade mesh")
		return
	
	# Setup multimesh
	multimesh.instance_count = 0
	multimesh.use_custom_data = true
	multimesh.use_colors = true
	multimesh.mesh = blade_mesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = spawns.size()
	
	# Process spawns - now with color data
	for index in multimesh.instance_count:
		var spawn:Array = spawns[index]
		multimesh.set_instance_transform(index, spawn[0])  # Transform
		multimesh.set_instance_custom_data(index, spawn[1])  # Blade parameters
		if spawn.size() > 2:
			multimesh.set_instance_color(index, spawn[2])  # Mesh color
		else:
			# Fallback green color if no mesh color
			multimesh.set_instance_color(index, Color(0.2, 0.8, 0.1, 1.0))
