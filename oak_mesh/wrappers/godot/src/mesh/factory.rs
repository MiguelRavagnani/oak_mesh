use godot::prelude::*;
use godot::classes::ArrayMesh;
use godot::classes::mesh::{ArrayType, PrimitiveType};
use godot::obj::IndexEnum;

struct HotReload;

#[gdextension]
unsafe impl ExtensionLibrary for HotReload {
    fn on_level_init(level: InitLevel) {
        println!("[Rust]   Init level {level:?}");
    }

    fn on_level_deinit(level: InitLevel) {
        println!("[Rust]   Deinit level {level:?}");
    }
}

#[derive(GodotClass)]
#[class(init, base=Node)]
struct Factory {
    _base: Base<Node>,
    #[export]
    mesh: MeshType,
}

#[godot_api]
impl Factory {
    #[signal]
    fn mesh_generated(mesh: Gd<ArrayMesh>);

    #[func]
    fn set_mesh_type(&mut self, mesh_type: MeshType) {
        self.mesh = mesh_type;
    }

    #[func]
    fn get_mesh_type(&self) -> MeshType {
        self.mesh
    }

    #[func]
    fn generate_mesh(&self) -> Gd<ArrayMesh> {
        let mesh = match self.mesh {
            MeshType::GrassBlade => self.create_grass_blade(),
            MeshType::Placeholder => self.create_placeholder(),
        };
        mesh
    }

    #[func]
    fn generate_mesh_with_type(&mut self, mesh_type: MeshType) -> Gd<ArrayMesh> {
        self.mesh = mesh_type;
        self.generate_mesh()
    }

    fn create_grass_blade(&self) -> Gd<ArrayMesh> {
        let vertices = PackedVector3Array::from(&[
            Vector3::new(-0.5, 0.0, 0.0),
            Vector3::new(0.5, 0.0, 0.0),
            Vector3::new(0.0, 1.0, 0.0),
        ]);

        let uvs = PackedVector2Array::from(&[
            Vector2::new(0.0, 0.0),
            Vector2::new(0.0, 0.0),
            Vector2::new(1.0, 1.0),
        ]);

        let mut arrays = VariantArray::new();
        arrays.resize(ArrayType::MAX.to_index(),  &Variant::nil());

        arrays.set(ArrayType::VERTEX.to_index(), &vertices.to_variant());
        arrays.set(ArrayType::TEX_UV2.to_index(), &uvs.to_variant());

        let mut mesh = ArrayMesh::new_gd();
        mesh.add_surface_from_arrays(
            PrimitiveType::TRIANGLES,
            &arrays,
        );

        mesh.set_custom_aabb(Aabb {
            position: Vector3::new(-0.5, 0.0, -0.5), size: Vector3::new(1.0, 1.0, 1.0)
        });

        mesh
    }

    fn create_placeholder(&self) -> Gd<ArrayMesh> {
        ArrayMesh::new_gd()
    }
}

#[derive(GodotConvert, Var, Export, Copy, Clone, Debug, Default)]
#[godot(via = GString)]
enum MeshType {
    #[default]
    GrassBlade,
    Placeholder,
}