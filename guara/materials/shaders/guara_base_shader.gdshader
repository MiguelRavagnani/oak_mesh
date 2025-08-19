shader_type spatial;

uniform sampler2D albedo_sampler : source_color, filter_linear_mipmap, repeat_disable;
uniform float _glossiness = 0.5;

#include "res://materials/shaders/shared/fresnel.gdshaderinc"

void fragment() {
	ALBEDO = texture(albedo_sampler, UV).rgb;
	ROUGHNESS = 0.98;
	SPECULAR = 0.25;
}

void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT) * ATTENUATION * 4.0, 0.0, 1.0);
	
	// specular
	vec3 H = normalize(VIEW + LIGHT);
	float NdotH = max(0, dot(NORMAL, H));
	float specular = clamp(pow(NdotH, 1.0 / _glossiness), 0.0, 1.0);
	// rim
	float rimDot = 1.0 - dot(VIEW, NORMAL);
	float rim = clamp(rimDot * NdotL, 0.0, 1.0);
	
	DIFFUSE_LIGHT += NdotL * (rim + specular);
	
	DIFFUSE_LIGHT += clamp(vec3(1.0) * step(0.5, fresnel(1.5, NORMAL, VIEW)) * NORMAL.y, 0.0, 1.0);
}