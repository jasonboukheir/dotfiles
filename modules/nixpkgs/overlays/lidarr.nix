final: prev: {
  lidarr = prev.lidarr.overrideAttrs (oldAttrs: rec {
    pname = "lidarr-nightly";
    version = "3.1.2.4914";

    src = final.fetchurl {
      url = "https://dev.azure.com/Lidarr/Lidarr/_apis/build/builds/4873/artifacts?artifactName=Packages&fileId=CE73236DB593666413C718979FA61AEB2C3F46760B19AC16C1580919571CB31F02&fileName=Lidarr.develop.${version}.linux-core-x64.tar.gz&api-version=5.1";
      hash = "sha256-BlOnnB311f1DBcOIR8AcrqSZlxV/P9U/GN1TfkHtQFE=";
    };
  });
}
