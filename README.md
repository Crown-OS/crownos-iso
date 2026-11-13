# crownos-iso

Builds the CrownOS ISO and publishes the signed `[crownos]` package repository
as GitHub releases of this repository, served at `https://repo.crownos.org`.

- `components.toml` pins every CrownOS package (change it with `just pin`).
- `packaging/` builds `crownos-base`, `crownos-release`, `crownos-keyring` and `crownos-source`.
- `profile/` is the archiso profile; `config/` holds the default user configs.

```sh
just check            # lint and validate
just resolve          # download and build every package into target/repo
just build            # build the ISO into out/
just test-install     # install it unattended in QEMU
```

See [docs/publishing.md](docs/publishing.md) for the channels, the release flow
and the one-time setup.
