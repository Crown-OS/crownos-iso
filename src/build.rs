use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{Result, bail};

use crate::util::{command, fs, user};
use crate::{components, layout};

const INSTALLER_BINARY: &str = "crownos-installer";
const STAGED_BINARY: &str = "airootfs/usr/bin/crownos-installer";
const STAGED_REPO_KEY: &str = "airootfs/usr/share/crownos/crownos-archive-keyring.asc";

pub fn run(installer: Option<&Path>, repo_key: Option<&Path>) -> Result<()> {
    if user::is_root()? {
        bail!("run as a normal user; only the mkarchiso step needs root and asks sudo for it");
    }

    let profile = layout::profile();
    let pacman_conf = components::write_pacman_conf(&components::fetch_latest_releases()?)?;

    let mut mkarchiso = Command::new("sudo");
    mkarchiso
        .args(["mkarchiso", "-v", "-r", "-w"])
        .arg(layout::target().join("iso-work"))
        .arg("-o")
        .arg(layout::out())
        .arg("-C")
        .arg(pacman_conf);

    let staged_binary = profile.join(STAGED_BINARY);
    match installer {
        Some(checkout) => fs::copy_creating_dirs(&build_installer(checkout)?, &staged_binary)?,
        None => {
            fs::remove_if_exists(&staged_binary)?;
            mkarchiso.args(["-p", INSTALLER_BINARY]);
        }
    }

    let staged_key = profile.join(STAGED_REPO_KEY);
    match repo_key {
        Some(key) => fs::copy_creating_dirs(key, &staged_key)?,
        None if !staged_key.exists() => {
            eprintln!("warning: no --repo-key given; the installer cannot add the CrownOS desktop")
        }
        None => {}
    }

    command::run(mkarchiso.arg(&profile))
}

fn build_installer(checkout: &Path) -> Result<PathBuf> {
    command::run(
        Command::new("cargo")
            .args(["build", "--release", "--locked", "--manifest-path"])
            .arg(checkout.join("Cargo.toml")),
    )?;
    Ok(checkout.join("target/release").join(INSTALLER_BINARY))
}
