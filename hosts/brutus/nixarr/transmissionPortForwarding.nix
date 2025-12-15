{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.nixarr;
  vpnNamespace = "wg";
in {
  config = lib.mkIf (cfg.transmission.enable && cfg.transmission.vpn.enable) {
    environment.systemPackages = with pkgs; [
      libnatpmp
      ripgrep
      iptables
    ];

    systemd.timers."transmission-port-forwarding" = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "45s";
        OnUnitActiveSec = "45s";
        Unit = "transmission-port-forwarding.service";
      };
    };

    systemd.services."transmission-port-forwarding" = {
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script =
        /*
        bash
        */
        ''
          set -u

          port_file="${cfg.stateDir}/transmission-port"

          # Renew TCP first to get a port
          result_tcp="$(${pkgs.iproute2}/bin/ip netns exec ${vpnNamespace} ${pkgs.libnatpmp}/bin/natpmpc -a 1 0 tcp 60 -g 10.2.0.1)"
          if [ $? -ne 0 ]; then
            echo "ERROR: natpmpc failed for TCP" >&2
            exit 1
          fi
          echo "$result_tcp"
          new_port="$(echo "$result_tcp" | ${pkgs.ripgrep}/bin/rg --only-matching --replace '$1' 'Mapped public port (\d+) protocol ... to local port 0 lifetime 60')"
          if [ -z "$new_port" ]; then
            echo "ERROR: Failed to parse new TCP port" >&2
            exit 1
          fi
          old_port="$(cat "$port_file" 2>/dev/null || echo ''')"
          echo "Mapped new TCP port $new_port, old was $old_port."
          echo "$new_port" >"$port_file"

          # NEW: Update Transmission's peer port via RPC
          echo "Updating Transmission peer port to $new_port..."
          if ${cfg.transmission.package}/bin/transmission-remote --port "$new_port"; then
            echo "Successfully updated Transmission port to $new_port."
          else
            echo "WARNING: Failed to update Transmission port (check RPC auth/connectivity)." >&2
          fi

          # Renew UDP using the same port
          result_udp="$(${pkgs.iproute2}/bin/ip netns exec ${vpnNamespace} ${pkgs.libnatpmp}/bin/natpmpc -a "$new_port" 0 udp 60 -g 10.2.0.1)"
          if [ $? -ne 0 ]; then
            echo "ERROR: natpmpc failed for UDP" >&2
            exit 1
          fi
          echo "$result_udp"

          for protocol in tcp udp; do
            if ${pkgs.iptables}/bin/iptables -C INPUT -p "$protocol" --dport "$new_port" -j ACCEPT; then
              echo "New $protocol port $new_port already open."
            else
              echo "Opening new $protocol port $new_port."
              ${pkgs.iptables}/bin/iptables -I INPUT -p "$protocol" --dport "$new_port" -j ACCEPT
            fi

            if [ "$new_port" = "$old_port" ]; then
              echo "New $protocol port same as old, not closing."
            else
              if [ -n "$old_port" ] && ${pkgs.iptables}/bin/iptables -C INPUT -p "$protocol" --dport "$old_port" -j ACCEPT; then
                echo "Closing old $protocol port $old_port."
                ${pkgs.iptables}/bin/iptables -D INPUT -p "$protocol" --dport "$old_port" -j ACCEPT
              else
                echo "Old $protocol port $old_port not open."
              fi
            fi
          done
        '';
    };
  };
}
