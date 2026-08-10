{
  description = "Typed wiki validator and coding-agent memory plugin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-gleam = {
      url = "github:arnarg/nix-gleam";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nix-gleam,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = function: nixpkgs.lib.genAttrs systems function;
      mkValidator =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        nix-gleam.packages.${system}.buildGleamApplication {
          src = ./.;
          target = "javascript";
          doCheck = true;
          nativeBuildInputs = [
            pkgs.gnutar
            pkgs.gzip
            pkgs.shellcheck
          ];
          MEMORY_JS_YAML_TARBALL = pkgs.fetchurl {
            url = "https://registry.npmjs.org/js-yaml/-/js-yaml-4.1.1.tgz";
            hash = "sha512-qQKT4zQxXl8lLwBtHMWwaTcGfFOZviOJet3Oy/xmGk2gZH677CJM9EvtfdSkgWcATZhj/55JZ0rmy3myCT5lsA==";
          };
          MEMORY_ARGPARSE_TARBALL = pkgs.fetchurl {
            url = "https://registry.npmjs.org/argparse/-/argparse-2.0.1.tgz";
            hash = "sha512-8+9WqebbFzpX9OR+Wa6O29asIogeRMzcGtAINdpMHHyAg10f05aSFVBbcEqGf/PXw1EjAZ+q2/bEBg3DvurK3Q==";
          };
          postConfigure = "${./nix/package.sh} prepare";
          preCheck = "${./nix/package.sh} check";
          postInstall = "${./nix/package.sh} install";
        };
    in
    {
      packages = forAllSystems (system: {
        default = mkValidator system;
        memory-validator = mkValidator system;
      });

      checks = forAllSystems (system: {
        memory-validator = mkValidator system;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.gleam
              pkgs.nodejs
              pkgs.shellcheck
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
