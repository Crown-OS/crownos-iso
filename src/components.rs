use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{Context, Result};

use crate::layout;
use crate::util::{command, fs as files};

const REPO_NAME: &str = "crownos";
const PACKAGE_SUFFIX: &str = ".pkg.tar.zst";
const STAGED_REPO: &str = "airootfs/usr/share/crownos/repo";

pub fn fetch_latest_releases() -> Result<PathBuf> {
    let repo_dir = layout::profile().join(STAGED_REPO);
    files::remove_if_exists(&repo_dir)?;
    fs::create_dir_all(&repo_dir).with_context(|| format!("creating {}", repo_dir.display()))?;

    let components_list = layout::components();
    let repositories = fs::read_to_string(&components_list)
        .with_context(|| format!("reading {}", components_list.display()))?;
    for repository in repositories
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
    {
        command::run(
            Command::new("gh")
                .args(["release", "download", "--repo", repository, "--dir"])
                .arg(&repo_dir)
                .args(["--pattern", &format!("*{PACKAGE_SUFFIX}")]),
        )?;
    }

    command::run(
        Command::new("repo-add")
            .arg(repo_dir.join(format!("{REPO_NAME}.db.tar.zst")))
            .args(files::files_with_suffix(&repo_dir, PACKAGE_SUFFIX)?),
    )?;
    Ok(repo_dir)
}

pub fn write_pacman_conf(repo_dir: &Path) -> Result<PathBuf> {
    let profile_conf = layout::profile().join("pacman.conf");
    let base = fs::read_to_string(&profile_conf)
        .with_context(|| format!("reading {}", profile_conf.display()))?;
    let build_conf = layout::target().join("pacman.conf");
    let repo_section = format!(
        "\n[{REPO_NAME}]\nSigLevel = Optional TrustAll\nServer = file://{}\n",
        repo_dir.display()
    );
    fs::create_dir_all(layout::target()).context("creating target/")?;
    fs::write(&build_conf, base + &repo_section)
        .with_context(|| format!("writing {}", build_conf.display()))?;
    Ok(build_conf)
}
