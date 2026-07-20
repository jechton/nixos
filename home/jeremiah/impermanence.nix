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
      ".local/share/gnupg"
      ".config/gh"
      ".local/share/fish"
      ".local/share/keyrings"
      ".local/share/direnv"
      ".mozilla"
      ".zen"

      # Development tool configurations and caches
      ".docker"
      ".cache/uv"
      ".cache/npm"
      ".local/share/npm"
      ".local/share/pnpm"
      ".vscode"
      ".config/Code/User/extensions"
      ".config/Code/User/globalStorage"
      ".claude"
    ];

    files = [
      ".config/Code/User/settings.json"
      ".config/Code/User/keybindings.json"
      ".claude.json"
    ];
  };
}
