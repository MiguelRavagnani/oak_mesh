OAK_MESH_DIR := oak_mesh
CORE_DIR := core

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

build-dyn-dev:
	@echo "Building with dynamic linking, as dev..."
	@cargo build --bin core --manifest-path $(OAK_MESH_DIR)/$(CORE_DIR)/Cargo.toml