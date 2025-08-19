@tool
extends MeshInstance3D

@export var target_mesh_instance : MeshInstance3D
@export var resolution : int = 10

func _ready():
	var source_mesh = target_mesh_instance.mesh
	var final_mesh : ArrayMesh = ArrayMesh.new()
	
	for i in resolution:
		var percent : float = ((i + 1) / float(resolution))
		var mt = MeshDataTool.new()
		mt.create_from_surface(source_mesh, 0)
		for v_idx in mt.get_vertex_count():
			var base_color = mt.get_vertex_color(v_idx)
			mt.set_vertex_color(v_idx, Color(percent * 0.5, base_color.g, 0.0))
		mt.commit_to_surface(final_mesh)
	mesh = final_mesh
	skin = target_mesh_instance.skin


	# --- Sync material parameters from base mesh material to fur material ---
	var base_mat = target_mesh_instance.get_active_material(0)
	var fur_mat = get_active_material(0)

	if base_mat is ShaderMaterial and fur_mat is ShaderMaterial:
		# Parameters to copy from base material shader
		var params_to_copy = [
			"x_color", "y_color", "z_color",
			"x_noise_sampler", "y_noise_sampler", "z_noise_sampler",
			"sharpness"
		]
		for p in params_to_copy:
			if base_mat.get_shader_parameter(p) != null:
				fur_mat.set_shader_parameter(p, base_mat.get_shader_parameter(p))
