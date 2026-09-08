{ pkgs, ... }:
let
  # Fonts not packaged in nixpkgs, fetched straight from upstream.
  ignazio = pkgs.stdenvNoCC.mkDerivation {
    pname = "ignazio";
    version = "1.00";

    src = pkgs.fetchzip {
      url = "https://dl.dafont.com/dl/?f=ignazio";
      hash = "sha256-hyylkwvcBqQaXMosxi3CzqYKkg57v6dwbMjZsqg8KUw=";
      extension = "zip";
      stripRoot = false;
    };

    installPhase = ''
      runHook preInstall
      install -Dm644 *.ttf -t $out/share/fonts/truetype
      runHook postInstall
    '';
  };
in
{
  fonts.packages = [ ignazio ];
}
