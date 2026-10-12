use std::borrow::Cow;
use std::path::Path;
use std::process::Command;

use anyhow::{Context, Result};

use crate::layout;
use crate::util::{command, fs};

const OVMF_CODE: &str = "/usr/share/edk2/x64/OVMF_CODE.4m.fd";
const OVMF_VARS_TEMPLATE: &str = "/usr/share/edk2/x64/OVMF_VARS.4m.fd";
const DISK_SIZE: &str = "32G";

pub fn run(iso: Option<&Path>) -> Result<()> {
    let iso = match iso {
        Some(iso) => Cow::Borrowed(iso),
        None => Cow::Owned(
            fs::newest_with_extension(&layout::out(), "iso")?
                .context("no ISO in out/; run `build` first")?,
        ),
    };

    let target = layout::target();
    let disk = target.join("disk.qcow2");
    let ovmf_vars = target.join("OVMF_VARS.fd");
    if !disk.exists() {
        command::run(
            Command::new("qemu-img")
                .args(["create", "-f", "qcow2"])
                .arg(&disk)
                .arg(DISK_SIZE),
        )?;
    }
    if !ovmf_vars.exists() {
        fs::copy_creating_dirs(Path::new(OVMF_VARS_TEMPLATE), &ovmf_vars)?;
    }

    command::run(
        Command::new("qemu-system-x86_64")
            .args(["-enable-kvm", "-cpu", "host", "-m", "4G", "-smp", "4"])
            .args([
                "-drive",
                &format!("if=pflash,format=raw,readonly=on,file={OVMF_CODE}"),
            ])
            .args([
                "-drive",
                &format!("if=pflash,format=raw,file={}", ovmf_vars.display()),
            ])
            .args([
                "-drive",
                &format!("if=virtio,format=qcow2,file={}", disk.display()),
            ])
            .arg("-cdrom")
            .arg(iso.as_ref())
            .args(["-device", "virtio-vga-gl", "-display", "gtk,gl=on"])
            .args(["-device", "qemu-xhci", "-device", "usb-tablet"])
            .args(["-nic", "user,model=virtio-net-pci"]),
    )
}
