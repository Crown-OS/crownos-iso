# crownos-iso

Builds the CrownOS ISO and publishes the signed `[crownos]` package repository
as GitHub releases of this repository, served at `https://repo.crownos.org`.

- `components.toml` pins every CrownOS package (change it with `just pin`).
- `packaging/` builds `crownos-base`, `crownos-release`, `crownos-keyring` and `crownos-source`.
- `defaults/` holds the CrownOS settings defaults, one file per section, for the live image and
  every installed system; `defaults/live/` holds only the keys that the live image changes.
- `dotfiles/` holds the configs of other programs at the paths they install to; `themes/gtk/`
  holds the GTK themes. `crownos-base` installs all three.
- `profile/` is the archiso profile and holds only files of the live image.
- `releases/<X.Y.Z>/` holds the restart kind, notes and post-update script of each release.

```sh
just check            # lint and validate
just resolve          # download and build every package into target/repo
just build            # build the ISO into out/
just test-install     # install it unattended in QEMU
```

See [docs/publishing.md](docs/publishing.md) for the channels, the release flow
and the one-time setup.
