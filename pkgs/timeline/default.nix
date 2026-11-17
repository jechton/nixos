{
  buildGoModule,
  chafa,
  coreutils,
  lib,
  makeWrapper,
  mermaid-cli,
  mermaid-preview,
}:
buildGoModule {
  pname = "timeline";
  version = "0.1.0";
  src = ./.;
  vendorHash = "sha256-RNbS40G+8rtwlSJgYLN1puTCytGfXdagQTEs6sIXwnM=";
  nativeBuildInputs = [ makeWrapper ];
  # `timeline present` shells out to mmdc and chafa.
  postInstall = ''
    wrapProgram $out/bin/timeline --prefix PATH : ${
      lib.makeBinPath [
        chafa
        coreutils
        mermaid-cli
        mermaid-preview
      ]
    }
  '';
  meta.mainProgram = "timeline";
}
