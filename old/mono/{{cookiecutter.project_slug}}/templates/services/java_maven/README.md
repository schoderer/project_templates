# __NAME__

Java HTTP service (JDK `com.sun.net.httpserver`, virtual threads, no runtime
dependencies), built with Maven via nixpkgs `maven.buildMavenPackage`.

| Route               | Response          |
| ------------------- | ----------------- |
| `GET /health`       | `ok`              |
| `GET /hello/{name}` | `Hello, {name}!`  |

The port comes from `PORT` (default `8080`). JVM flags go into
`JDK_JAVA_OPTIONS` (e.g. `-Xmx256m`), which the `java` launcher reads.

## Commands

Inside this folder (standalone flake):

```sh
nix develop                # JDK 25, maven, google-java-format
nix build                  # binary -> result/bin/__NAME__ (runs mvn test)
nix build .#docker         # image  -> result (tar.gz)
nix flake check            # google-java-format, HTTP smoke test, build + tests
```

From the repo root: `nix build .#__NAME__`, `nix build .#__NAME__-docker`, and
`just up` runs it with every other service on `localhost:__PORT__`.

In the dev shell, `mvn package`, `mvn test` and
`java -jar target/__NAME__.jar` work as usual.

## Runtime

The binary is a launcher script running `target/__NAME__.jar` on a minimal
JRE (`jlink`) that holds only the modules listed in `nix/default.nix`
(`java.base`, `java.logging`, `jdk.httpserver`). Unit tests run on the full
JDK, so when new code or a dependency needs another module, the `smoke` check
(which starts the real binary) or the service itself fails with
`NoClassDefFoundError`: add the module there.
`jdeps --print-module-deps --class-path 'target/lib/*' target/__NAME__.jar`
lists what is needed.

## Adding a dependency

1. Add it to `<dependencies>` in `pom.xml`. Runtime dependencies are copied
   to `target/lib/` and put on the jar's classpath.
2. In `nix/default.nix` set `mvnHash = lib.fakeHash;`, run `nix build`, and
   replace it with the hash printed in the error (`got: sha256-...`).
3. Repeat step 2 whenever dependencies or plugins in `pom.xml` change, and
   after `just update` if the build reports a hash mismatch (a new Maven in
   nixpkgs may download differently).

## Files

- `nix/default.nix`: all build logic (binary, image, checks, dev shell)
- `flake.nix`: thin standalone wrapper around `nix/default.nix`
- `pom.xml`: Maven build (plugin versions pinned, warnings are errors)
