shader_type spatial;
render_mode cull_back, depth_draw_always;

// Textures
uniform sampler2D noise_deformation_sampler : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_sampler : filter_linear_mipmap, repeat_enable;
uniform sampler2D curve : repeat_disable;
uniform sampler2D fur_flow_map : filter_linear_mipmap, repeat_disable;

// Material properties
uniform float _glossiness = 0.5;
uniform float _fur_length = 0.15;
uniform float _fur_gravity = 0.0;
uniform float height_variation_intensity = 0.2;
uniform float _bend_factor = 0.3;    // Controls how much the grass bends (0.0 to 1.0)
uniform float _flatten_factor = 0.5;  // Controls the blade thickness (0.0 to 1.0)

// Colors
uniform vec4 x_color : source_color = vec4(1.0);
uniform vec4 y_color : source_color = vec4(1.0);
uniform vec4 z_color : source_color = vec4(1.0);

// Color noise textures
uniform sampler2D x_noise_sampler : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D y_noise_sampler : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D z_noise_sampler : source_color, filter_linear_mipmap, repeat_disable;

// Wind properties
global uniform vec3 wind_direction = vec3(1.0, 0.0, 0.0);
global uniform float wind_intensity = 1.0;
global uniform float wind_speed = 1.0;

varying float object_y;

#include "res://materials/shaders/shared/fresnel.gdshaderinc"

void vertex() {
    object_y = NORMAL.y;

    // Basic fur length with noise variation
    float noise = 0.5 - texture(noise_deformation_sampler, UV + COLOR.r * 0.15).x;
    vec3 length_variance = texture(noise_sampler, UV).xyz + vec3(1.0);
    float base_length = texture(curve, vec2(COLOR.r, 0.0)).z * _fur_length;

    // Add random height variation
    float height_var = texture(noise_sampler, UV * 2.0).x * height_variation_intensity;

    // Wind effect calculation
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 world_wind_dir = normalize(wind_direction);

    // Wind animation
    float wind_time = TIME * wind_speed;
    float wind_wave = sin(wind_time + world_pos.x * 0.5 + world_pos.z * 0.5);

    // Create blade shape with bending and flattening
    vec3 offset = NORMAL * (base_length + height_var);

    // Apply bending (curves the blade)
    offset.x *= (1.0 - _bend_factor * COLOR.r);

    // Apply flattening (makes the blade thinner)
    vec3 tangent = normalize(cross(NORMAL, vec3(0.0, 1.0, 0.0)));
    offset = mix(offset, offset * vec3(0.1, 1.0, 1.0), _flatten_factor * COLOR.r);

    VERTEX += offset;

    // Apply wind
    vec3 wind_offset = world_wind_dir * wind_wave * wind_intensity * COLOR.r;
    VERTEX += (inverse(MODEL_MATRIX) * vec4(wind_offset, 0.0)).xyz;
}

void fragment() {
    // Sample flow map and noise
    vec2 flow_map = texture(fur_flow_map, UV).xy * COLOR.r;
    float strand = texture(noise_sampler, UV * 10.0 - flow_map * 0.2).x;

    // Sample color noise textures
    vec3 nx = texture(x_noise_sampler, UV).rgb * x_color.rgb;
    vec3 ny = texture(y_noise_sampler, UV).rgb * y_color.rgb;
    vec3 nz = texture(z_noise_sampler, UV).rgb * z_color.rgb;

    // Color blending weights
    float wx = texture(x_noise_sampler, UV).r;
    float wy = texture(y_noise_sampler, UV).r;
    float wz = texture(z_noise_sampler, UV).r;

    // Sharpen transitions
    float sharpness = 3.5;
    wx = pow(wx, sharpness);
    wy = pow(wy, sharpness);
    wz = pow(wz, sharpness);

    // Normalize weights
    float sum_w = wx + wy + wz + 0.0001;
    vec3 weights = vec3(wx, wy, wz) / sum_w;

    // Final color blend
    ALBEDO = x_color.rgb * weights.x + y_color.rgb * weights.y + z_color.rgb * weights.z;
    ALBEDO *= strand * 0.5 + 0.5;

    // Material properties
    ROUGHNESS = 0.8;
    SPECULAR = 0.4;

    // Alpha handling
    ALPHA = texture(curve, vec2(strand * (0.9 - COLOR.r), 0.0)).y;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
}
