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

      # No owning module for these
      ".ssh"
      ".local/share/keyrings"
      ".docker"
    ];
  };
}
