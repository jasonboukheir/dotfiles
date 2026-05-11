{pkgs}:
pkgs.writeShellApplication {
  name = "disk";

  # zfs/zpool and cryptsetup intentionally come from the running system —
  # their userspace must match the loaded kernel module, which on brutus is
  # zfs_unstable. Pulling pkgs.zfs from pkgs-unstable risks version skew.
  runtimeInputs = with pkgs; [
    smartmontools
    util-linux
    gawk
    gnugrep
    gnused
    coreutils
    memtester
    pciutils
  ];

  text = ''
        if [ "$(uname -s)" != "Linux" ]; then
          echo "disk: only meaningful on Linux (this is $(uname -s))" >&2
          exit 1
        fi

        CYAN=$'\e[36m'
        GREEN=$'\e[32m'
        RED=$'\e[31m'
        YELLOW=$'\e[33m'
        BOLD=$'\e[1m'
        DIM=$'\e[2m'
        RST=$'\e[0m'

        sudo_cmd() {
          # Echo the command in dim, then run it with sudo if not already root.
          printf "%s\$ %s%s\n" "$DIM" "$*" "$RST" >&2
          if [ "$(id -u)" -eq 0 ]; then
            "$@"
          else
            sudo "$@"
          fi
        }

        confirm() {
          local prompt="''${1:-Proceed?}"
          local ans
          read -r -p "$prompt [y/N] " ans
          [[ "$ans" =~ ^[Yy]$ ]]
        }

        have_zpool() { command -v zpool >/dev/null 2>&1; }

        # ---- pool / drive discovery -------------------------------------------

        # All imported pools, one per line.
        pools() {
          have_zpool || return 0
          zpool list -H -o name 2>/dev/null || true
        }

        # Parse zpool status -P -L into one line per leaf vdev:
        #   <name>\t<state>\t<was_path>
        # where <name> is either /dev/... or a numeric GUID (for slots whose
        # underlying disk has been pulled), <state> is ONLINE / DEGRADED /
        # FAULTED / OFFLINE / UNAVAIL / REMOVED, and <was_path> is the
        # "was /dev/..." annotation zpool appends for missing members (empty
        # otherwise). Container vdevs (raidzN-M, mirror-N, spare-N,
        # replacing-N, logs/cache/spares/dedup/special) are skipped.
        pool_leaf_vdevs() {
          local pool="$1"
          zpool status -P -L "$pool" \
            | awk -v POOL="$pool" '
                /^[[:space:]]*config:/ { in_config = 1; next }
                /^[[:space:]]*errors:/ { in_config = 0 }
                !in_config { next }
                /^\t[[:space:]]*NAME[[:space:]]+STATE/ { next }
                /^\t/ {
                  name = $1; state = $2
                  if (name == POOL) next
                  if (name ~ /^(raidz[0-9]*-[0-9]+|mirror-[0-9]+|spare-[0-9]+|replacing-[0-9]+|logs|cache|spares|dedup|special)$/) next
                  was = ""
                  if (match($0, /[[:space:]]was[[:space:]]+\/[^[:space:]]+/)) {
                    was = substr($0, RSTART, RLENGTH)
                    sub(/^[[:space:]]+was[[:space:]]+/, "", was)
                  }
                  print name "\t" state "\t" was
                }
              '
        }

        # Just the leaf vdev names that look like a /dev path. Used to map
        # physical drives → pool; GUID-only slots have no attached disk so
        # they can never match.
        pool_vdev_paths() {
          pool_leaf_vdevs "$1" | awk -F'\t' '$1 ~ /^\//{print $1}'
        }

        # Top-level vdevs of a pool, one per line:
        #   <name>\t<state>\t<type>      type ∈ raidz | mirror | stripe
        # In zpool status these are indented one level under the pool. Stripe
        # vdevs (single disks at top level) get type=stripe; container vdevs
        # (raidzN-M, mirror-N) get the corresponding type. Aux sections
        # (logs/cache/spares/dedup/special) are skipped.
        pool_top_vdevs() {
          local pool="$1"
          zpool status -P -L "$pool" \
            | awk -v POOL="$pool" '
                /^[[:space:]]*config:/ { in_c = 1; next }
                /^[[:space:]]*errors:/ { in_c = 0 }
                !in_c { next }
                /^\t  [^[:space:]]/ {
                  name = $1; state = $2
                  if (name == POOL) next
                  if (name ~ /^(logs|cache|spares|dedup|special)$/) next
                  if      (name ~ /^raidz[0-9]+-[0-9]+$/) type = "raidz"
                  else if (name ~ /^mirror-[0-9]+$/)      type = "mirror"
                  else                                    type = "stripe"
                  print name "\t" state "\t" type
                }
              '
        }

        # True if this pool's leaf vdev paths include any /dev/mapper/* —
        # i.e. drives are LUKS-backed (ssd_pool, ext_pool) rather than the
        # pool using ZFS-native encryption (hdd_pool1).
        pool_uses_luks() {
          pool_vdev_paths "$1" | grep -q '^/dev/mapper/'
        }

        # When expanding a LUKS-backed pool, pick the next mapper name in
        # the existing naming sequence (ssd_pool1..ssd_pool4 → ssd_pool5).
        # Falls back to <pool>_new if no number is found.
        next_luks_mapper_name() {
          local pool="$1" max=0 base="" p mapname num
          while read -r p; do
            mapname="''${p##*/}"
            if [[ "$mapname" =~ ^(.+[^0-9])([0-9]+)$ ]]; then
              base="''${BASH_REMATCH[1]}"
              num="''${BASH_REMATCH[2]}"
              ((num > max)) && max=$num
            fi
          done < <(pool_vdev_paths "$pool" | grep '^/dev/mapper/')
          if [ -n "$base" ]; then
            echo "''${base}$((max + 1))"
          else
            echo "''${pool}_new"
          fi
        }

        # If $1 is /dev/mapper/X or /dev/dm-Y, print the underlying block
        # device by reading /sys/block/dm-N/slaves/ (the kernel's record of
        # the dm target's backing devices). Otherwise echo $1.
        #
        # Earlier this used `cryptsetup status`, which (a) isn't on the
        # unprivileged PATH on NixOS and (b) only works for the
        # /dev/mapper/<name> form — ZFS often records vdevs by the
        # /dev/dm-N alias instead. Reading the sysfs slaves works for any
        # dm target (LUKS, LVM, dm-crypt) and needs no extra tools.
        resolve_physical() {
          local dev="$1" name slave
          case "$dev" in
            /dev/mapper/*|/dev/dm-*)
              # /dev/mapper/X is typically a symlink to ../dm-N; resolve it
              # so we always look up by the dm-N kernel name.
              name=$(readlink -f "$dev" 2>/dev/null || echo "$dev")
              name="''${name##*/}"
              if [ -d "/sys/block/$name/slaves" ]; then
                slave=$(find "/sys/block/$name/slaves" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | head -n1)
                if [ -n "$slave" ]; then
                  echo "/dev/$slave"
                  return
                fi
              fi
              echo "$dev"
              ;;
            *)
              echo "$dev"
              ;;
          esac
        }

        # All physical disks (lsblk type=disk), one path per line.
        # Excludes virtual block devices (zram, loop, md, dm-*) and optical
        # (sr*) that lsblk also tags as "disk".
        all_disks() {
          lsblk -dn -o NAME,TYPE | awk '
            $2 != "disk" { next }
            $1 ~ /^(zram|loop|sr|md|dm-)/ { next }
            { print "/dev/" $1 }
          '
        }

        # /dev/sdb1 → /dev/sdb, /dev/nvme0n1p1 → /dev/nvme0n1, /dev/sdb → /dev/sdb.
        # Uses lsblk PKNAME so the parent-disk math survives weird naming
        # (nvme, mmcblk, loop) instead of hand-rolling regex.
        parent_disk() {
          local p="$1" parent
          parent=$(lsblk -no PKNAME "$p" 2>/dev/null | head -n1)
          if [ -n "$parent" ]; then
            echo "/dev/$parent"
          else
            echo "$p"
          fi
        }

        # True if any partition of this drive is currently mounted (i.e.
        # the OS lives on it). Catches /dev/sda1 → /, /dev/nvme0n1p2 → /boot.
        drive_has_mounted_partition() {
          local dev="$1" base="''${1##*/}"
          awk -v re="^/dev/''${base}p?[0-9]+$" '
            $1 ~ re { found=1; exit }
            END { exit !found }
          ' /proc/mounts
        }

        # Drives not in any ZFS pool and not hosting the OS — the set of
        # drives we could 'absorb' into a pool.
        unassigned_drives() {
          local d
          while read -r d; do
            [ -n "$(drive_pool_assignment "$d")" ] && continue
            drive_has_mounted_partition "$d" && continue
            echo "$d"
          done < <(all_disks)
        }

        # Pretty one-line description of a drive: SIZE  MODEL  SERIAL.
        drive_oneline() {
          local dev="$1" line
          line=$(lsblk -dn -o SIZE,MODEL,SERIAL "$dev" 2>/dev/null \
            | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]\+$//' -e 's/[[:space:]]\+/  /g')
          printf "%s" "$line"
        }

        # Map physical-path → which pool uses it (via LUKS or direct).
        # Vdev paths are commonly partitions (/dev/sdg1) or LUKS mappers
        # whose underlying device is a partition (/dev/mapper/ssd_pool1 →
        # /dev/sda1). Compare at the parent-disk level so /dev/sda matches
        # /dev/sda1.
        drive_pool_assignment() {
          local target="$1" pool dev phys
          target=$(parent_disk "$(readlink -f "$target")")
          for pool in $(pools); do
            while read -r dev; do
              phys=$(resolve_physical "$dev")
              phys=$(parent_disk "$(readlink -f "$phys")")
              if [ "$phys" = "$target" ]; then
                echo "$pool"
                return 0
              fi
            done < <(pool_vdev_paths "$pool")
          done
          # Falling off the end means "no match" — that's a normal answer
          # (the drive isn't in any pool), not a failure. Return success
          # explicitly so callers don't trip set -e on the empty result.
          return 0
        }

        # ---- subcommands ------------------------------------------------------

        cmd_help() {
          cat <<EOF
    ''${BOLD}disk''${RST} — drive health, SMART self-tests, and pool drive replacement.

    Usage: disk <command> [args]

      ''${CYAN}pools''${RST}                List ZFS pools with health summary
      ''${CYAN}drives''${RST}               Physical drives: model, serial, pool, SMART verdict
      ''${CYAN}health''${RST} [DEV]         SMART overall health for one drive (or all)
      ''${CYAN}test''${RST} DEV [long]      Start the drive's firmware self-test
                           (default ''${BOLD}short''${RST} ~2 min; ''${BOLD}long''${RST} hours, full surface scan)
      ''${CYAN}report''${RST} DEV           Show the drive's last firmware self-test result
      ''${CYAN}free''${RST}                 Show drives that aren't in any pool — ready to absorb
      ''${CYAN}replace''${RST}              Interactive walkthrough: absorb a new drive into a
                           pool. If the pool has a failed/removed slot, fills it
                           via ''${BOLD}zpool replace''${RST}. If the pool is healthy, offers to
                           expand a vdev via ''${BOLD}zpool attach''${RST} (raidz expansion / new
                           mirror copy). Prints the crypttab line to paste into
                           hardware-configuration.nix when LUKS is involved.
                           Aliases: absorb, attach, expand.
      ''${CYAN}memtest''${RST}              How to RAM-test this host

    DEV can be /dev/sdX, /dev/nvmeXn1, or a /dev/disk/by-id/* path.

    ''${DIM}Self-test reports live in the drive's SMART log persistently — run a long
    test before trusting a refurbished disk, then check the report.''${RST}
    EOF
        }

        cmd_pools() {
          if ! have_zpool; then
            echo "disk: zpool not found (host doesn't run ZFS?)" >&2
            return 1
          fi
          local p
          for p in $(pools); do
            echo "''${BOLD}''${CYAN}== $p ==''${RST}"
            zpool status -v "$p"
            echo
          done
        }

        cmd_drives() {
          printf "''${BOLD}%-12s %-8s %-22s %-20s %-12s %-8s''${RST}\n" \
            DEVICE SIZE MODEL SERIAL POOL SMART
          local dev info size model serial pool smart smart_color
          while read -r dev; do
            info=$(lsblk -dn -o SIZE,MODEL,SERIAL,ROTA "$dev" 2>/dev/null) || continue
            size=$(echo "$info" | awk '{print $1}')
            # MODEL and SERIAL can be empty; pad fields.
            model=$(lsblk -dn -o MODEL "$dev"   2>/dev/null | tr -s ' ' | sed 's/ *$//')
            serial=$(lsblk -dn -o SERIAL "$dev" 2>/dev/null | tr -s ' ' | sed 's/ *$//')
            [ -z "$model" ]  && model="-"
            [ -z "$serial" ] && serial="-"
            pool=$(drive_pool_assignment "$dev")
            [ -z "$pool" ] && pool="-"
            # SMART overall health: PASSED / FAILED / unsupported. smartctl
            # encodes status in its exit-code bits, so non-zero is normal —
            # plus the call needs root, which silently fails without a TTY
            # for sudo. pipefail + set -e would abort the loop without the
            # `|| true` here.
            smart=$(sudo_cmd smartctl -H "$dev" 2>/dev/null \
              | awk -F: '/overall-health|SMART Health Status/ {gsub(/^ */,"",$2); print $2; exit}') || true
            [ -z "$smart" ] && smart="n/a"
            case "$smart" in
              PASSED|OK) smart_color="$GREEN" ;;
              FAILED*)   smart_color="$RED"   ;;
              *)         smart_color="$YELLOW";;
            esac
            printf "%-12s %-8s %-22.22s %-20.20s %-12s ''${smart_color}%-8s''${RST}\n" \
              "$dev" "$size" "$model" "$serial" "$pool" "$smart"
          done < <(all_disks)
        }

        cmd_health() {
          local dev="''${1:-}"
          if [ -n "$dev" ]; then
            sudo_cmd smartctl -H -i "$dev"
            return $?
          fi
          local d
          while read -r d; do
            echo "''${BOLD}''${CYAN}== $d ==''${RST}"
            sudo_cmd smartctl -H -i "$d" || true
            echo
          done < <(all_disks)
        }

        cmd_test() {
          local dev="''${1:-}" kind="''${2:-short}"
          if [ -z "$dev" ]; then
            echo "usage: disk test <device> [short|long]" >&2
            return 2
          fi
          case "$kind" in short|long) ;; *)
            echo "disk test: kind must be 'short' or 'long', got '$kind'" >&2
            return 2 ;;
          esac
          echo "Starting $kind firmware self-test on $dev."
          echo "The drive runs this itself; you can unmount/eject afterwards"
          echo "or leave it; the report persists in the drive's SMART log."
          sudo_cmd smartctl -t "$kind" "$dev"
          echo
          echo "Track progress:  ''${BOLD}disk report $dev''${RST}"
          echo "Or:              ''${BOLD}sudo smartctl -c $dev''${RST}  (estimated time remaining)"
        }

        cmd_report() {
          local dev="''${1:-}"
          if [ -z "$dev" ]; then
            echo "usage: disk report <device>" >&2
            return 2
          fi
          sudo_cmd smartctl -l selftest "$dev"
          echo
          echo "''${DIM}Tip: ''${BOLD}sudo smartctl -a $dev''${RST}''${DIM} shows full SMART attributes.''${RST}"
        }

        cmd_free() {
          local candidates=()
          mapfile -t candidates < <(unassigned_drives)
          if [ ''${#candidates[@]} -eq 0 ]; then
            echo "No absorbable drives."
            echo "  Every attached drive is either in a pool or hosting the OS."
            echo "  Plug in the replacement and re-run, or check ''${BOLD}disk drives''${RST}."
            return 0
          fi
          echo "''${BOLD}Drives not in any pool, no mounted partitions:''${RST}"
          local i d
          for i in "''${!candidates[@]}"; do
            d="''${candidates[$i]}"
            printf "  %d) %-10s  ''${DIM}%s''${RST}\n" $((i+1)) "$d" "$(drive_oneline "$d")"
          done
          echo
          echo "''${DIM}Next: ''${BOLD}disk replace''${RST}''${DIM} to absorb one into a pool's empty slot.''${RST}"
        }

        cmd_memtest() {
          cat <<EOF
    ''${BOLD}Memory testing — two paths.''${RST}

    ''${CYAN}1. Userspace (runtime), fastest to start:''${RST}
       ''${BOLD}sudo memtester <SIZE> [iterations]''${RST}
       e.g. ''${BOLD}sudo memtester 64G 1''${RST}  (allocate 64 GiB, run all patterns once)

       Quirks:
         - Can only test what it can mlock(); leave headroom for the OS.
         - Won't catch errors masked by ECC scrubbing — for that, use option 2.
         - Tail logs: ''${BOLD}journalctl -k --since "1 hour ago" | grep -iE "edac|mce"''${RST}

    ''${CYAN}2. Bootable (offline), most thorough:''${RST}
       memtest86+ as a systemd-boot menu entry — opt-in on NixOS. Add to
       configuration.nix and ''${BOLD}rebuild''${RST}:
         ''${DIM}boot.loader.systemd-boot.memtest86.enable = true;''${RST}
       Then reboot, pick "Memtest86+" from the boot menu, let it cycle for
       several passes (overnight is good).

    ''${CYAN}3. EDAC / ECC counters (passive, always-on):''${RST}
       ''${BOLD}sudo edac-util -v''${RST} or ''${BOLD}journalctl -k | grep -i edac''${RST}
       Persistent uncorrectable counts means your DIMMs are dying *now*.
    EOF
        }

        # ---- interactive absorb (replace failed slot OR expand healthy vdev) ----

        cmd_replace() {
          if ! have_zpool; then
            echo "disk: zpool not found" >&2
            return 1
          fi

          # 1. Pick pool.
          local pool_choices
          mapfile -t pool_choices < <(pools)
          if [ ''${#pool_choices[@]} -eq 0 ]; then
            echo "disk: no imported pools" >&2
            return 1
          fi
          echo "''${BOLD}Pools on this host:''${RST}"
          local i
          for i in "''${!pool_choices[@]}"; do
            local p="''${pool_choices[$i]}"
            local pstate
            pstate=$(zpool list -H -o health "$p" 2>/dev/null)
            printf "  %d) %s  ''${DIM}[%s]''${RST}\n" $((i+1)) "$p" "$pstate"
          done
          local pick pool
          read -r -p "Pick pool # to operate on: " pick
          pool="''${pool_choices[$((pick-1))]:-}"
          if [ -z "$pool" ]; then
            echo "no pool selected" >&2
            return 1
          fi

          echo
          echo "''${BOLD}''${CYAN}Current status of $pool:''${RST}"
          zpool status -L -P "$pool"
          echo

          # 2. Decide mode. If there's a failed/missing leaf, we 'replace'
          #    it (fills an empty slot in a redundant vdev). If the pool is
          #    healthy, we 'attach' (raidz expansion / new mirror member /
          #    promote stripe to mirror). Both branches converge below on
          #    the same drive-picker, self-test, LUKS, and execute steps.
          local zfs_op="" zfs_target="" target_type=""
          local old_state="" old_was=""
          local is_luks="no" new_mapper="" old_mapper=""

          local failed_lines
          failed_lines=$(pool_leaf_vdevs "$pool" \
            | awk -F'\t' '$2 ~ /^(UNAVAIL|FAULTED|OFFLINE|REMOVED|DEGRADED)$/')

          if [ -n "$failed_lines" ]; then
            # ---- replace mode ----
            echo "''${YELLOW}Failing/missing slots in $pool:''${RST}"
            local n_failed=0
            while IFS=$'\t' read -r fname fstate fwas; do
              n_failed=$((n_failed+1))
              if [ -n "$fwas" ]; then
                printf "  %d) %s  ''${DIM}[%s, was %s]''${RST}\n" "$n_failed" "$fname" "$fstate" "$fwas"
              else
                printf "  %d) %s  ''${DIM}[%s]''${RST}\n" "$n_failed" "$fname" "$fstate"
              fi
            done <<< "$failed_lines"

            if [ "$n_failed" -eq 1 ]; then
              IFS=$'\t' read -r zfs_target old_state old_was <<< "$failed_lines"
              read -r -p "Fill slot ''${BOLD}$zfs_target''${RST} [$old_state]? [Y/n] " ans
              [[ "$ans" =~ ^[Nn]$ ]] && zfs_target=""
            else
              read -r -p "Pick slot # to fill: " pick
              zfs_target=$(echo "$failed_lines" | awk -F'\t' -v n="$pick" 'NR==n{print $1}')
              old_state=$(echo "$failed_lines" | awk -F'\t' -v n="$pick" 'NR==n{print $2}')
              old_was=$(echo "$failed_lines"   | awk -F'\t' -v n="$pick" 'NR==n{print $3}')
            fi
            [ -z "$zfs_target" ] && { echo "nothing to replace"; return 1; }
            zfs_op="replace"

            if [ "$old_state" = "REMOVED" ] || [ "$old_state" = "UNAVAIL" ]; then
              echo
              echo "''${DIM}Slot $zfs_target is $old_state — ZFS is tracking an empty position''${RST}"
              echo "''${DIM}in the redundant vdev (the disk you pulled). 'zpool replace' fills''${RST}"
              echo "''${DIM}that exact position; this is not 'zpool add'.''${RST}"
              [ -n "$old_was" ] && echo "''${DIM}Original path: $old_was''${RST}"
            fi

            # LUKS hint from current slot or "was" path.
            local luks_hint="$zfs_target"
            case "$zfs_target" in /dev/mapper/*|/dev/dm-*) luks_hint="$zfs_target" ;; *)
              [ -n "$old_was" ] && luks_hint="$old_was" ;;
            esac
            case "$luks_hint" in
              /dev/mapper/*|/dev/dm-*)
                is_luks="yes"
                old_mapper="''${luks_hint##*/}"
                new_mapper="''${old_mapper}_new"
                ;;
            esac

          else
            # ---- attach / expand mode ----
            echo "''${GREEN}$pool has no failed or missing vdev slots.''${RST}"
            echo
            echo "If you want to ''${BOLD}expand''${RST} the pool by attaching a new drive to an"
            echo "existing vdev (raidz expansion or a new mirror copy), pick one"
            echo "below. To extend the pool with a brand-new top-level vdev instead"
            echo "(''${BOLD}zpool add''${RST}), do that by hand — it's irreversible and the topology"
            echo "design isn't something this tool will choose for you."
            echo
            echo "''${BOLD}Top-level vdevs in $pool:''${RST}"
            local top_lines top_count=0
            top_lines=$(pool_top_vdevs "$pool")
            if [ -z "$top_lines" ]; then
              echo "  (no top-level vdevs found — unexpected)" >&2
              return 1
            fi
            while IFS=$'\t' read -r tname tstate ttype; do
              top_count=$((top_count+1))
              printf "  %d) %-16s ''${DIM}[%s, type=%s]''${RST}\n" "$top_count" "$tname" "$tstate" "$ttype"
            done <<< "$top_lines"

            read -r -p "Pick # to attach to (Enter to cancel): " pick
            [ -z "$pick" ] && return 0
            zfs_target=$(echo "$top_lines"  | awk -F'\t' -v n="$pick" 'NR==n{print $1}')
            target_type=$(echo "$top_lines" | awk -F'\t' -v n="$pick" 'NR==n{print $3}')
            if [ -z "$zfs_target" ]; then
              echo "no vdev selected" >&2
              return 1
            fi
            zfs_op="attach"

            echo
            case "$target_type" in
              raidz)
                echo "''${BOLD}''${CYAN}Plan: raidz expansion''${RST}"
                echo "  Adds a disk to $zfs_target, growing it from N-wide to (N+1)-wide."
                echo "  Requires OpenZFS 2.3+. ZFS rewrites parity in the background — no"
                echo "  downtime. Capacity grows after expansion completes (can take days"
                echo "  for large pools)."
                ;;
              mirror)
                echo "''${BOLD}''${CYAN}Plan: add a mirror member to $zfs_target''${RST}"
                echo "  ZFS resilvers the new drive from existing copies."
                ;;
              stripe)
                echo "''${BOLD}''${CYAN}Plan: promote stripe vdev $zfs_target to a 2-way mirror''${RST}"
                echo "  $zfs_target is a single-disk top-level vdev (no redundancy)."
                echo "  Attaching turns it into a mirror, resilvered from the existing copy."
                ;;
            esac

            if pool_uses_luks "$pool"; then
              is_luks="yes"
              new_mapper=$(next_luks_mapper_name "$pool")
            fi
          fi

          echo "''${DIM}LUKS-backed: $is_luks''${RST}"
          [ "$is_luks" = "yes" ] && echo "''${DIM}  new mapper name: $new_mapper''${RST}"

          # 3. Pick the new physical drive — shared by both modes.
          echo
          echo "''${BOLD}Drives available to absorb (not in any pool, no mounted partitions):''${RST}"
          local candidates=() d
          mapfile -t candidates < <(unassigned_drives)
          if [ ''${#candidates[@]} -eq 0 ]; then
            echo "  ''${YELLOW}(none found — every attached drive is already in a pool or hosts the OS)''${RST}"
            echo
            echo "  Plug the new drive in (or check ''${BOLD}disk drives''${RST} for current state)."
            echo "  You can also paste a /dev path manually below."
          else
            local i
            for i in "''${!candidates[@]}"; do
              d="''${candidates[$i]}"
              printf "  %d) %-10s  ''${DIM}%s''${RST}\n" $((i+1)) "$d" "$(drive_oneline "$d")"
            done
          fi
          echo
          local new_phys pick_new
          read -r -p "Pick # to absorb, or paste a /dev path: " pick_new
          if [[ "$pick_new" =~ ^[0-9]+$ ]]; then
            new_phys="''${candidates[$((pick_new-1))]:-}"
            if [ -z "$new_phys" ]; then
              echo "disk: no candidate #$pick_new" >&2
              return 1
            fi
          else
            new_phys="$pick_new"
          fi
          if [ ! -b "$new_phys" ]; then
            echo "disk: $new_phys is not a block device" >&2
            return 1
          fi
          local picked_pool
          picked_pool=$(drive_pool_assignment "$new_phys")
          if [ -n "$picked_pool" ]; then
            echo "''${RED}$new_phys is already part of pool $picked_pool — aborting.''${RST}" >&2
            return 1
          fi
          if drive_has_mounted_partition "$new_phys"; then
            echo "''${RED}$new_phys has a mounted partition (likely the OS disk) — aborting.''${RST}" >&2
            return 1
          fi

          # 4. Resolve a stable by-id path for the new drive.
          local new_by_id
          new_by_id=$(
            find /dev/disk/by-id -lname "*$(basename "$new_phys")" \
              -not -name 'wwn-*' -not -name '*-part*' -printf '%p\n' 2>/dev/null \
              | head -n1
          )
          if [ -z "$new_by_id" ]; then
            new_by_id=$(
              find /dev/disk/by-id -lname "*$(basename "$new_phys")" \
                -not -name '*-part*' -printf '%p\n' 2>/dev/null \
                | head -n1
            )
          fi
          if [ -z "$new_by_id" ]; then
            echo "''${YELLOW}warning: no /dev/disk/by-id/ link found for $new_phys.''${RST}"
            echo "ZFS strongly prefers by-id paths so vdev identity survives sd-letter shuffling."
            read -r -p "Continue with the unstable $new_phys path? [y/N] " ans
            [[ "$ans" =~ ^[Yy]$ ]] || return 1
            new_by_id="$new_phys"
          fi
          echo "''${DIM}New drive stable path: $new_by_id''${RST}"

          # 5. Self-test confirmation — refurbs should pass a long test first.
          echo
          echo "''${YELLOW}Before trusting a refurbished drive in a pool, run a full surface scan:''${RST}"
          echo "  ''${BOLD}disk test $new_by_id long''${RST}   (hours, runs on the drive itself)"
          echo "  ''${BOLD}disk report $new_by_id''${RST}      (check the result later)"
          read -r -p "Have you already done this and verified the drive is healthy? [y/N] " ans
          if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            read -r -p "Kick off a long self-test now and exit? [Y/n] " ans2
            if [[ ! "$ans2" =~ ^[Nn]$ ]]; then
              cmd_test "$new_by_id" long
            fi
            echo "Re-run ''${BOLD}disk replace''${RST} once the drive has passed."
            return 0
          fi

          # 6. LUKS dance (only if pool is LUKS-backed).
          local new_zpool_dev
          if [ "$is_luks" = "yes" ]; then
            echo
            echo "''${BOLD}LUKS plan:''${RST}"
            echo "  1. ''${BOLD}cryptsetup luksFormat''${RST} $new_by_id with /var/lib/secrets/data.key"
            echo "  2. ''${BOLD}cryptsetup open''${RST} it as $new_mapper"
            echo "  3. ''${BOLD}zpool $zfs_op''${RST} $pool $zfs_target /dev/mapper/$new_mapper"
            echo "  4. Edit hardware-configuration.nix crypttab (see hint at end)"
            if ! confirm "Proceed?"; then return 0; fi

            if [ ! -r /var/lib/secrets/data.key ] && ! sudo_cmd test -r /var/lib/secrets/data.key; then
              echo "disk: /var/lib/secrets/data.key not readable; aborting" >&2
              return 1
            fi

            echo "''${RED}This will WIPE $new_by_id (luksFormat).''${RST}"
            if ! confirm "WIPE $new_by_id?"; then return 0; fi
            sudo_cmd cryptsetup luksFormat --key-file /var/lib/secrets/data.key "$new_by_id"
            sudo_cmd cryptsetup open --key-file /var/lib/secrets/data.key "$new_by_id" "$new_mapper"
            new_zpool_dev="/dev/mapper/$new_mapper"
          else
            new_zpool_dev="$new_by_id"
          fi

          # 7. Execute.
          echo
          if ! confirm "Run: zpool $zfs_op $pool $zfs_target $new_zpool_dev ?"; then return 0; fi
          sudo_cmd zpool "$zfs_op" "$pool" "$zfs_target" "$new_zpool_dev"
          echo
          if [ "$zfs_op" = "replace" ]; then
            echo "''${BOLD}''${GREEN}Resilver started.''${RST} Watch with: ''${BOLD}watch -n 5 zpool status $pool''${RST}"
          else
            case "$target_type" in
              raidz)
                echo "''${BOLD}''${GREEN}raidz expansion started.''${RST}"
                echo "Watch with: ''${BOLD}watch -n 10 zpool status $pool''${RST}"
                echo "Expansion runs in the background; can take days on large pools."
                ;;
              *)
                echo "''${BOLD}''${GREEN}Attach + resilver started.''${RST} Watch with: ''${BOLD}watch -n 5 zpool status $pool''${RST}"
                ;;
            esac
          fi

          # 8. Persist to Nix. For LUKS-backed pools the crypttab entry has
          #    to be updated by hand (mapper-name → UUID lives in
          #    hardware-configuration.nix). For pool-level (ZFS-native)
          #    encryption and plain pools, the vdev layout lives entirely
          #    in ZFS labels — no Nix change needed.
          echo
          local host config_path
          host=$(hostname -s 2>/dev/null || uname -n | cut -d. -f1)
          config_path="hosts/$host/hardware-configuration.nix"
          if [ "$is_luks" = "yes" ]; then
            local new_uuid
            new_uuid=$(sudo_cmd cryptsetup luksUUID "$new_by_id" 2>/dev/null)
            echo "''${BOLD}Persist to Nix — edit''${RST} ''${CYAN}$config_path''${RST}''${BOLD}:''${RST}"
            echo "  Inside ''${BOLD}environment.etc.\"crypttab\".text''${RST}, paste:"
            echo
            if [ "$zfs_op" = "replace" ]; then
              echo "  (replacing the existing ''${BOLD}$old_mapper''${RST} line)"
              echo
              printf "    %-18s%-51s%s  %s\n" \
                "$old_mapper" "UUID=$new_uuid" "/var/lib/secrets/data.key" \
                "luks,x-systemd.device-timeout=120"
              echo
              echo "  Then ''${BOLD}rebuild''${RST}. After the resilver finishes and on next boot,"
              echo "  the new drive comes up under $old_mapper via crypttab — the"
              echo "  temporary $new_mapper name won't reappear."
            else
              echo "  (adding a new line for the new mapper)"
              echo
              printf "    %-18s%-51s%s  %s\n" \
                "$new_mapper" "UUID=$new_uuid" "/var/lib/secrets/data.key" \
                "luks,x-systemd.device-timeout=120"
              echo
              echo "  Then ''${BOLD}rebuild''${RST} so $new_mapper opens automatically on boot."
            fi
          else
            echo "''${BOLD}Persist to Nix:''${RST} ''${GREEN}nothing to do.''${RST}"
            echo "  $pool's vdev layout lives in ZFS labels on the disks themselves,"
            echo "  not in $config_path. The new drive will be picked up automatically"
            echo "  on every boot via 'zpool import'."
            case "$pool" in
              hdd_pool*)
                echo "  (Native-encrypted pools like $pool already have their unlock"
                echo "   listed in ''${BOLD}boot.zfs.requestEncryptionCredentials''${RST} — no change there.)"
                ;;
            esac
          fi
        }

        # ---- dispatch ---------------------------------------------------------

        cmd="''${1:-help}"
        shift || true
        case "$cmd" in
          help|-h|--help) cmd_help ;;
          pools)          cmd_pools "$@" ;;
          drives|list)    cmd_drives "$@" ;;
          health)         cmd_health "$@" ;;
          test)           cmd_test "$@" ;;
          report)         cmd_report "$@" ;;
          free|absorbable) cmd_free "$@" ;;
          replace|absorb|attach|expand) cmd_replace "$@" ;;
          memtest|mem)    cmd_memtest "$@" ;;
          *)
            echo "disk: unknown command: $cmd" >&2
            echo "Run 'disk help' for usage." >&2
            exit 2
            ;;
        esac
  '';
}
