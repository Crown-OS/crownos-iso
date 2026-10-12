mod build;
mod cli;
mod components;
mod layout;
mod qemu;
mod util;

use anyhow::Result;
use clap::Parser;
use cli::{Action, Cli};

fn main() -> Result<()> {
    match Cli::parse().action {
        Action::Build {
            installer,
            repo_key,
        } => build::run(installer.as_deref(), repo_key.as_deref()),
        Action::Run { iso } => qemu::run(iso.as_deref()),
    }
}
