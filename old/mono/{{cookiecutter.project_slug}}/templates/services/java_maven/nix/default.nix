# Build definition of the __NAME__ service (the project contract, see services/README.md).
#
# Called by ../flake.nix (standalone) and by the root flake (monorepo) with
#   pkgs    nixpkgs for the target system
#   inputs  flake inputs (unused here)
#
# JDK and Maven come from nixpkgs; libraries and Maven plugins come from Maven
# Central, downloaded in a separate fixed-output derivation pinned by `mvnHash`.
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  # Keep in line with <version> in pom.xml.
  version = "0.1.0";

  # Build with the full JDK; run on a jlink'ed runtime holding only the modules
  # the service needs, which keeps the image small. Add modules here when code
  # or a dependency needs them (`jdeps --print-module-deps target/__NAME__.jar`
  # lists them), e.g. java.sql, java.naming, java.net.http, java.management.
  # The `smoke` check below runs the service on this runtime.
  jdk = pkgs.jdk25_headless;
  maven = pkgs.maven.override { jdk_headless = jdk; };
  jre = pkgs.jre25_minimal.override {
    inherit jdk;
    jdkOnBuild = pkgs.buildPackages.jdk25_headless; # provides jlink
    modules = [
      "java.base"
      "java.logging"
      "jdk.httpserver"
    ];
  };

  # Only the files the build needs: editing docs or nix files does not cause a rebuild.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../pom.xml
      ../src
    ];
  };

  bin = maven.buildMavenPackage {
    pname = "__NAME__";
    inherit version src;
    mvnJdk = jdk;

    # Hash of everything Maven downloads (plugins + dependencies). Set when the
    # project was scaffolded; after changing dependencies or plugins in
    # pom.xml, set it to `lib.fakeHash`, run `nix build` and copy the hash
    # from the error message.
    mvnHash = lib.fakeHash;

    # `mvn package` runs the unit tests, so a failing test fails `nix build`.
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/__NAME__
      cp target/__NAME__.jar $out/share/__NAME__/
      if [ -d target/lib ]; then cp -r target/lib $out/share/__NAME__/; fi
      makeWrapper ${lib.getExe' jre "java"} $out/bin/__NAME__ \
        --add-flags "-jar $out/share/__NAME__/__NAME__.jar"
      runHook postInstall
    '';

    meta.mainProgram = "__NAME__";
  };

  docker = pkgs.dockerTools.buildLayeredImage {
    name = "__NAME__";
    tag = bin.version;
    # The image only holds the launcher, the jar and the minimal runtime
    # (which brings its own CA certificates for outgoing TLS).
    config = {
      Cmd = [ (lib.getExe bin) ];
      Env = [ "PORT=8080" ];
      ExposedPorts."8080/tcp" = { };
      User = "65534:65534"; # nobody
      Labels = {
        "org.opencontainers.image.title" = "__NAME__";
        "org.opencontainers.image.version" = bin.version;
      };
    };
  };
in
{
  packages = {
    default = bin;
    inherit docker;
  };

  # Merged into this service's entry of the root compose file (`just up`).
  # The host port was picked by the scaffolder; any compose key works here.
  compose = {
    ports = [ "__PORT__:8080" ];
    # environment.JDK_JAVA_OPTIONS = "-Xmx256m";
    # depends_on = [ "postgres" ];
  };

  # The root flake adds the binary build (which runs mvn test) as <name>-build.
  checks = {
    fmt =
      pkgs.runCommand "__NAME__-java-format"
        {
          nativeBuildInputs = [ pkgs.google-java-format ];
        }
        ''
          find ${src}/src -name '*.java' -print0 |
            xargs -0 google-java-format --dry-run --set-exit-if-changed ||
            { echo "not google-java-format formatted (run: nix fmt)" >&2; exit 1; }
          touch $out
        '';

    # Starts the packaged service (on the minimal runtime) and probes it over
    # HTTP: catches a module missing from `jre` that the unit tests, which run
    # on the full JDK, cannot.
    smoke =
      pkgs.runCommand "__NAME__-smoke"
        {
          nativeBuildInputs = [
            bin
            pkgs.curl
          ];
        }
        ''
          export PORT=18080
          __NAME__ &
          for _ in $(seq 100); do
            curl -sf "http://127.0.0.1:$PORT/health" >/dev/null && break
            sleep 0.1
          done
          [ "$(curl -sf "http://127.0.0.1:$PORT/health")" = ok ]
          [ "$(curl -sf "http://127.0.0.1:$PORT/hello/nix")" = "Hello, nix!" ]
          kill %1
          touch $out
        '';
  };

  devShell = pkgs.mkShell {
    packages = [
      jdk
      maven
      pkgs.google-java-format
    ];
    JAVA_HOME = jdk.home;
  };
}
