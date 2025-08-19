use godot::global::randf_range;
use godot::prelude::*;

pub fn rand_bcc() -> Vector3 {
    let mut u = randf_range(0.0, 1.0);
    let mut v = randf_range(0.0, 1.0);
    if u + v >= 1.0 {
        u = 1.0 - u;
        v = 1.0 - v;
    }
    Vector3::new(u as f32, v as f32, 1.0 - (u + v) as f32)
}

pub fn from_bcc_vector3(uvw: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3 {
    a * uvw.x + b * uvw.y + c * uvw.z
}

pub fn get_orthogonal_to(v: Vector3) -> Vector3 {
    let x = v.x.abs();
    let y = v.y.abs();
    let z = v.z.abs();
    let other = if x > y && x > z {
        Vector3::RIGHT
    } else if y > z {
        Vector3::UP
    } else {
        Vector3::FORWARD
    };
    v.cross(other)
}

pub fn quat_shortest_arc(normal_from: Vector3, normal_to: Vector3) -> Quaternion {
    // Normalize input vectors to ensure they're unit vectors
    let from = normal_from.normalized();
    let to = normal_to.normalized();

    let dot = from.dot(to);

    if dot > 0.999_999 {
        // Vectors are nearly identical
        Quaternion::IDENTITY
    } else if dot < -0.999_999 {
        // Vectors are nearly opposite
        let orthogonal = get_orthogonal_to(from).normalized();
        Quaternion::from_axis_angle(orthogonal, std::f32::consts::PI)
    } else {
        // General case: create quaternion from axis-angle
        let axis = from.cross(to);
        let axis_length = axis.length();

        if axis_length < 1e-6 {
            // Cross product is too small, vectors are nearly parallel
            return Quaternion::IDENTITY;
        }

        let normalized_axis = axis / axis_length;
        let angle = from.angle_to(to);

        Quaternion::from_axis_angle(normalized_axis, angle)
    }
}

pub fn triangle_area(a: Vector3, b: Vector3, c: Vector3) -> f32 {
    let ab = a.distance_to(b);
    let bc = b.distance_to(c);
    let ca = c.distance_to(a);
    let s = (ab + bc + ca) / 2.0;
    let area_squared = s * (s - ab) * (s - bc) * (s - ca);

    // Handle potential numerical issues
    if area_squared <= 0.0 {
        0.0
    } else {
        area_squared.sqrt()
    }
}
