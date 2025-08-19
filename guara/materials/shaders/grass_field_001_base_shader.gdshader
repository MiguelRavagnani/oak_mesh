shader_type spatial;

uniform vec4 x_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);  // Red areas
uniform vec4 y_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);  // Green areas
uniform vec4 z_color : source_color = vec4(0.0, 0.0, 1.0, 1.0);  // Blue areas
uniform sampler2D weight_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float _glossiness = 0.5;

#include "res://materials/shaders/shared/fresnel.gdshaderinc"


void fragment() {
    // Sample the RGB weight texture
    vec3 weights = texture(weight_texture, UV).rgb;

    // Direct color blending using the weights
    ALBEDO = x_color.rgb * weights.r +
             y_color.rgb * weights.g +
             z_color.rgb * weights.b;

    ROUGHNESS = 0.98;
    SPECULAR = 0.25;
}