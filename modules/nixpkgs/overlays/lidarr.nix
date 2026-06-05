final: prev: {
  lidarr = prev.lidarr.overrideAttrs (oldAttrs: rec {
    pname = "lidarr-nightly";
    version = "3.1.3.4968";

    # Lidarr nightlies = `develop` branch; plugin support not yet in stable/master.
    # Track GitHub Releases (durable URL) not Azure DevOps artifact fileIds (rotate).
    # https://wiki.servarr.com/lidarr/plugins
    src = final.fetchurl {
      url = "https://github.com/Lidarr/Lidarr/releases/download/v${version}/Lidarr.develop.${version}.linux-core-x64.tar.gz";
      hash = "sha256-jhTloumon3y3ooFDSnSE0bljL8UvLMBrsDpRAnFN3dE=";
    };
  });
}
