use std::os::unix::fs::MetadataExt;

use anyhow::{Context, Result};

pub fn is_root() -> Result<bool> {
    let process = std::fs::metadata("/proc/self").context("reading /proc/self")?;
    Ok(process.uid() == 0)
}
