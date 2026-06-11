# Why my.ghostty's wrapper alone can't cover darwin: Dock/Spotlight launches
# go through LaunchServices, which execs Ghostty.app's binary directly — PATH
# wrappers (and their baked --config-file) never run. macOS ghostty does read
# two fixed user config paths on every launch, GUI included:
# $XDG_CONFIG_HOME/ghostty/config first, then
# ~/Library/Application Support/com.mitchellh.ghostty/config, later file
# winning on conflicts. Symlinking the Application Support path at the
# wrapper's baked config therefore gives Dock launches the exact config the
# wrapper bakes, with the same precedence as the Linux wrapper: baked settings
# beat ~/.config/ghostty/config, and keys the baked config leaves unset stay
# user-tunable there.
#
# Seed-and-accept: activation re-points the symlink every rebuild so stylix
# re-themes track system generations, but a regular file at that path means
# the user took the dotfile over, and it is left untouched. Accepted caveats:
#   - wrapper-launched terminals load the baked file twice (as a default file
#     and again via --config-file); ghostty's last-wins merge makes the second
#     load a no-op.
#   - config changes need a darwin-rebuild plus ghostty's reload_config (or a
#     new window) — ghostty does not watch its config files.
#   - only the per-user scope (users.users.<n>.my.ghostty) is seeded; a
#     system-scope my.ghostty.enable has no single home directory to seed.
#   - per-user packages get no Spotlight/Launchpad trampoline (mac-app-util
#     only covers environment.systemPackages and home-manager's
#     home.packages), so Ghostty.app is launched from the Dock pin
#     (hosts/*/system/dock.nix points at the ghostty-bin store path).
{
  config,
  lib,
  ...
}: let
  seedUsers =
    lib.filterAttrs (
      _: u: u.my.ghostty.enable && u.home != null
    )
    config.users.users;

  seedFor = name: u: let
    dir = "${u.home}/Library/Application Support/com.mitchellh.ghostty";
    link = "${dir}/config";
    target = u.my.ghostty.finalPackage.configFile;
  in ''
    if [ -L ${lib.escapeShellArg link} ] || [ ! -e ${lib.escapeShellArg link} ]; then
      mkdir -p ${lib.escapeShellArg dir}
      chown ${name} ${lib.escapeShellArg dir}
      ln -sfn ${lib.escapeShellArg target} ${lib.escapeShellArg link}
      chown -h ${name} ${lib.escapeShellArg link}
    else
      echo "my.ghostty: leaving user-owned ${link} in place" >&2
    fi
  '';
in {
  config = lib.mkIf (seedUsers != {}) {
    # nix-darwin activation runs as root (there is no per-user activation
    # phase); the chowns hand the created dir and link back to the user.
    system.activationScripts.extraActivation.text =
      lib.concatStrings (lib.mapAttrsToList seedFor seedUsers);
  };
}
