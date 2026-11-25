# Docker image for a project binary, shared by nix/rust.nix, nix/go.nix and nix/python.nix.
#
#   docker = null | true  -> image with defaults (binaries only)
#            false        -> no image
#            { name, tag, config, copyToRoot, entrypoint }  -> image, overrides merged
#
# Returns { dockerImage = …; } or { } (always { } for libraries: no binary to run).
{
  pkgs,
  bin,
  pname,
  # Executable in ${bin}/bin used as the entrypoint (Python scripts can differ from pname).
  mainProgram ? pname,
  docker,
  library,
}:
let
  opts = {
    name = "ghcr.io/schoderer/${pname}";
    tag = "latest";
    config = { };
    copyToRoot = [ ];
    entrypoint = [ "${bin}/bin/${mainProgram}" ];
  }
  // (if builtins.isAttrs docker then docker else { });
in
pkgs.lib.optionalAttrs (!library && docker != false) {
  dockerImage = pkgs.dockerTools.buildImage {
    inherit (opts) name tag;
    created = "now"; # breaks bit-for-bit reproducibility, but avoids epoch timestamps
    copyToRoot = [ bin ] ++ opts.copyToRoot;
    config = {
      Entrypoint = opts.entrypoint;
      User = "7337:7337"; # do not run as root
      Env = [ ];
    }
    // opts.config;
  };
}
