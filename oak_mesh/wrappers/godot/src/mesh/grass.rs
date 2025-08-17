use godot::prelude::*;

#[derive(Clone)]
pub struct GrassBlade {
    pub transform: Transform3D,
    pub params: Color,
}

impl GrassBlade {
    pub fn new(transform: Transform3D, params: Color) -> Self {
        Self { transform, params }
    }
}