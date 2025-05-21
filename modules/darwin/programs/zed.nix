{ pkgs, ... }:
{
  home-manager.users.jasonbk = {
    home.packages = [ pkgs.zed-editor ];
    home.file = {
      ".config/zed" = {
        source = ./zed;
        recursive = true;
      };
    };
    # home.activation.symlinkZedCli = ''
    #   if [ -f "${pkgs.zed-editor}/bin/zeditor" ]; then
    #     echo '===='
    #     echo 'Link Zed Editor to usr bin to install CLI'
    #     echo 'sudo ln -sf "$(which zeditor)" /usr/local/bin/zed'
    #     echo '===='
    #   else
    #     echo "Zed editor not installed, skipping symlink creation"
    #   fi
    # '';
  };

  system.activationScripts.postActivation.text = ''
    if [ -f "${pkgs.zed-editor}/bin/zeditor" ]; then
      echo 'Symlinking Zed Editor (${pkgs.zed-editor}) to /usr/local/bin to install CLI'
      sudo ln -sf "${pkgs.zed-editor}/bin/zeditor" /usr/local/bin/zed
    else
      echo "Zed editor not installed, skipping symlink creation"
    fi
  '';
}
