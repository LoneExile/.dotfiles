# omp (oh-my-pi, https://github.com/can1357/oh-my-pi) from its GitHub release asset, pinned by hash.
#
# The asset is a Bun-compiled executable: Bun appends the JavaScript bundle to the ELF file and
# finds it again by the file's own layout, so nothing may rewrite the file. That rules out strip,
# patchelf and autoPatchelfHook (all off below). The executable's interpreter is
# /lib64/ld-linux-x86-64.so.2, which `programs.nix-ld` provides on the VM (see ../agent-dev.nix).
#
# This pin is the seed and the fallback, not the version the user runs day to day. `omp update` replaces its own file and refuses to
# run from the Nix store (read-only), so Home Manager copies this binary once to ~/.local/bin/omp, a regular file that is the user's
# and comes first on PATH (home/linux/seed-user-binary.sh), and `omp update` on the VM updates that copy. The copy is never replaced
# by a deploy or a reboot, so bumping the pin only changes what a new install (or a VM whose copy was deleted) gets; this store
# package stays on the system PATH as the fallback. To bump the pin, change `version` and `hash` together, then `just vm-deploy <name>`.
# The command below prints the new hash; compare it with the checksum of the release page:
#   nix store prefetch-file --json https://github.com/can1357/oh-my-pi/releases/download/v<version>/omp-linux-x64
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "omp";
  version = "18.8.7";

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
    hash = "sha256-uH+YNaCs27gbu62Cc6otmZtgiiCFmEIalYTP/rMTmoo=";
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
