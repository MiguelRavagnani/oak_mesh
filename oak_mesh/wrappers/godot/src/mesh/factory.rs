use godot::prelude::*;
use godot::classes::ArrayMesh;
use godot::classes::mesh::{ArrayType, PrimitiveType};
use godot::obj::IndexEnum;
use godot::global::randf_range;
use crate::mesh::utils::{rand_bcc, triangle_area, from_bcc_vector3, quat_shortest_arc};

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
pub struct MeshFactory {
    base: Base<RefCounted>,
    #[export] 
    mesh_type: MeshType,
}

#[godot_api]
impl MeshFactory {
    #[signal]
    fn mesh_generated(mesh: Gd<ArrayMesh>);
    
    #[func]
    fn generate_mesh(&self) -> Gd<ArrayMesh> {
        godot_print!("[Rust] Generating mesh of type: {:?}", self.mesh_type);
        
        let mesh = match self.mesh_type {
            MeshType::GrassBlade => self.create_grass_blade(),
            MeshType::Placeholder => self.create_placeholder(),
        };
        mesh
    }
    
    #[func]
    fn generate_mesh_with_type(&mut self, mesh_type: MeshType) -> Gd<ArrayMesh> {
        self.mesh_type = mesh_type;
        self.generate_mesh()
    }
    
    fn create_grass_blade(&self) -> Gd<ArrayMesh> {
        // More detailed grass blade geometry
        let vertices = PackedVector3Array::from(&[
            // Bottom (wide base)
            Vector3::new(-0.1, 0.0, 0.0),
            Vector3::new(0.1, 0.0, 0.0),

            // Mid 1
            Vector3::new(-0.05, 0.33, 0.0),
            Vector3::new(0.05, 0.33, 0.0),

            // Mid 2
            Vector3::new(-0.03, 0.66, 0.0),
            Vector3::new(0.03, 0.66, 0.0),

            // Top (thin tip)
            Vector3::new(0.0, 1.0, 0.0),
        ]);

        // UVs mapped bottom→top
        let uvs = PackedVector2Array::from(&[
            Vector2::new(0.0, 0.0), Vector2::new(1.0, 0.0),
            Vector2::new(0.0, 0.33), Vector2::new(1.0, 0.33),
            Vector2::new(0.0, 0.66), Vector2::new(1.0, 0.66),
            Vector2::new(0.5, 1.0),
        ]);

        // Indices → two tris per segment
        let indices = PackedInt32Array::from(&[
            0, 1, 2,  1, 3, 2, // base
            2, 3, 4,  3, 5, 4, // mid
            4, 5, 6,           // tip triangle
        ]);

        let mut arrays = VariantArray::new();
        arrays.resize(ArrayType::MAX.to_index(), &Variant::nil());
        arrays.set(ArrayType::VERTEX.to_index(), &vertices.to_variant());
        arrays.set(ArrayType::INDEX.to_index(), &indices.to_variant());
        arrays.set(ArrayType::TEX_UV.to_index(), &uvs.to_variant());

        let mut mesh = ArrayMesh::new_gd();
        mesh.add_surface_from_arrays(PrimitiveType::TRIANGLES, &arrays);

        mesh.set_custom_aabb(Aabb {
            position: Vector3::new(-0.2, 0.0, -0.05),
            size: Vector3::new(0.4, 1.0, 0.1),
        });

        mesh
    }

    fn create_placeholder(&self) -> Gd<ArrayMesh> {
        ArrayMesh::new_gd()
    }
    
    #[func]
    fn generate_grass_distribution(
        &self,
        mesh: Gd<ArrayMesh>,
        density: f32,
        blade_width: Vector2,
        blade_height: Vector2,
        sway_pitch: Vector2,
        sway_yaw: Vector2,
    ) -> Array<Array<Variant>> {
        godot_print!("[Rust] generate_grass_distribution called with density: {}", density);

        self.generate_grass_blades_internal(
            mesh, density, blade_width, blade_height, sway_pitch, sway_yaw
        )
    }
    
    // Keep the internal logic separate - returns Vec<GrassBlade> for internal use
    fn generate_grass_blades_internal(
        &self,
        mesh: Gd<ArrayMesh>,
        density: f32,
        blade_width: Vector2,
        blade_height: Vector2,
        sway_pitch: Vector2,
        sway_yaw: Vector2,
    ) -> Array<Array<Variant>> {
        if mesh.get_surface_count() == 0 {
            godot_print!("[Rust] Error: Mesh has no surfaces");
            return Array::new();
        }
        
        let surface: Array<Variant> = mesh.surface_get_arrays(0);
        let indices = surface.get(ArrayType::INDEX.to_index()).unwrap_or_default();
        let positions = surface.get(ArrayType::VERTEX.to_index()).unwrap_or_default();
        let normals = surface.get(ArrayType::NORMAL.to_index()).unwrap_or_default();
        
        let vec_positions = PackedVector3Array::from_variant(&positions);
        let vec_normals = PackedVector3Array::from_variant(&normals);
        let vec_indices = PackedInt32Array::from_variant(&indices);
        
        godot_print!("[Rust] Mesh data - Vertices: {}, Normals: {}, Indices: {}", 
                vec_positions.len(), vec_normals.len(), vec_indices.len());
        
        self.generate_grass_blades(
            &vec_positions,
            &vec_normals,
            &vec_indices,
            density,
            blade_width,
            blade_height,
            sway_pitch,
            sway_yaw,
        )
    }
    
