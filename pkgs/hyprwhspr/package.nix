{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  makeWrapper,
  wrapGAppsHook4,
  gobject-introspection,
  gtk4,
  gtk4-layer-shell,
  wtype,
  wl-clipboard,
  libnotify,
  pulseaudio,
  ydotool,
  bash,
  cudaSupport ? false,
  cudaPackages,
  cudaCapabilities ? [ "8.9" ],
  autoAddDriverRunpath,
}:
let
  # nixpkgs' own sounddevice/pyudev already hardcode absolute
  # libportaudio.so/libudev.so store paths in place of ctypes'
  # find_library() (which doesn't work in a locked-down systemd unit's
  # PATH anyway), so no extra patching needed for those here.
  pywhispercpp = python3.pkgs.callPackage ./pywhispercpp.nix {
    inherit
      cudaSupport
      cudaPackages
      cudaCapabilities
      autoAddDriverRunpath
      ;
  };

  pythonEnv = python3.withPackages (ps: [
    pywhispercpp
    ps.sounddevice
    ps.numpy
    ps.soxr
    ps.evdev
    ps.pyudev
    ps.pulsectl
    ps.rich
    ps.pyperclip
    ps.dbus-python
    ps.requests
    ps.pygobject3
    ps.pycairo
  ]);

  runtimePath = lib.makeBinPath [
    wtype
    wl-clipboard
    libnotify
    pulseaudio
    ydotool
    pythonEnv
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "hyprwhspr";
  version = "1.40.0";

  src = fetchFromGitHub {
    owner = "goodroot";
    repo = "hyprwhspr";
    tag = "v${finalAttrs.version}";
    hash = "sha256-SYzcpz9/YuHz5RKOqce8jQm6JGPdEhfd4lIOwaZB7WQ=";
  };

  nativeBuildInputs = [
    makeWrapper
    wrapGAppsHook4
    gobject-introspection
  ];

  buildInputs = [
    gtk4
    gtk4-layer-shell
  ];

  dontWrapGApps = true;

  postPatch = ''
    substituteInPlace lib/cli.py \
      --replace-fail "return 'unknown'" "return 'v${finalAttrs.version}'"
    substituteInPlace lib/mic_osd/runner.py \
      --replace-fail "'/usr/lib64/libgtk4-layer-shell.so*'," "'${gtk4-layer-shell}/lib/libgtk4-layer-shell.so*',"
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/hyprwhspr $out/bin $out/share/systemd/user
    cp -r lib $out/lib/hyprwhspr/lib
    cp -r share $out/lib/hyprwhspr/share
    cp -r config $out/lib/hyprwhspr/config

    cat > $out/bin/hyprwhspr <<EOF
    #!${bash}/bin/bash
    export HYPRWHSPR_ROOT="$out/lib/hyprwhspr"
    export PYTHONPATH="$out/lib/hyprwhspr/lib\''${PYTHONPATH:+:\$PYTHONPATH}"
    py="${pythonEnv}/bin/python3"
    cli="$out/lib/hyprwhspr/lib/cli.py"
    case "\$1" in
      -h|--help|help) exec "\$py" "\$cli" --help ;;
      --version) exec "\$py" "\$cli" --version ;;
      test|setup|install|config|waybar|systemd|status|model|validate|uninstall|backend|state|mic-osd|keyboard|record)
        exec "\$py" "\$cli" "\$@" ;;
    esac
    exec "\$py" "$out/lib/hyprwhspr/lib/main.py" "\$@"
    EOF
    chmod +x $out/bin/hyprwhspr

    substitute config/systemd/hyprwhspr.service $out/share/systemd/user/hyprwhspr.service \
      --replace-fail "ExecStart=/usr/lib/hyprwhspr/bin/hyprwhspr" "ExecStart=$out/bin/hyprwhspr" \
      --replace-fail "Environment=HYPRWHSPR_ROOT=/usr/lib/hyprwhspr" "Environment=HYPRWHSPR_ROOT=$out/lib/hyprwhspr" \
      --replace-fail "/bin/bash" "${bash}/bin/bash"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/hyprwhspr \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${runtimePath}
  '';

  passthru = {
    inherit pywhispercpp pythonEnv;
  };

  meta = {
    description = "Push-to-talk speech-to-text for Linux desktops using whisper.cpp";
    homepage = "https://github.com/goodroot/hyprwhspr";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "hyprwhspr";
  };
})
