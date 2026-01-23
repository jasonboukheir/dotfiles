{
  config,
  lib,
  ...
}: let
  RC_MARKER = "# added by setup_fb4a.sh";
  SDK_DIR = "/opt/android_sdk";
  NDK_DIR = "/opt/android_ndk";
in {
  config = lib.mkIf config.programs.fish.enable {
    programs.fish = {
      shellInit = ''
        ${RC_MARKER}
        set -gx ANDROID_SDK ${SDK_DIR}
        set -gx ANDROID_NDK_REPOSITORY ${NDK_DIR}
        set -gx ANDROID_HOME "''$ANDROID_SDK"
        set -gx ANDROID_SDK_ROOT "''$ANDROID_SDK"
        set -gx PATH "''$PATH"':'"''$ANDROID_SDK"'/emulator:'"''$ANDROID_SDK"'/tools:'"''$ANDROID_SDK"'/tools/bin:'"''$ANDROID_SDK"'/platform-tools'
      '';
    };
  };
}
