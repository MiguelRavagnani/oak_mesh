# WeightGeneratorDock.gd - Enhanced with noise samplers and colors
@tool
extends Control

# For dock registration, you need to add this method
func get_dock_name() -> String:
	return "Weight Generator"

# Reference to the editor plugin
var editor_plugin: EditorPlugin

# Noise sources
var r_noise: NoiseTexture2D
var g_noise: NoiseTexture2D
var b_noise: NoiseTexture2D

# Colors for each layer
var r_color: Color = Color.RED
var g_color: Color = Color.GREEN
var b_color: Color = Color.BLUE

# Settings
var output_size: Vector2i = Vector2i(1024, 1024)
var sharpness: float = 2.5
var output_path: String = "res://materials/textures/generated/noise"

# UI References
var preview_rect: TextureRect
var status_label: Label

func _ready():
	create_ui()
	# Initialize default noises
	setup_default_noises()

func setup_default_noises():
	# Create NoiseTexture2D for each channel with proper initialization
	r_noise = NoiseTexture2D.new()
	var r_fnl = FastNoiseLite.new()
	r_fnl.seed = 1000
	r_fnl.frequency = 0.1
	r_fnl.noise_type = FastNoiseLite.TYPE_PERLIN
	r_noise.noise = r_fnl
	r_noise.width = 256
	r_noise.height = 256
	
	g_noise = NoiseTexture2D.new()
	var g_fnl = FastNoiseLite.new()
	g_fnl.seed = 2000
	g_fnl.frequency = 0.15
	g_fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX
	g_noise.noise = g_fnl
	g_noise.width = 256
	g_noise.height = 256
	
	b_noise = NoiseTexture2D.new()
	var b_fnl = FastNoiseLite.new()
	b_fnl.seed = 3000
	b_fnl.frequency = 0.08
	b_fnl.noise_type = FastNoiseLite.TYPE_VALUE
	b_noise.noise = b_fnl
	b_noise.width = 256
	b_noise.height = 256
	
	print("Default noises initialized with seeds: R=1000, G=2000, B=3000")

func create_ui():
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	scroll.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "Terrain Weight Generator"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# === RED LAYER ===
	create_layer_section(vbox, "Red Layer", 0)
	
	# === GREEN LAYER ===
	create_layer_section(vbox, "Green Layer", 1)
	
	# === BLUE LAYER ===
	create_layer_section(vbox, "Blue Layer", 2)
	
	vbox.add_child(HSeparator.new())
	
	# === GLOBAL SETTINGS ===
	var settings_label = Label.new()
	settings_label.text = "Global Settings:"
	settings_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(settings_label)
	
	# Size
	var size_hbox = HBoxContainer.new()
	vbox.add_child(size_hbox)
	
	var size_label = Label.new()
	size_label.text = "Size:"
	size_label.custom_minimum_size.x = 80
	size_hbox.add_child(size_label)
	
	var size_option = OptionButton.new()
	size_option.add_item("512x512", 512)
	size_option.add_item("1024x1024", 1024)
	size_option.add_item("2048x2048", 2048)
	size_option.selected = 1
	size_option.item_selected.connect(_on_size_changed)
	size_hbox.add_child(size_option)
	
	# Sharpness
	var sharp_hbox = HBoxContainer.new()
	vbox.add_child(sharp_hbox)
	
	var sharp_label = Label.new()
	sharp_label.text = "Sharpness:"
	sharp_label.custom_minimum_size.x = 80
	sharp_hbox.add_child(sharp_label)
	
	var sharp_spin = SpinBox.new()
	sharp_spin.min_value = 0.1
	sharp_spin.max_value = 10.0
	sharp_spin.step = 0.1
	sharp_spin.value = 2.5
	sharp_spin.value_changed.connect(_on_sharpness_changed)
	sharp_hbox.add_child(sharp_spin)
	
	# Output path
	var path_label = Label.new()
	path_label.text = "Output Path:"
	vbox.add_child(path_label)
	
	var path_line = LineEdit.new()
	path_line.text = output_path
	path_line.text_changed.connect(_on_path_changed)
	vbox.add_child(path_line)
	
	vbox.add_child(HSeparator.new())
	
	# === PREVIEW ===
	var preview_label = Label.new()
	preview_label.text = "Preview (256x256):"
	vbox.add_child(preview_label)
	
	preview_rect = TextureRect.new()
	preview_rect.custom_minimum_size = Vector2(256, 256)
	preview_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	vbox.add_child(preview_rect)
	
	# Preview button
	var preview_btn = Button.new()
	preview_btn.text = "Generate Preview"
	preview_btn.pressed.connect(_on_preview_pressed)
	vbox.add_child(preview_btn)
	
	vbox.add_child(HSeparator.new())
	
	# === GENERATION BUTTONS ===
	var gen_hbox = HBoxContainer.new()
	vbox.add_child(gen_hbox)
	
	var weight_btn = Button.new()
	weight_btn.text = "Generate Weight Map"
	weight_btn.pressed.connect(_on_generate_weights_pressed)
	gen_hbox.add_child(weight_btn)
	
	var colored_btn = Button.new()
	colored_btn.text = "Generate Colored Blend"
	colored_btn.pressed.connect(_on_generate_colored_pressed)
	gen_hbox.add_child(colored_btn)
	
	# Status label
	status_label = Label.new()
	status_label.text = "Ready to generate..."
	vbox.add_child(status_label)

