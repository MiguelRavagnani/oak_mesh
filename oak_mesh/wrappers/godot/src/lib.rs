pub mod mesh;

use godot::prelude::*;

struct HotReload;

#[gdextension]
unsafe impl ExtensionLibrary for HotReload {
    fn on_level_init(level: InitLevel) {
        godot_print!("[Rust] Init level {level:?}");
    }
    fn on_level_deinit(level: InitLevel) {
        godot_print!("[Rust] Deinit level {level:?}");
    }
}