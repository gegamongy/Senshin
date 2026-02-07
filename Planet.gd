class_name Planet
extends MeshInstance3D

var universe_config = UniverseConfig.new()
var planet_shader = preload("res://scenes/Planet.gdshader")

var radius: int #Planet Radius in km

var transition_threshold_distance: int
var clipmap_blend_distance: int
var transition_threshold: float
var clipmap_blend_threshold: float

var galactic_position: Vector3i = Vector3i.ZERO #For development we start with only one system at galactic coord (0, 0, 0)
var system_position: Vector3i = Vector3i.ZERO #Position in System Units 
var local_position: Vector3 = Vector3.ZERO #Local Position offset for realistic orbits and planet position precision

var distance_to_player_system_units: Vector3i #System unit distance vector to player
var distance_to_player_local_units: Vector3 #Local space distance offset to player
var total_distance: float #Total combined distance in meters

var material = ShaderMaterial.new()

var is_small_planet: bool = false #Does planet fit inside projection distance?


# --- PLANET PROJECTION ----#
var sphere_mesh: ArrayMesh = null
var fake_radius: float = 0.0 #The scaled radius for rendering at projection distance

#Local distance of the planet mesh to the spaceship. Follows the ship to make the illusion that planets are extremely large and far away.
var projection_distance: float = 500.0 * 1000.0 #Distance from player to render planet projection

#Direction of the planet to the ship, so it shows up in the correct spot surrounding the ship.
var projection_direction: Vector3 = Vector3.ZERO

# Reference to player for distance calculations
var player: SpaceshipController = null
var camera: Camera3D = null

# System unit size in meters/km (should match universe config)
var SYSTEM_UNIT_SIZE: float = universe_config.floating_origin_threshold  # 5000 units = 1 system unit

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set top_level to prevent inheriting parent transforms
	top_level = true
	
	if player:
		# Get camera reference from player
		var camera_pivot = player.get_node_or_null("CameraPivot")
		if camera_pivot:
			camera = camera_pivot.get_node_or_null("Camera3D")
		
		if check_is_small_planet():
			print("SMALL PLANET!")
		calculate_distance_to_player()
		calculate_projection_direction()
		setup_thresholds()
		setup_visual()
		update_projection_position()
		scale_based_on_distance()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	# Update distance and projection each frame
	if player:
		calculate_distance_to_player()
		calculate_projection_direction()
		calculate_thresholds()
		update_projection_position()
		scale_based_on_distance()
		scale_and_translate_in_shader_based_on_transition()
		
		

## Create the planet's visual representation
func setup_visual():
	# Create cube sphere mesh for better UV mapping and texturing
	sphere_mesh = create_cube_sphere(32)  # 32 subdivisions per face
	mesh = sphere_mesh
	
	# Create material with random color
	material.shader = planet_shader
	var planet_color = Color(
		randf_range(0.2, 0.8),
		randf_range(0.2, 0.8),
		randf_range(0.2, 0.8)
	)
	material.set_shader_parameter("planet_color", planet_color)
	
	material_override = material

## Create a cube sphere by projecting cube vertices onto a sphere
func create_cube_sphere(subdivisions: int) -> ArrayMesh:
	## Create arrays for mesh data
	var arrays = [] 
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	# Generate 6 cube faces
	var faces = [
		Vector3.RIGHT,   # +X
		Vector3.LEFT,    # -X
		Vector3.UP,      # +Y
		Vector3.DOWN,    # -Y
		Vector3.FORWARD, # +Z (in Godot, this is -Z in standard coords)
		Vector3.BACK     # -Z
	]
	
	for face_normal in faces:
		generate_cube_face(face_normal, subdivisions, vertices, normals, uvs, indices)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return array_mesh

