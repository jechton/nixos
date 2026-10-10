{ pkgs, ... }:
{
  home.packages = [ pkgs.riseup-vpn ];

  programs.fish.functions = {
    vpn-on = {
      description = "Start the IVPN daemon and connect to the fastest server";
      body = ''
        sudo systemctl start ivpn-service
        for i in (seq 10)
          ivpn firewall -lan_allow >/dev/null 2>&1
          ivpn splittun -on >/dev/null 2>&1
          set -l out (ivpn connect -fastest 2>&1)
          if test $status -eq 0
            printf '%s\n' $out
            return
          end
          if string match -iq '*not logged in*' -- $out
            echo "vpn-on: not logged in. Run 'ivpn login ACCOUNT_ID' (find your account ID at ivpn.net) then try again." >&2
            return 1
          end
          sleep 0.5
        end
        echo "vpn-on: daemon never came up" >&2
        return 1
      '';
    };

    vpn-off = {
      description = "Disconnect IVPN and stop its daemon";
      body = ''
        ivpn disconnect
        sudo systemctl stop ivpn-service
      '';
    };

    claude = {
      description = "Run claude; bypasses the VPN tunnel when it's connected";
      body = ''
        if ivpn status 2>/dev/null | string match -q '*: CONNECTED*'
          ivpn exclude claude $argv
        else
          command claude $argv
        end
      '';
    };
  };
}
