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
          new_port="$(echo "$result_tcp" | ${pkgs.ripgrep}/bin/rg --only-matching --replace '$1' 'Mapped public port (\d+) protocol ... to local port 0 lifetime 60')"
          if [ -z "$new_port" ]; then
            echo "ERROR: Failed to parse new TCP port" >&2
            exit 1
          fi
          old_port="$(cat "$port_file" 2>/dev/null || echo ''')"
          echo "$new_port" >"$port_file"

          port_changed=false
          if [ "$new_port" != "$old_port" ]; then
            port_changed=true
            echo "Port changed: $old_port -> $new_port"
          fi

          # Update Transmission's peer port via RPC
          if ! ${cfg.transmission.package}/bin/transmission-remote --port "$new_port" >/dev/null 2>&1; then
            echo "WARNING: Failed to update Transmission port (check RPC auth/connectivity)." >&2
          fi

          # Renew UDP using the same port
          if ! ${pkgs.iproute2}/bin/ip netns exec ${vpnNamespace} ${pkgs.libnatpmp}/bin/natpmpc -a "$new_port" 0 udp 60 -g 10.2.0.1 >/dev/null; then
            echo "ERROR: natpmpc failed for UDP" >&2
            exit 1
          fi

          for protocol in tcp udp; do
            if ! ${pkgs.iptables}/bin/iptables -C INPUT -p "$protocol" --dport "$new_port" -j ACCEPT 2>/dev/null; then
              if [ "$port_changed" = true ]; then
                echo "Opening $protocol port $new_port"
              fi
              ${pkgs.iptables}/bin/iptables -I INPUT -p "$protocol" --dport "$new_port" -j ACCEPT
            fi

            if [ "$new_port" != "$old_port" ] && [ -n "$old_port" ]; then
              if ${pkgs.iptables}/bin/iptables -C INPUT -p "$protocol" --dport "$old_port" -j ACCEPT 2>/dev/null; then
                echo "Closing old $protocol port $old_port"
                ${pkgs.iptables}/bin/iptables -D INPUT -p "$protocol" --dport "$old_port" -j ACCEPT
              fi
            fi
          done
        '';
    };
  };
}