## Generate a single face of the cube sphere
func generate_cube_face(normal: Vector3, subdivisions: int, vertices: PackedVector3Array, 
						normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array):
	# Get two perpendicular axes for this face
	var axis_a = Vector3.UP if abs(normal.y) < 0.9 else Vector3.RIGHT
	axis_a = axis_a.cross(normal).normalized()
	var axis_b = normal.cross(axis_a).normalized()
	
	# Starting index for this face's vertices
	var vertex_offset = vertices.size()
	
	# Generate grid of vertices for this face
	for y in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			# Calculate position on cube face (-1 to 1 on each axis)
			var percent_x = float(x) / float(subdivisions)
			var percent_y = float(y) / float(subdivisions)
			
			var point_on_cube = normal + \
								(percent_x * 2.0 - 1.0) * axis_a + \
								(percent_y * 2.0 - 1.0) * axis_b
			
			# Project onto unit sphere
			var point_on_sphere = point_on_cube.normalized()
			
			vertices.append(point_on_sphere)
			normals.append(point_on_sphere)  # For a sphere, normal = position
			uvs.append(Vector2(percent_x, percent_y))
	
	# Generate indices for triangles
	for y in range(subdivisions):
		for x in range(subdivisions):
			var i = vertex_offset + y * (subdivisions + 1) + x
			
			# Two triangles per quad
			indices.append(i)
			indices.append(i + subdivisions + 1)
			indices.append(i + subdivisions + 2)
			
			indices.append(i)
			indices.append(i + subdivisions + 2)
			indices.append(i + 1)

## Calculate the distance to the player in both system and local units
func calculate_distance_to_player():
	# System unit distance (integer grid distance)
	distance_to_player_system_units = system_position - player.system_position
	
	# Local space distance offset
	distance_to_player_local_units = local_position - player.local_position
	
	# Check if we're at extreme distance (>10,000 system units)
	var system_distance_magnitude = distance_to_player_system_units.length()
	
	if system_distance_magnitude > 10000:
		# EXTREME DISTANCE MODE: Use hierarchical coordinates only
		# Ignore local offsets - they're negligible at this scale
		# Distance in meters = system_units * SYSTEM_UNIT_SIZE
		total_distance = system_distance_magnitude * SYSTEM_UNIT_SIZE
	else:
		# CLOSE DISTANCE MODE: Use precise meter calculations
		# Total distance in meters (convert system units to meters and add local offset)
		var system_distance_m = Vector3(
			distance_to_player_system_units.x * SYSTEM_UNIT_SIZE,
			distance_to_player_system_units.y * SYSTEM_UNIT_SIZE,
			distance_to_player_system_units.z * SYSTEM_UNIT_SIZE
		)
		
		var total_distance_vector = system_distance_m + distance_to_player_local_units
		total_distance = total_distance_vector.length()

## Calculate the direction from player to planet for projection
func calculate_projection_direction():
	# Check if we're at extreme distance
	var system_distance_magnitude = distance_to_player_system_units.length()
	
	if system_distance_magnitude > 10000:
		# EXTREME DISTANCE MODE: Use only system unit direction
		# Convert to Vector3 for direction calculation
		var system_direction = Vector3(
			float(distance_to_player_system_units.x),
			float(distance_to_player_system_units.y),
			float(distance_to_player_system_units.z)
		)
		
		if system_direction.length() > 0:
			projection_direction = system_direction.normalized()
		else:
			projection_direction = Vector3.FORWARD
	else:
		# CLOSE DISTANCE MODE: Use precise direction with local offsets
		var system_distance = Vector3(
			distance_to_player_system_units.x * SYSTEM_UNIT_SIZE,
			distance_to_player_system_units.y * SYSTEM_UNIT_SIZE,
			distance_to_player_system_units.z * SYSTEM_UNIT_SIZE
		)
		
		var total_distance_vector = system_distance + distance_to_player_local_units
		
		if total_distance_vector.length() > 0:
			projection_direction = total_distance_vector.normalized()
		else:
			projection_direction = Vector3.FORWARD


## Update the planet's rendered position based on projection
func update_projection_position():
	# Position the planet at projection_distance in the direction of the actual planet
	# Use global_position to prevent interpolation
	if player:
		# Calculate absolute position in world space
		# Planet center is always at: player position + direction * total_distance
		if fake_radius >= radius * 1000:
			# If planet is at real size, position it at actual location
			var planet_center_offset = projection_direction * total_distance
			global_position = player.global_position + planet_center_offset
		else:
			# Position at projection distance instead
			var planet_center_offset = projection_direction * projection_distance
			global_position = player.global_position + planet_center_offset

