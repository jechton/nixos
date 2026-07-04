_: {
  home.persistence."/persist" = {
    directories = [
      # XDG User Directories
      "Documents"
      "Downloads"
      "Music"
      "Pictures"
      "Videos"
      "Projects"

      ".ssh"
      ".gnupg"
      ".config/gh"
      ".local/share/fish"
      ".local/share/keyrings"
      ".local/share/direnv"
      ".mozilla"
      ".zen"

      # Development tool configurations and caches
      ".docker"
      ".npm"
      ".pnpm"
      ".cache/uv"
      ".vscode"
      ".config/Code/User/extensions"
      ".config/Code/User/globalStorage"
    ];

    files = [".config/Code/User/settings.json" ".config/Code/User/keybindings.json"];
  };
}
