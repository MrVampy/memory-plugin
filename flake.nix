{
  description = "Typed wiki validator and coding-agent memory plugin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    {
      nixpkgs,
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
        import ./nix/package.nix {
          inherit pkgs;
          sourceRoot = ./.;
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
