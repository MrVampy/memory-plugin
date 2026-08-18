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
      lib.skills = {
        create = builtins.path {
          path = ./plugins/skills/create;
          name = "memory-create-skill";
        };
        recall = builtins.path {
          path = ./plugins/skills/recall;
          name = "memory-recall-skill";
        };
        maintain = builtins.path {
          path = ./plugins/skills/maintain;
          name = "memory-maintain-skill";
        };
      };

      packages = forAllSystems (system: {
        default = mkValidator system;
        memory-validator = mkValidator system;
      });

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          memory-validator = mkValidator system;
          memory-skills = pkgs.runCommand "memory-skills-check" { } ''
            grep -F '.memory/wiki' ${./plugins/skills/recall/SKILL.md} >/dev/null
            grep -F '.memory/wiki' ${./plugins/skills/create/SKILL.md} >/dev/null
            grep -F '"schema_id": "memory-entry-mutation-request"' ${./plugins/skills/create/SKILL.md} >/dev/null
            grep -F 'memory-entry-mutation-result' ${./plugins/skills/create/SKILL.md} >/dev/null
            ! grep -R -F '$NAMESPACE/fs/memory' ${./plugins/skills/recall} ${./plugins/skills/create}
            ! grep -R -F 'r9p rpc memory/ctl/entries' ${./plugins/skills/create}
            ! grep -R -E 'memory-entry-mutation-(request|result)\.v[0-9]+' ${./plugins/skills/create}
            touch "$out"
          '';
        }
      );

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
