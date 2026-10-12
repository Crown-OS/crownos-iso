use std::path::{Path, PathBuf};

fn root() -> &'static Path {
    Path::new(env!("CARGO_MANIFEST_DIR"))
}

pub fn profile() -> PathBuf {
    root().join("profile")
}

pub fn out() -> PathBuf {
    root().join("out")
}

pub fn target() -> PathBuf {
    root().join("target")
}

pub fn components() -> PathBuf {
    root().join("components.txt")
}