func create_layer_section(parent: VBoxContainer, layer_name: String, layer_index: int):
	var layer_label = Label.new()
	layer_label.text = layer_name + ":"
	layer_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(layer_label)
	
	# Color display row
	var color_hbox = HBoxContainer.new()
	parent.add_child(color_hbox)
	
	var color_label = Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size.x = 60
	color_hbox.add_child(color_label)
	
	# Fixed ColorRect instead of ColorPicker
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(40, 20)
	match layer_index:
		0:
			color_rect.color = Color(1, 0, 0) # Red
		1:
			color_rect.color = Color(0, 1, 0) # Green
		2:
			color_rect.color = Color(0, 0, 1) # Blue
	
	color_hbox.add_child(color_rect)
	
	# NoiseTexture2D picker using EditorResourcePicker
	var noise_hbox = HBoxContainer.new()
	parent.add_child(noise_hbox)
	
	var noise_label = Label.new()
	noise_label.text = "Noise:"
	noise_label.custom_minimum_size.x = 60
	noise_hbox.add_child(noise_label)
	
	var noise_picker = EditorResourcePicker.new()
	noise_picker.base_type = "NoiseTexture2D"
	noise_picker.editable = true
	noise_picker.custom_minimum_size.x = 150
	
	# Set initial resource
	match layer_index:
		0: 
			noise_picker.edited_resource = r_noise
		1: 
			noise_picker.edited_resource = g_noise
		2: 
			noise_picker.edited_resource = b_noise
	
	# Connect the resource changed signal
	noise_picker.resource_changed.connect(func(resource):
		match layer_index:
			0: 
				r_noise = resource as NoiseTexture2D
			1: 
				g_noise = resource as NoiseTexture2D
			2: 
				b_noise = resource as NoiseTexture2D
		
		# If a new resource was created or loaded, open it in the inspector
		if resource:
			# Open in inspector to show all parameters
			EditorInterface.get_inspector().edit_resource(resource)
			
			if status_label:
				status_label.text = "Noise resource ready for layer " + str(layer_index) + " - Check inspector panel"
				status_label.modulate = Color.GREEN
		else:
			if status_label:
				status_label.text = "Cleared noise for layer " + str(layer_index)
				status_label.modulate = Color.ORANGE
	)
	
	noise_hbox.add_child(noise_picker)

func _force_inspect_resource(resource: Resource):
	# Try to force the inspector to show the resource
	if resource:
		EditorInterface.get_inspector().edit_resource(resource)
		# Also try to refresh the inspector
		EditorInterface.get_inspector().refresh()



# Global settings callbacks
func _on_size_changed(index):
	var sizes = [512, 1024, 2048]
	var size = sizes[index]
	output_size = Vector2i(size, size)

