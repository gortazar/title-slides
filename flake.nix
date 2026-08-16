{
  description = "title-slides — carry the last ## title onto untitled continuation slides in Quarto";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Quarto is taken from its own release rather than from nixpkgs, for two reasons.
      # The version is what the extension is tested against, so it belongs pinned here
      # — `quarto-required` in _extension.yml is the other half of that promise. And the
      # release tarball ships the pandoc, deno and dart-sass it expects: nixpkgs
      # currently wires quarto 1.10 to a pandoc too old for it, so `quarto render`
      # there fails on any document at all, extension or no extension.
      quartoVersion = "1.8.27";
      quartoTarballs = {
        x86_64-linux = {
          suffix = "linux-amd64";
          hash = "sha256-vfaJtViXiaHyHYnDuD147QKpeRTdcC5hcpTyzB6nOH0=";
        };
        aarch64-linux = {
          suffix = "linux-arm64";
          hash = "sha256-HyCC6C6XHFsreEJMrJOgkhwAUEVexeqjJTOwIwaCiD4=";
        };
        x86_64-darwin = {
          suffix = "macos";
          hash = "sha256-0p0WPZM+B6pVrgzqG8XOIcvyvStUSVAzb511LroM2h0=";
        };
        aarch64-darwin = {
          suffix = "macos";
          hash = "sha256-0p0WPZM+B6pVrgzqG8XOIcvyvStUSVAzb511LroM2h0=";
        };
      };

      quartoFor = pkgs:
        let
          tarball = quartoTarballs.${pkgs.stdenv.hostPlatform.system};
        in
        pkgs.stdenv.mkDerivation {
          pname = "quarto";
          version = quartoVersion;

          src = pkgs.fetchurl {
            url = "https://github.com/quarto-dev/quarto-cli/releases/download/v${quartoVersion}/quarto-${quartoVersion}-${tarball.suffix}.tar.gz";
            inherit (tarball) hash;
          };

          nativeBuildInputs = [ pkgs.makeWrapper ]
            ++ pkgs.lib.optional pkgs.stdenv.hostPlatform.isLinux pkgs.autoPatchelfHook;
          buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
            pkgs.openssl
          ];

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/libexec" "$out/bin"
            cp -r . "$out/libexec/quarto"
            makeWrapper "$out/libexec/quarto/bin/quarto" "$out/bin/quarto" \
              --set QUARTO_DENO "$out/libexec/quarto/bin/tools/"*"/deno"
            # The tests drive pandoc directly for their Lua helpers. Expose the very
            # pandoc quarto renders with, so the two can never be a version apart.
            ln -s "$out/libexec/quarto/bin/tools/"*"/pandoc" "$out/bin/pandoc"
            runHook postInstall
          '';

          # The bundled binaries are prebuilt for a generic Linux; autoPatchelf sorts out
          # the interpreter and rpath, and there is nothing to strip or check beyond that.
          dontStrip = true;
          dontPatchELF = false;
        };
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ (quartoFor pkgs) pkgs.git pkgs.jq ];
          shellHook = ''
            echo "title-slides dev shell — quarto $(quarto --version), pandoc $(pandoc --version | head -1 | cut -d' ' -f2)"
            echo "  tests/run-unit.sh    unit tests over the AST"
            echo "  tests/run-golden.sh  filtered deck vs. the hand-written one"
            echo "  tests/run-smoke.sh   render example/deck.qmd and check the slides"
          '';
        };
      });

      checks = forAllSystems (pkgs: {
        # The unit tests are pure: pandoc, a few Lua files, no network and no rendering.
        unit = pkgs.runCommand "title-slides-unit"
          {
            src = self;
            nativeBuildInputs = [ pkgs.pandoc pkgs.bash ];
          } ''
          cp -r "$src" source && chmod -R u+w source
          cd source
          bash tests/run-unit.sh
          touch "$out"
        '';

        # The golden and smoke tests drive a real `quarto render`, so they need quarto and
        # a writable home for the caches it insists on.
        render = pkgs.runCommand "title-slides-render"
          {
            src = self;
            # quarto probes for R with `which`, which the build sandbox does not have.
            nativeBuildInputs = [ (quartoFor pkgs) pkgs.bash pkgs.diffutils pkgs.which ];
          } ''
          cp -r "$src" source && chmod -R u+w source
          cd source
          export HOME="$TMPDIR/home"
          export XDG_CACHE_HOME="$TMPDIR/cache"
          export XDG_DATA_HOME="$TMPDIR/data"
          mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
          bash tests/run-golden.sh
          bash tests/run-smoke.sh
          touch "$out"
        '';
      });

      # The release artefact: the extension exactly as `quarto add` installs it.
      packages = forAllSystems (pkgs: {
        default = pkgs.runCommand "title-slides-extension" { src = self; } ''
          mkdir -p "$out"
          cp -r "$src/_extensions" "$out/_extensions"
        '';
      });
    };
}
