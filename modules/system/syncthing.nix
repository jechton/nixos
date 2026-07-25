{ config, lib, ... }:
let
  username = config.burrow.users.username;
  homeDir = "/home/${username}";
in
{
  # vm is disposable and doesn't participate in the sync mesh
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    services.syncthing = {
      enable = true;
      user = username;
      group = "users";
      openDefaultPorts = true;

      # devices/folders are pushed via the API on every activation, so GUI
      # changes don't stick — this repo stays the source of truth
      settings = {
        devices = {
          bunpi = {
            id = "DJZ2V37-PZMXHB5-DA7VARQ-HDIHYHA-6O5CTYH-3TPXZ7J-R7IXNMC-HQDASQZ";
            introducer = true;
          };
          desk.id = "TCXFDVV-XJJBVEL-S4FWXMN-W64ATLR-6OLMLOV-ID3JDEK-LTI6TLN-QFZPJAZ";
          "S25 Ultra".id = "A2VUGTA-HY6VULU-B5BDXD7-D55N4XG-NRJI42C-W45TZMO-ZUAOKIA-NQ2VAAU";
        };

        folders = {
          "Driftwood Documents" = {
            path = "${homeDir}/Documents/Driftwood";
            devices = [
              "bunpi"
              "desk"
            ];
          };
          "Electronic Arts" = {
            path = "${homeDir}/.local/share/bottles/bottles/Gaming/drive_c/users/steamuser/Documents/Electronic Arts";
            devices = [
              "bunpi"
              "desk"
            ];
          };
          "Ludusavi" = {
            path = "${homeDir}/Games/Ludusavi";
            devices = [
              "bunpi"
              "desk"
            ];
          };
          "Obsidian" = {
            path = "${homeDir}/Documents/Obsidian";
            devices = [
              "S25 Ultra"
              "bunpi"
              "desk"
            ];
          };
        };
      };
    };
  };
}
