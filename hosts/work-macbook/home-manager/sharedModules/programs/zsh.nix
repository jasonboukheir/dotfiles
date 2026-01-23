{
  config,
  lib,
  ...
}: let
  RC_MARKER = "# added by setup_fb4a.sh";
  SDK_DIR = "/opt/android_sdk";
  NDK_DIR = "/opt/android_ndk";
in {
  config = lib.mkIf config.programs.zsh.enable {
    programs.zsh = {
      initContent = ''
        ${RC_MARKER}
        export ANDROID_SDK=${SDK_DIR}
        export ANDROID_NDK_REPOSITORY=${NDK_DIR}
        export ANDROID_HOME=''${ANDROID_SDK}
        export ANDROID_SDK_ROOT = ''${ANDROID_SDK}
        export PATH=''${PATH}:''${ANDROID_SDK}/emulator:''${ANDROID_SDK}/tools:''${ANDROID_SDK}/tools/bin:''${ANDROID_SDK}/platform-tools
      '';
    };
  };
}
