// wind_functions.inc

#ifdef VERTEX

float get_position_sum(vec3 world_position) {
    return world_position.x + world_position.y + world_position.z;
}

mat3 get_inv_model_matrix() {
    return inverse(mat3(MODEL_MATRIX));
}

vec3 get_wind_local_direction(vec3 wind_direction) {
    mat3 inv_model = get_inv_model_matrix();
    return normalize(inv_model * wind_direction);
}

vec3 apply_wind_deformation(
    vec3 vertex,
    vec3 world_position,
    vec3 wind_direction,
    float wind_intensity,
    float wind_speed,
    float vertex_color_mask
) {
    vec3 model_front_direction = vec3(1.0, 0.0, 0.0);
    vec3 model_side_direction = vec3(0.0, 0.0, 1.0);

    float position_sum = get_position_sum(world_position);

    vec3 wind_local_direction = get_wind_local_direction(wind_direction);

    float dot_product = dot(model_front_direction, wind_local_direction);
    float side_dot = dot(model_side_direction, wind_local_direction);

    float strength = abs(dot_product);
    float push_strength = clamp(strength, 0.01, 1.0);
    float noise_strength = clamp(strength, 0.5, 1.0);

    float scroll_direction = -1.0 * sign(side_dot);
    float scroll_speed = wind_speed;

    float wind_uv_scale = 0.1;
    float wind_object_offset = position_sum * 0.2;

    vec2 wind_uv = vec2(
        vertex.z * wind_uv_scale + TIME * scroll_speed * scroll_direction + wind_object_offset,
        vertex.y * wind_uv_scale
    );

    float wind_noise = texture(wind_noise_texture, wind_uv).r;
    wind_noise = 2.0 * wind_noise - 1.0;

    // Calculate displacement
    vec3 displaced_vertex = vertex;
    displaced_vertex += wind_local_direction * wind_intensity * push_strength * vertex_color_mask;
    displaced_vertex.x += wind_noise * 0.5 * wind_intensity * noise_strength * vertex_color_mask;

    return displaced_vertex;
}

#endif