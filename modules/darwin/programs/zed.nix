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
    home.activation.symlinkZedCli = ''
      if [ -f "${pkgs.zed-editor}/bin/zeditor" ]; then
        echo '===='
        echo 'Link Zed Editor to usr bin to install CLI'
        echo 'sudo ln -sf "$(which zeditor)" /usr/local/bin/zed'
        echo '===='
      else
        echo "Zed editor not installed, skipping symlink creation"
      fi
    '';
  };
}
