# BEGIN added by setup_fb4a.sh

$env.ANDROID_SDK = "/opt/android_sdk"
$env.ANDROID_NDK_REPOSITORY = "/opt/android_ndk"
$env.ANDROID_HOME = $env.ANDROID_SDK
$env.PATH = ($env.PATH | append [
  ($env.ANDROID_SDK + "/emulator"),
  ($env.ANDROID_SDK + "/tools"),
  ($env.ANDROID_SDK + "/tools/bin"),
  ($env.ANDROID_SDK + "/platform-tools")
])
# END added by setup_fb4a.sh
