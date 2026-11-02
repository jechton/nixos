{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.riseup-vpn ];

  programs.fish.functions = {
    vpn-on = {
      description = "Connect to the fastest IVPN server, or pick one with --pick";
      body = ''
        set -l target -fastest
        if contains -- --pick $argv
          set -l servers
          for i in (seq 10)
            set servers (ivpn servers 2>/dev/null)
            and break
            sleep 0.5
          end
          set -l rows
          for line in (printf '%s\n' $servers | string match '*WireGuard*')
            set -l f (string trim -- (string split '|' -- $line))
            set -a rows (string join '|' $f[3] $f[4] $f[5] $f[2])
          end
          set -l choice (printf '%s\n' $rows | ${pkgs.util-linux}/bin/column -t -s '|' | ${lib.getExe pkgs.fzf} --prompt 'server> ')
          or return 1
          set target (string match -r '\S+\.ivpn\.net' -- $choice)[1]
        end
        for i in (seq 10)
          ivpn firewall -lan_allow >/dev/null 2>&1
          ivpn splittun -on >/dev/null 2>&1
          set -l out (ivpn connect $target 2>&1)
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
      description = "Disconnect IVPN";
      body = ''
        ivpn disconnect
        ivpn firewall -off
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
