{...}: {
  environment = {
    shellInit = ''
      # include /etc/profile if it exists
      [[ -f /etc/profile ]] && . /etc/profile
    '';
  };
}
