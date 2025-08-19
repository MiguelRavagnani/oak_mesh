@tool
extends EditorScript
class_name TerrainWeightGenerator

# ============================
# Gaussian blur helper
# ============================
static func generate_gaussian_kernel(radius: int, sigma: float) -> PackedFloat32Array:
	var kernel = PackedFloat32Array()
	var sum = 0.0
	for i in range(-radius, radius + 1):
		var value = exp(-float(i * i) / (2.0 * sigma * sigma))
		kernel.append(value)
		sum += value
	# Normalize
	for i in range(kernel.size()):
		kernel[i] /= sum
	return kernel

static func apply_gaussian_blur(image: Image, radius: int = 2, sigma: float = 1.0) -> Image:
	if radius <= 0:
		return image.duplicate()

	var width = image.get_width()
	var height = image.get_height()
	var kernel = generate_gaussian_kernel(radius, sigma)

	var temp_img = image.duplicate()

	# Horizontal pass
	for y in range(height):
		for x in range(width):
			var sum = Color(0,0,0,0)
			for i in range(-radius, radius + 1):
				var sample_x = clamp(x + i, 0, width - 1)
				sum += image.get_pixel(sample_x, y) * kernel[i + radius]
			temp_img.set_pixel(x, y, sum)

	var final_img = temp_img.duplicate()

	# Vertical pass
	for x in range(width):
		for y in range(height):
			var sum = Color(0,0,0,0)
			for i in range(-radius, radius + 1):
				var sample_y = clamp(y + i, 0, height - 1)
				sum += temp_img.get_pixel(x, sample_y) * kernel[i + radius]
			final_img.set_pixel(x, y, sum)

	return final_img

# ============================
# Noise-based weight map
# ============================
static func generate_weight_texture_from_noise(
	r_noise: Noise,
	g_noise: Noise,
	b_noise: Noise,
	r_color: Color = Color.RED,
	g_color: Color = Color.GREEN,
	b_color: Color = Color.BLUE,
	output_size: Vector2i = Vector2i(1024, 1024),
	sharpness: float = 2.5,
	output_path: String = "",
	blur_radius: int = 0
) -> ImageTexture:
	if not r_noise or not g_noise or not b_noise:
		push_error("All three noise sources are required")
		return null

	var output_image = Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGB8)

	for x in range(output_size.x):
		for y in range(output_size.y):
			var wr = pow((r_noise.get_noise_2d(x, y) + 1.0) * 0.5, sharpness)
			var wg = pow((g_noise.get_noise_2d(x, y) + 1.0) * 0.5, sharpness)
			var wb = pow((b_noise.get_noise_2d(x, y) + 1.0) * 0.5, sharpness)

			var green_factor = 0.5
			var blue_factor = 0.5

			var wr_adj = wr * (1.0 - green_factor * wg - blue_factor * wb)
			var wg_adj = wg * (1.0 - blue_factor * wb)
			var wb_adj = wb

			var final_color = Color(
				r_color.r * wr_adj + g_color.r * wg_adj + b_color.r * wb_adj,
				r_color.g * wr_adj + g_color.g * wg_adj + b_color.g * wb_adj,
				r_color.b * wr_adj + g_color.b * wg_adj + b_color.b * wb_adj,
				1.0
			)

			output_image.set_pixel(x, y, final_color)

	if blur_radius > 0:
		output_image = apply_gaussian_blur(output_image, blur_radius)

	var result_texture = ImageTexture.new()
	result_texture.set_image(output_image)

	if output_path != "":
		var full_path = output_path
		if not full_path.ends_with(".png"):
			full_path += ".png"
		output_image.save_png(full_path)
		print("Weight texture saved to: ", full_path)
		ResourceSaver.save(result_texture, full_path.replace(".png", ".tres"))

	return result_texture

# ============================
# Raw weight map (for shaders)
# ============================
static func generate_weight_map(
	r_noise: Noise,
	g_noise: Noise,
	b_noise: Noise,
	output_size: Vector2i = Vector2i(1024, 1024),
	sharpness: float = 2.5,
	output_path: String = "",
	blur_radius: int = 0
) -> ImageTexture:
	if not r_noise or not g_noise or not b_noise:
		push_error("All three noise sources are required")
		return null

	var output_image = Image.create(output_size.x, output_size.y, false, Image.FORMAT_RGB8)

	for x in range(output_size.x):
		for y in range(output_size.y):
			var wr = pow((r_noise.get_noise_2d(x, y) + 1.0) * 0.5, sharpness)
			var wg = pow((g_noise.get_noise_2d(x, y) + 1.0) * 0.5, sharpness)
			var wb = pow((b_noise.get_noise_2d(x, y) + 1.0) * 0.5, sharpness)

			var green_factor = 0.5
			var blue_factor = 0.5

			var wr_adj = wr * (1.0 - green_factor * wg - blue_factor * wb)
			var wg_adj = wg * (1.0 - blue_factor * wb)
			var wb_adj = wb

			output_image.set_pixel(x, y, Color(wr_adj, wg_adj, wb_adj, 1.0))

	if blur_radius > 0:
		output_image = apply_gaussian_blur(output_image, blur_radius)

	var result_texture = ImageTexture.new()
	result_texture.set_image(output_image)

	if output_path != "":
		var full_path = output_path
		if not full_path.ends_with(".png"):
			full_path += ".png"
		output_image.save_png(full_path)
		print("Weight map saved to: ", full_path)
		ResourceSaver.save(result_texture, full_path.replace(".png", ".tres"))

	return result_texture

# ============================
# Run example
# ============================
func _run():
	var r_noise = FastNoiseLite.new()
	r_noise.seed = 123
	r_noise.frequency = 0.01
	r_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var g_noise = FastNoiseLite.new()
	g_noise.seed = 456
	g_noise.frequency = 0.005
	g_noise.noise_type = FastNoiseLite.TYPE_PERLIN

	var b_noise = FastNoiseLite.new()
	b_noise.seed = 789
	b_noise.frequency = 0.02
	b_noise.noise_type = FastNoiseLite.TYPE_VALUE

	var weight_map = generate_weight_map(r_noise, g_noise, b_noise, Vector2i(1024, 1024), 2.5, "res://materials/textures/generated_weight", 2)
	var colored_texture = generate_weight_texture_from_noise(r_noise, g_noise, b_noise, Color.RED, Color.GREEN, Color.BLUE, Vector2i(1024, 1024), 2.5, "res://materials/textures/generated_colored", 2)

	if weight_map and colored_texture:
		print("Terrain texture generation complete!")
	else:
		print("Terrain texture generation failed!")