func _on_sharpness_changed(value):
	sharpness = value

func _on_path_changed(text):
	output_path = text

# Generation callbacks
func _on_preview_pressed():
	if not r_noise or not g_noise or not b_noise:
		if status_label:
			status_label.text = "Error: Missing noise textures"
			status_label.modulate = Color.RED
		return
	
	# Check if the noise resources have actual Noise objects
	if not r_noise.noise or not g_noise.noise or not b_noise.noise:
		if status_label:
			status_label.text = "Error: Noise resources don't have noise data"
			status_label.modulate = Color.RED
		return
	
	if status_label:
		status_label.text = "Generating preview..."
		status_label.modulate = Color.YELLOW
	
	# Use TerrainWeightGenerator for consistent preview generation
	var preview_texture = TerrainWeightGenerator.generate_weight_texture_from_noise(
		r_noise.noise,
		g_noise.noise,
		b_noise.noise,
		r_color,
		g_color,
		b_color,
		Vector2i(256, 256),  # Smaller size for preview
		sharpness,
		""  # No save path for preview
	)
	
	if preview_texture:
		preview_rect.texture = preview_texture
		
		if status_label:
			status_label.text = "Preview generated successfully!"
			status_label.modulate = Color.GREEN
	else:
		if status_label:
			status_label.text = "Preview generation failed!"
			status_label.modulate = Color.RED

func _on_generate_weights_pressed():
	if not status_label:
		print("Status label missing")
		return
	
	if not r_noise or not g_noise or not b_noise:
		status_label.text = "Error: Noise sources not initialized"
		status_label.modulate = Color.RED
		return
	
	# Check if the noise resources have actual Noise objects
	if not r_noise.noise or not g_noise.noise or not b_noise.noise:
		status_label.text = "Error: Noise resources don't have noise data"
		status_label.modulate = Color.RED
		return
	
	status_label.text = "Generating weight map..."
	status_label.modulate = Color.YELLOW
	
	# Use the actual TerrainWeightGenerator function
	var result = TerrainWeightGenerator.generate_weight_map(
		r_noise.noise,  # Extract the actual Noise from NoiseTexture2D
		g_noise.noise,
		b_noise.noise,
		output_size,
		sharpness,
		output_path + "_weights"
	)
	
	if result:
		status_label.text = "Weight map generated! Saved to: " + output_path + "_weights.png"
		status_label.modulate = Color.GREEN
		
		# Also update the preview with the generated result
		if preview_rect:
			preview_rect.texture = result
			
		print("Weight map generated successfully!")
	else:
		status_label.text = "Weight map generation failed!"
		status_label.modulate = Color.RED
		print("Error: TerrainWeightGenerator.generate_weight_map returned null")

func _on_generate_colored_pressed():
	if not status_label:
		return
	
	if not r_noise or not g_noise or not b_noise:
		status_label.text = "Error: Noise sources not initialized"
		status_label.modulate = Color.RED
		return
	
	# Check if the noise resources have actual Noise objects
	if not r_noise.noise or not g_noise.noise or not b_noise.noise:
		status_label.text = "Error: Noise resources don't have noise data"
		status_label.modulate = Color.RED
		return
	
	status_label.text = "Generating colored blend..."
	status_label.modulate = Color.YELLOW
	
	# Use the actual TerrainWeightGenerator function
	var result = TerrainWeightGenerator.generate_weight_texture_from_noise(
		r_noise.noise,  # Extract the actual Noise from NoiseTexture2D
		g_noise.noise,
		b_noise.noise,
		r_color,
		g_color,
		b_color,
		output_size,
		sharpness,
		output_path + "_colored"
	)
	
	if result:
		status_label.text = "Colored blend generated! Saved to: " + output_path + "_colored.png"
		status_label.modulate = Color.GREEN
		
		# Also update the preview with the generated result
		if preview_rect:
			preview_rect.texture = result
			
		print("Colored blend texture generated successfully!")
	else:
		status_label.text = "Colored blend generation failed!"
		status_label.modulate = Color.RED
		print("Error: TerrainWeightGenerator.generate_weight_texture_from_noise returned null")
