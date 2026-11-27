# heygen, HeyGen's command-line tool (https://developers.heygen.com/cli), from its Linux release archive, pinned by hash.
#
# HyperFrames' media-use runs it for HeyGen's catalog of music, images and icons, with the key that HyperFrames saved (it needs no
# sign-in of its own). The archive holds one statically linked Go program (no interpreter, so not even nix-ld is needed), with
# LICENSE (Apache 2.0) and README.md beside it. Nothing strips or patches it: the file stays byte for byte the release's.
#
# Like omp (omp.nix), this pin is the seed and the fallback, not the version the user runs day to day. `heygen update` replaces its own
# file, which it cannot do in the Nix store (read-only), so Home Manager copies this binary once to ~/.local/bin/heygen, a regular file
# that is the user's and comes first on PATH (home/linux/seed-user-binary.sh), and never replaces that copy. Bumping the pin only
# changes what a new install (or a VM whose copy was deleted) gets. To bump it, change `version` and `hash` together, then
# `just vm-deploy <name>`. The command below prints the new hash; compare it, as hex, with the release's checksums.txt (same folder):
#   nix store prefetch-file --json https://static.heygen.ai/cli/releases/v<version>/heygen_v<version>_linux_amd64.tar.gz
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "heygen";
  version = "0.13.0";

  src = fetchurl {
    url = "https://static.heygen.ai/cli/releases/v${version}/heygen_v${version}_linux_amd64.tar.gz";
    # checksums.txt of the release: 38b8e74f514dca2633f5c45cc180e42483a6105216d7abbe4cdf3e15a76b1016
    hash = "sha256-OLjnT1FNyiYz9cRcwYDkJIOmEFIW16u+TN8+FadrEBY=";
  };

  # The archive has no top-level directory.
  sourceRoot = ".";
  dontStrip = true;
  dontPatchELF = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 heygen $out/bin/heygen
    runHook postInstall
  '';

  meta = {
    description = "heygen, HeyGen's command-line tool (prebuilt Linux x86_64 release)";
    homepage = "https://developers.heygen.com/cli";
    license = lib.licenses.asl20;
    mainProgram = "heygen";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
