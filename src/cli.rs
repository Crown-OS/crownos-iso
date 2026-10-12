use std::path::PathBuf;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(about = "Builds and boots the CrownOS installer ISO")]
pub struct Cli {
    #[command(subcommand)]
    pub action: Action,
}

#[derive(Subcommand)]
pub enum Action {
    /// Pack the latest CrownOS component releases into a bootable ISO under out/
    Build {
        /// Build this crownos-installer checkout instead of using its latest release
        #[arg(long)]
        installer: Option<PathBuf>,
        /// The CrownOS repository signing key the installer trusts
        #[arg(long)]
        repo_key: Option<PathBuf>,
    },
    /// Boot an ISO in QEMU with UEFI firmware and virgl GPU acceleration
    Run {
        /// The ISO to boot [default: the newest one in out/]
        iso: Option<PathBuf>,
    },
}