func scale_based_on_distance():
	# Scale the planet mesh based on distance to create illusion of size
	# Simple linear scaling: closer = larger, farther = smaller
	
	# Check if we need extreme distance calculations
	var system_distance_magnitude = distance_to_player_system_units.length()
	
	if system_distance_magnitude > 10000:
		# EXTREME DISTANCE MODE: Use simplified calculation
		# fake_radius = (R * D) / d, where all values are in km
		# Avoid converting to meters to prevent overflow
		var distance_km = system_distance_magnitude * (SYSTEM_UNIT_SIZE / 1000.0)  # Convert to km
		fake_radius = (radius * (projection_distance / 1000.0)) / distance_km * 1000.0  # Result in meters
	else:
		# CLOSE DISTANCE MODE: Use precise meter calculations
		fake_radius = (radius / (total_distance / 1000)) * (projection_distance / 1000) * 1000
	
	# Scale the mesh (cube sphere is unit sphere, so scale = radius)
	if fake_radius / 1000 >= radius:
		# Lock to actual radius
		scale = Vector3.ONE * radius * 1000
		print("Reached actual planet size: ", radius)
	else:
		# Scale to fake radius
		scale = Vector3.ONE * fake_radius
		#print("Scaling planet to fake radius: ", fake_radius / 1000, " km")
			
func scale_and_translate_in_shader_based_on_transition():
	if transition_threshold <= 0 and !check_is_small_planet():
		# We're in the transition zone
		
		# Distance to planet surface
		var distance_to_surface = total_distance - (radius * 1000)
		
		# Blend range: from transition_threshold_distance above surface down to surface
		var blend_range = transition_threshold_distance
		
		# Current position in blend range (0 at transition start, blend_range at surface)
		var current_position = transition_threshold_distance - distance_to_surface
		
		# Blend factor: 0.0 at transition threshold, 1.0 at planet surface
		var blend_factor = clamp(current_position / blend_range, 0.0, 1.0)
		
		# Calculate scale ratio: how much smaller our sphere is compared to real planet
		# This represents the curvature difference
		var current_mesh_radius = scale.x  # Since we scale uniformly, any component works
		var scale_ratio = current_mesh_radius / (radius * 1000)
		
		# Squash factor: compress depth by the scale ratio to maintain correct curvature
		# A 10000km planet shown as 500km sphere needs squash_factor = 500/10000 = 0.05
		var squash_factor = scale_ratio
		
		# Keep perpendicular scale at 1.0 (we're not scaling the disc, just flattening depth)
		var scale_factor = 1.0
		
		# Offset to compensate for squashing: push front surface back to original distance
		# After squashing, front is at radius * squash_factor, we want it at radius
		# So we need to push it forward by: radius * (1 - squash_factor)
		var offset_distance = - current_mesh_radius * (1.0 - squash_factor)
		
		# Transform projection_direction from world space to local space
		var local_planet_direction = global_transform.basis.inverse() * projection_direction
		
		print("Blend: ", blend_factor, " Scale ratio: ", scale_ratio, " Squash: ", squash_factor, " Offset: ", offset_distance / 1000, "km")
		
		# Send to shader
		material.set_shader_parameter("base_scale", current_mesh_radius)
		material.set_shader_parameter("scale_factor", scale_factor)
		material.set_shader_parameter("squash_factor", squash_factor)
		material.set_shader_parameter("offset_distance", offset_distance)
		material.set_shader_parameter("blend_factor", blend_factor)
		material.set_shader_parameter("planet_direction", local_planet_direction)
	else:
		# Reset shader parameters when not in transition
		material.set_shader_parameter("blend_factor", 0.0)
	
	pass # Replace with function body.

func setup_thresholds():
	#Set planet transition thresholds for visual effects 
	transition_threshold_distance = (radius * 0.2 ) * 1000
	clipmap_blend_distance = (radius * 0.05) * 1000

func calculate_thresholds():
	transition_threshold = total_distance - (radius * 1000) - transition_threshold_distance
	clipmap_blend_threshold = total_distance - (radius * 1000) - clipmap_blend_distance

func check_is_small_planet():
	#print("Checking for small planet... ", radius, ", ", projection_distance/1000)
	
		#print("This planet is SMALL")
	return radius < projection_distance / 1000
