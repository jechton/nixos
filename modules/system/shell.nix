{pkgs, ...}: {
  environment.systemPackages = [
    # keep-sorted start
    pkgs.curl
    pkgs.git # needed for flakes
    pkgs.openssl
    pkgs.wget
    # keep-sorted end
  ];

  programs.fish = {
    enable = true;
    # Translate bash scripts into fish rather than wrapping them with foreign-env, which is slower
    useBabelfish = true;
  };
  users.defaultUserShell = pkgs.fish;

  programs.nano = {
    enable = true;
    syntaxHighlight = true;
    nanorc = ''
      set tabsize 2
      set autoindent
      set atblanks
      set linenumber
      set smarthome
      set softwrap
    '';
  };
}