    fn generate_grass_blades(
        &self,
        positions: &PackedVector3Array,
        normals: &PackedVector3Array,
        indices: &PackedInt32Array,
        density: f32,
        blade_width: Vector2,
        blade_height: Vector2,
        sway_pitch: Vector2,
        sway_yaw: Vector2,
    ) -> Array<Array<Variant>> {
        let mut spawns = Array::new();
        
        // Handle case where mesh has no indices (direct vertex array)
        if indices.len() == 0 {
            // Process vertices directly in groups of 3
            godot_print!("[Rust] No indices found, processing vertices directly");
            for index in (0..positions.len()).step_by(3) {
                if index + 2 >= positions.len() {
                    break;
                }
                
                let j = index;
                let k = index + 1;
                let l = index + 2;
                
                let area = triangle_area(positions[j], positions[k], positions[l]);
                let blades_per_face = (area * density).round() as usize;
                
                for _ in 0..blades_per_face { // Fixed: replaced * with _
                    let uvw = rand_bcc();
                    let position = from_bcc_vector3(uvw, positions[j], positions[k], positions[l]);
                    
                    // Handle case where normals might not exist
                    let normal = if normals.len() > l {
                        from_bcc_vector3(uvw, normals[j], normals[k], normals[l]).normalized()
                    } else {
                        // Calculate face normal if no vertex normals
                        let edge1 = positions[k] - positions[j];
                        let edge2 = positions[l] - positions[j];
                        edge1.cross(edge2).normalized()
                    };
                    
                    let q1 = Quaternion::from_axis_angle(Vector3::UP, (randf_range(0.0, 360.0) * std::f64::consts::PI / 180.0) as f32);
                    let q2 = quat_shortest_arc(Vector3::UP, normal);
                    let rotation = Basis::from_quaternion(q2 * q1);
                    let transform = Transform3D::new(rotation, position);
                    
                    let params = Color {
                        r: randf_range(blade_width.x as f64, blade_width.y as f64) as f32,
                        g: randf_range(blade_height.x as f64, blade_height.y as f64) as f32,
                        b: (randf_range(sway_pitch.x as f64, sway_pitch.y as f64) * std::f64::consts::PI / 180.0) as f32,
                        a: (randf_range(sway_yaw.x as f64, sway_yaw.y as f64) * std::f64::consts::PI / 180.0) as f32,
                    };

                    let mut entry: Array<Variant> = Array::new();

                    entry.push(&transform.to_variant());
                    entry.push(&params.to_variant());
                    
                    spawns.push(&entry);
                }
            }
        } else {
            // Process indexed vertices
            godot_print!("[Rust] Processing indexed vertices");
            for index in (0..indices.len()).step_by(3) {
                if index + 2 >= indices.len() {
                    break;
                }
                
                let j = indices[index] as usize;
                let k = indices[index + 1] as usize;
                let l = indices[index + 2] as usize;
                
                // Bounds checking
                if j >= positions.len() || k >= positions.len() || l >= positions.len() {
                    continue;
                }
                
                let area = triangle_area(positions[j], positions[k], positions[l]);
                let blades_per_face = (area * density).round() as usize;
                
                for _ in 0..blades_per_face { // Fixed: replaced * with _
                    let uvw = rand_bcc();
                    let position = from_bcc_vector3(uvw, positions[j], positions[k], positions[l]);
                    
                    let normal = if normals.len() > l {
                        from_bcc_vector3(uvw, normals[j], normals[k], normals[l]).normalized()
                    } else {
                        // Calculate face normal if no vertex normals
                        let edge1 = positions[k] - positions[j];
                        let edge2 = positions[l] - positions[j];
                        edge1.cross(edge2).normalized()
                    };
                    
                    let q1 = Quaternion::from_axis_angle(Vector3::UP, (randf_range(0.0 as f64, 360.0 as f64) * std::f64::consts::PI / 180.0) as f32); // Fixed: removed _f64 and used proper conversion
                    let q2 = quat_shortest_arc(Vector3::UP, normal);
                    let rotation = Basis::from_quaternion(q2 * q1); // Fixed: from_quaternion might not exist, try from_quat
                    let transform = Transform3D::new(rotation, position);
                    
                    let params = Color {
                        r: randf_range(blade_width.x.as_f64(), blade_width.y.as_f64()) as f32, // Fixed: removed as f64 and as f32
                        g: randf_range(blade_height.x.as_f64(), blade_height.y.as_f64()) as f32, // Fixed: removed as f64 and as f32
                        b: (randf_range(sway_pitch.x.as_f64(), sway_pitch.y.as_f64()) * std::f64::consts::PI / 180.0) as f32, // Fixed: proper degree to radian conversion
                        a: (randf_range(sway_yaw.x.as_f64(), sway_yaw.y.as_f64()) * std::f64::consts::PI / 180.0) as f32, // Fixed: proper degree to radian conversion
                    };
                    
                    let mut entry: Array<Variant> = Array::new();

                    entry.push(&transform.to_variant());
                    entry.push(&params.to_variant());
                    
                    spawns.push(&entry);
                }
            }
        }
        
        godot_print!("[Rust] Generated {} spawn points", spawns.len());
        spawns
    }
}

#[derive(GodotConvert, Var, Export, Copy, Clone, Debug, Default)]
#[godot(via = GString)]
pub enum MeshType {
    #[default]
    GrassBlade,
    Placeholder,
}