shader_type spatial;
render_mode cull_disabled;

uniform float billboard_threshold = 20.0;
uniform float blend_factor = 0.5;

uniform sampler2D weight_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 x_color : source_color;
uniform vec4 y_color : source_color;
uniform vec4 z_color : source_color;

uniform float tip_start = 0.9; // where brightening starts
uniform float tip_end   = 1.0; // tip of blade

// Color variation
uniform float color_variation = 0.1;
uniform float brightness_variation = 0.05;

// Wind
uniform float deg_sway_pitch = 80.0;
uniform float deg_sway_yaw   = 45.0;

global uniform float wind_intensity = 4.0;
global uniform float wind_speed     = 1.0;
global uniform vec3  wind_direction = vec3(0,0,-1);

uniform vec2 ellipse_center = vec2(0.5, -0.5);
uniform vec2 ellipse_radius = vec2(0.4, 0.85);

varying float wind;
varying vec3 blade_color;

const vec3 UP = vec3(0,1,0);
const float DEG2RAD = (PI / 180.0);

mat3 mat3_from_axis_angle(float angle, vec3 axis) {
    float s = sin(angle);
    float c = cos(angle);
    float t = 1.0 - c;
    float x = axis.x;
    float y = axis.y;
    float z = axis.z;

    return mat3(
        vec3(t*x*x+c,   t*x*y-s*z, t*x*z+s*y),
        vec3(t*x*y+s*z, t*y*y+c,   t*y*z-s*x),
        vec3(t*x*z-s*y, t*y*z+s*x, t*z*z+c)
    );
}

vec2 random2(vec2 p) {
    return fract(sin(vec2(
        dot(p, vec2(127.32, 231.4)),
        dot(p, vec2(12.3, 146.3))
    )) * 231.23);
}

float worley2(vec2 p) {
    float dist = 1.0;
    vec2 i_p = floor(p);
    vec2 f_p = fract(p);

    for(int y=-1;y<=1;y++) {
        for(int x=-1;x<=1;x++) {
            vec2 n = vec2(float(x), float(y));
            vec2 diff = n + random2(i_p + n) - f_p;
            dist = min(dist, length(diff));
        }
    }
    return dist;
}

void vertex() {
    NORMAL = UP;
    vec3 vertex = VERTEX;

    vec3 wind_dir = normalize(wind_direction);
    float time = TIME * wind_speed;

    // World pos for per-blade randomness
    vec2 world_pos = (MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0)).xz;
    vec2 rand_val  = random2(world_pos * 0.2); // more noise detail

    // Base wind field
    vec2 uv = world_pos * wind_intensity * 0.01;
    uv += wind_dir.xz * time;
    float wind_base = pow(worley2(uv), 1.5) * UV.y;

    // Add turbulence (secondary high-frequency gusts)
    float gust = sin(dot(world_pos, vec2(0.15,0.27)) + time * (0.8 + rand_val.x * 1.5)) * 0.5 + 0.5;

    // Mix in turbulence and per-blade variation
    wind = wind_base * (0.8 + rand_val.y * 0.4) + gust * 0.2;

    mat3 to_model = inverse(mat3(MODEL_MATRIX));
    vec3 wind_forward = to_model * wind_dir;
    vec3 wind_right = normalize(cross(wind_forward, UP));

    // Random sway amplitudes per blade
    float sway_pitch = (deg_sway_pitch * DEG2RAD * wind) * (0.8 + rand_val.x * 0.5) + INSTANCE_CUSTOM.z;
    float sway_yaw   = (deg_sway_yaw   * DEG2RAD * sin(time + rand_val.y*6.28) * wind) + INSTANCE_CUSTOM.w;

    mat3 rot_right   = mat3_from_axis_angle(sway_pitch, wind_right);
    mat3 rot_forward = mat3_from_axis_angle(sway_yaw, wind_forward);

    vertex.xz *= INSTANCE_CUSTOM.x;
    vertex.y  *= INSTANCE_CUSTOM.y;

    // === 👇 Billboard "anti-flat tilt" adjustment ===
    vec3 world_pos3 = (MODEL_MATRIX * vec4(vertex, 1.0)).xyz;
	vec3 camera_world_position = -VIEW_MATRIX[3].xyz;
    vec3 to_cam = normalize(camera_world_position - (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz);

    // How aligned the blade's forward axis is with the view
    float facing = abs(dot(normalize(wind_forward), to_cam));

    // Small tilt strength (play with 0.1–0.3)
    float tilt_strength = 0.4;

    // Random tilt axis per blade
    vec3 tilt_axis = normalize(vec3(rand_val.x - 0.5, 0.0, rand_val.y - 0.5));

    // Apply a tilt if blade is facing "flat" to camera
    float tilt_angle = tilt_strength * facing;
    mat3 rot_tilt = mat3_from_axis_angle(tilt_angle, tilt_axis);

    VERTEX = rot_tilt * (rot_right * rot_forward * vertex);

    // ✅ Base mesh color
    vec3 base_color = COLOR.rgb;

    blade_color = base_color;
}

void fragment() {
    float side = FRONT_FACING ? 1.0 : -1.0;
    NORMAL = NORMAL * side;
    
    vec2 uv = UV;
    vec2 diff = uv - ellipse_center;
    float ellipse_eq = (diff.x * diff.x) / (ellipse_radius.x * ellipse_radius.x)
                     + (diff.y * diff.y) / (ellipse_radius.y * ellipse_radius.y);
    if (ellipse_eq > 1.0) {
        discard;
    }

    vec2 terrain_uv = COLOR.rg;
    vec3 weights = texture(weight_texture, terrain_uv).rgb;

    // Base color from terrain weights
    vec3 base_color = x_color.rgb * weights.r +
                      y_color.rgb * weights.g +
                      z_color.rgb * weights.b;


	// Smooth ramp only at the tip
	float tip_factor = smoothstep(tip_start, tip_end, UV.y);

	// Slight lightening at tip
	float tip_light = color_variation; // max extra brightness
	float brightness_factor = 1.0 + tip_factor * tip_light;

	ALBEDO = base_color * brightness_factor;

    SPECULAR  = 0.25;
    ROUGHNESS = clamp(1.0 - (wind * 1.2), 0.0, 1.0);
}
