{ lib, pkgs, rust-bin, makeRustPlatform, runCommand, symlinkJoin, sources, version ? "unstable" }:

let
  # crownconnect-linux and fileshare-linux need a newer compiler than the
  # channel ships.
  toolchain = rust-bin.stable."1.97.1".minimal;
  rustPlatform = makeRustPlatform { cargo = toolchain; rustc = toolchain; };

  tree = runCommand "crownos-sources" { } ''
    mkdir $out
    ${lib.concatStrings (lib.mapAttrsToList (name: source: "cp -r ${source} $out/${name}\n") sources)}
  '';

  # Loaded with dlopen by winit and wgpu rather than linked, so they are
  # added to every binary's RUNPATH.
  dlopened = with pkgs; [ wayland libxkbcommon vulkan-loader libGL ];

  component = { pname, repo ? pname, cargoPackage ? null, postInstall ? "" }:
    rustPlatform.buildRustPackage {
      inherit pname version postInstall;
      src = tree;
      cargoRoot = repo;
      buildAndTestSubdir = repo;
      cargoLock = {
        lockFile = "${sources.${repo}}/Cargo.lock";
        allowBuiltinFetchGit = true;
      };
      cargoBuildFlags = lib.optionals (cargoPackage != null) [ "--package" cargoPackage ];
      nativeBuildInputs = with pkgs; [ pkg-config cmake rustPlatform.bindgenHook ];
      buildInputs = with pkgs; [
        wayland libxkbcommon libinput seatd systemdLibs mesa libGL pixman fontconfig freetype
        vulkan-loader alsa-lib dbus pipewire ffmpeg libopus libdrm openssl onnxruntime
      ];
      ORT_LIB_LOCATION = "${pkgs.onnxruntime}/lib";
      ORT_PREFER_DYNAMIC_LINK = "1";
      doCheck = false;
      postFixup = ''
        for binary in $out/bin/* $out/lib/*; do
          [ -f "$binary" ] && [ ! -L "$binary" ] && patchelf --add-rpath ${lib.makeLibraryPath dlopened} "$binary"
        done
      '';
    };

  components = {
    crownpositor = component {
      pname = "crownpositor";
      cargoPackage = "compositor";
      postInstall = "mv $out/bin/compositor $out/bin/crownpositor";
    };
    crownbar = component { pname = "crownbar"; };
    crownotify = component { pname = "crownotify"; };
    crownpaper = component { pname = "crownpaper"; };
    crownpad = component { pname = "crownpad"; };
    crowndock = component { pname = "crowndock"; };
    crownos-home = component { pname = "crownos-home"; };
    crownos-clipboard = component { pname = "crownos-clipboard"; };
    crownos-settings = component {
      pname = "crownos-settings";
      postInstall = "ln -s crownsettings $out/bin/crownos-settings";
    };
    crowndictator = component { pname = "crowndictator"; };
    crownconnect = component { pname = "crownconnect"; repo = "crownconnect-linux"; };
    fileshare = component {
      pname = "fileshare";
      repo = "fileshare-linux";
      cargoPackage = "fileshare-linux";
    };
    xdg-desktop-portal-crownos = component {
      pname = "xdg-desktop-portal-crownos";
      postInstall = ''
        mkdir -p $out/libexec $out/share/dbus-1/services $out/lib/systemd/user
        mv $out/bin/xdg-desktop-portal-crownos $out/bin/crownos-portal-dialog $out/libexec/
        data=${sources.xdg-desktop-portal-crownos}/data
        install -Dm644 $data/crownos.portal $out/share/xdg-desktop-portal/portals/crownos.portal
        install -Dm644 $data/crownos-portals.conf $out/share/xdg-desktop-portal/crownos-portals.conf
        substitute $data/org.freedesktop.impl.portal.desktop.crownos.service.in \
          $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.crownos.service \
          --replace-fail @libexecdir@ $out/libexec
        substitute $data/xdg-desktop-portal-crownos.service.in \
          $out/lib/systemd/user/xdg-desktop-portal-crownos.service \
          --replace-fail @libexecdir@ $out/libexec
      '';
    };
  };

  session = runCommand "crownos-session-${version}" { } ''
    install -Dm755 ${../crownos-desktop/crownos-session} $out/bin/crownos-session
    install -Dm644 ${../crownos-desktop/crownos.desktop} $out/share/wayland-sessions/crownos.desktop
    install -Dm644 ${../crownos-desktop/compositor.ron} $out/share/crownos/compositor.ron
  '';
in
components // {
  crownos-desktop = symlinkJoin {
    name = "crownos-desktop-${version}";
    paths = lib.attrValues components ++ [ session ];
    passthru.providedSessions = [ "crownos" ];
  };
}
