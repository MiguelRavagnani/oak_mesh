OAK_MESH_DIR := oak_mesh
CORE_DIR := core
WRAPPER_GODOT_DIR := wrappers/godot

.PHONY: run-dyn-release run-dyn-dev build-dyn-release build-dyn-dev

run-dyn-release:
	@echo "Running with dynamic linking, as release..."
	@cargo run --release --bin core --manifest-path $(OAK_MESH_DIR)/$(CORE_DIR)/Cargo.toml

run-dyn-dev:
	@echo "Running with dynamic linking, as dev..."
	@cargo run --bin core --manifest-path $(OAK_MESH_DIR)/$(CORE_DIR)/Cargo.toml

build-dyn-release:
	@echo "Building with dynamic linking, as release..."
	@cargo build --release --bin core --manifest-path $(OAK_MESH_DIR)/$(CORE_DIR)/Cargo.toml
	@cargo build --release --bin core --manifest-path $(OAK_MESH_DIR)/$(WRAPPER_GODOT_DIR)/Cargo.toml

build-dyn-dev:
	@echo "Building with dynamic linking, as dev..."
	@cargo build --bin core --manifest-path $(OAK_MESH_DIR)/$(CORE_DIR)/Cargo.toml
	@cargo build --release --bin core --manifest-path $(OAK_MESH_DIR)/$(WRAPPER_GODOT_DIR)/Cargo.toml

wrapper-godot-build-dyn-dev:
	@echo "Building with dynamic linking, as dev..."
	@cargo build --manifest-path $(OAK_MESH_DIR)/$(WRAPPER_GODOT_DIR)/Cargo.toml

win-wrapper-godot-build-dyn-dev:
	@echo "Building with dynamic linking for Windows, as dev..."
	@cargo build --target x86_64-pc-windows-gnu --manifest-path $(OAK_MESH_DIR)/$(WRAPPER_GODOT_DIR)/Cargo.toml

win-wrapper-godot-build-dyn:
	@echo "Building with dynamic linking for Windows, as release..."
	@cargo build --release --target x86_64-pc-windows-gnu --manifest-path $(OAK_MESH_DIR)/$(WRAPPER_GODOT_DIR)/Cargo.toml

win-wrapper-godot-build-dyn-all:
	@echo "Building with dynamic linking for Windows, both as release and dev..."
	@cargo build --target x86_64-pc-windows-gnu --manifest-path $(OAK_MESH_DIR)/$(WRAPPER_GODOT_DIR)/Cargo.toml
	@cargo build --release --target x86_64-pc-windows-gnu --manifest-path $(OAK_MESH_DIR)/$(WRAPPER_GODOT_DIR)/Cargo.toml