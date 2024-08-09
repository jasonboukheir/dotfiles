{ ... }:
{
  system.defaults.finder = {
    _FXShowPosixPathInTitle = true;
    AppleShowAllExtensions = true;
    CreateDesktop = false;
    FXEnableExtensionChangeWarning = false;
    QuitMenuItem = true;
    ShowPathbar = true;
    ShowStatusBar = true;
  };
  system.defaults.CustomUserPreferences = {
    "com.apple.finder" = {
        _FXSortFoldersFirst = true;
        # When performing a search, search the current folder by default
        FXDefaultSearchScope = "SCcf";
    };
  };
}
