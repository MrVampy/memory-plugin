{
  pkgs,
  sourceRoot,
}:

let
  lib = pkgs.lib;
  manifest = builtins.fromTOML (builtins.readFile (sourceRoot + "/manifest.toml"));
  hexPackages = builtins.filter (package: package.source == "hex") manifest.packages;
  fetchedPackages = map (package: {
    name = package.name;
    path = pkgs.fetchHex {
      pkg = package.name;
      inherit (package) version;
      sha256 = package.outer_checksum;
    };
  }) hexPackages;
  packageVersions = builtins.listToAttrs (
    map (package: {
      name = package.name;
      value = package.version;
    }) hexPackages
  );
  packagesToml = (pkgs.formats.toml { }).generate "memory-gleam-packages.toml" {
    packages = packageVersions;
  };
  packageWorkspace = pkgs.linkFarm "memory-gleam-packages" (
    fetchedPackages
    ++ [
      {
        name = "packages.toml";
        path = packagesToml;
      }
    ]
  );
  source = lib.fileset.toSource {
    root = sourceRoot;
    fileset = lib.fileset.unions [
      (sourceRoot + "/gleam.toml")
      (sourceRoot + "/manifest.toml")
      (sourceRoot + "/src")
      (sourceRoot + "/test")
    ];
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "memory-validator";
  version = "0.1.0";
  src = source;
  strictDeps = true;
  doCheck = true;
  nativeBuildInputs = [
    pkgs.gleam
    pkgs.gnutar
    pkgs.gzip
    pkgs.makeWrapper
    pkgs.nodejs
    pkgs.shellcheck
  ];
  MEMORY_GLEAM_PACKAGES = packageWorkspace;
  MEMORY_MAIN = ./main.mjs;
  MEMORY_NODE = "${pkgs.nodejs}/bin/node";
  MEMORY_JS_YAML_TARBALL = pkgs.fetchurl {
    url = "https://registry.npmjs.org/js-yaml/-/js-yaml-4.1.1.tgz";
    hash = "sha512-qQKT4zQxXl8lLwBtHMWwaTcGfFOZviOJet3Oy/xmGk2gZH677CJM9EvtfdSkgWcATZhj/55JZ0rmy3myCT5lsA==";
  };
  MEMORY_ARGPARSE_TARBALL = pkgs.fetchurl {
    url = "https://registry.npmjs.org/argparse/-/argparse-2.0.1.tgz";
    hash = "sha512-8+9WqebbFzpX9OR+Wa6O29asIogeRMzcGtAINdpMHHyAg10f05aSFVBbcEqGf/PXw1EjAZ+q2/bEBg3DvurK3Q==";
  };
  buildPhase = "${./package.sh} build";
  checkPhase = "${./package.sh} check";
  installPhase = "${./package.sh} install";
  meta = with lib; {
    description = "Structural validator for a Memory wiki";
    homepage = "https://github.com/MrVampy/memory-plugin";
    license = licenses.mit;
    mainProgram = "memory";
    platforms = platforms.linux;
  };
}
