{
  # Installs localsend and opens its firewall port (53317 TCP/UDP).
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };
}
