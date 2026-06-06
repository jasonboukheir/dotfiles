{...}: {
  # pam_kwallet5 (wired via security.pam ... enableKwallet) unlocks the
  # login-keyed wallet named "kdewallet" at greeter login. The interactively
  # created wallet was named "Default" with its own passphrase, so the
  # pam-unlocked wallet and the wallet apps open never matched and Brave
  # (via ksecretd / org.freedesktop.secrets) kept prompting. Pin the default
  # to kdewallet and force a single wallet so every secret-service client
  # targets the one pam auto-unlocks. On first login after this lands,
  # pam_kwallet5 seeds kdewallet keyed to the login password.
  xdg.configFile."kwalletrc".text = ''
    [Wallet]
    Enabled=true
    Use One Wallet=true
    Default Wallet=kdewallet
    First Use=false
  '';
}
