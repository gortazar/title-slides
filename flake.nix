{
  description = "title-slides — carry the last ## title onto untitled continuation slides in Quarto";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.quarto pkgs.pandoc pkgs.git pkgs.jq ];
          shellHook = ''
            echo "title-slides dev shell — quarto $(quarto --version), pandoc $(pandoc --version | head -1 | cut -d' ' -f2)"
            echo "  tests/run-unit.sh    unit tests over the AST"
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
