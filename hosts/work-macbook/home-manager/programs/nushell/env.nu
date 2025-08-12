if (ls /usr/libexec/path_helper | where type == 'file' | is-not-empty) {
    let path_helper_output = (/usr/libexec/path_helper -s | lines)
    for line in $path_helper_output {
        let parts = ($line | split row ";")
        let assignment = ($parts | get 0 | str trim)
        if ($assignment | str contains "=") {
            let var = ($assignment | split row "=" | get 0 | str trim)
            let val = ($assignment | split row "=" | get 1 | str trim | str replace -a --regex '^"|"$' '')
            if $var == "PATH" {
                $env.PATH = ($val | split row ":")
            } else if $var == "MANPATH" {
                $env.MANPATH = ($val | split row ":")
            }
        }
    }
}

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
