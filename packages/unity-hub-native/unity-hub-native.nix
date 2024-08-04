{ stdenv, fetchFromGitHub, cmake, libiconv }:
stdenv.mkDerivation {
  pname = "unity-hub-native";
  version = "1.54";

  src = fetchFromGitHub {
    owner = "Ravbug";
    repo = "UnityHubNative";
    rev = "8a1efd9c6b74f5926364bb16d925c26b355ffb5b";
    hash = "sha256-riHdi7qgUQJP5QPZHcQWPUxajmcj5q7Iy6b5t94lrnA=";
  };

  buildInputs = [ cmake libiconv ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  buildPhase = ''
  mkdir build && cd build
  cmake .. $cmakeFlags
  cmake --build . --config Release --target install
  '';

  installPhase = ''
  '';
}
