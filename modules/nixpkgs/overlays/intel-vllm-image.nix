final: prev: let
  version = "0.17.0";
  tag = "${version}-xpu";
in {
  intel-vllm-image = final.dockerTools.pullImage {
    imageName = "intel/vllm";
    imageDigest = "sha256:e961d08135a6a8ef6decd857c6deab7a70eb00e19de21de54cbc0ce05d9a9f43";
    sha256 = "sha256-DrN+E/Necu01A9zXAlSz0TIxP1GmYTgG6ovHaV7hYJ4=";
    finalImageName = "intel/vllm";
    finalImageTag = tag;
  };
}
