# omp (oh-my-pi, https://github.com/can1357/oh-my-pi) from its GitHub release asset, pinned by hash.
#
# The asset is a Bun-compiled executable: Bun appends the JavaScript bundle to the ELF file and
# finds it again by the file's own layout, so nothing may rewrite the file. That rules out strip,
# patchelf and autoPatchelfHook (all off below). The executable's interpreter is
# /lib64/ld-linux-x86-64.so.2, which `programs.nix-ld` provides on the VM (see ../agent-dev.nix).
#
# `omp update` cannot work here: it replaces its own binary, and the Nix store is read-only. To
# bump the version, change `version` and `hash` together, then `just vm-deploy <name>`. The
# command below prints the new hash; compare it with the checksum of the release page:
#   nix store prefetch-file --json https://github.com/can1357/oh-my-pi/releases/download/v<version>/omp-linux-x64
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "omp";
  version = "18.8.6";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
    hash = "sha256-h3rNxIOEuA/kwIOx5hBDPSiSLdn8zenqQwqqzodlsZs=";
  };

  dontUnpack = true;
  dontStrip = true;
  dontPatchELF = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/omp
    runHook postInstall
  '';

  meta = {
    description = "omp, the oh-my-pi coding agent (prebuilt Linux x86_64 release)";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = lib.licenses.mit;
    mainProgram = "omp";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
