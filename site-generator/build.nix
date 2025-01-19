# See: https://wiki.nixos.org/wiki/OCaml

{
  stdenv,
  lib,
  dune_3,
  ocaml,
  ocamlPackages,
}:
let
  fileset = lib.fileset;
in
stdenv.mkDerivation {
  name = "website-generator";
  src = fileset.toSource {
    root = ./.;
    fileset = let
      binFiles  =
        (fileset.fileFilter
          (file: file.hasExt "ml" || file.hasExt "mli")
          ./bin);
      libFiles  =
        (fileset.fileFilter
          (file: file.hasExt "ml" || file.hasExt "mli")
          ./lib);
      duneFiles = (fileset.unions [
        ./dune-project
        ./bin/dune
        ./lib/dune
      ]);
    in
    fileset.intersection
      (fileset.gitTracked ../.)
      (fileset.unions [
        binFiles
        libFiles
        duneFiles
        ./Makefile
      ]);
  };

  buildInputs = [
    ocaml
    dune_3
    ocamlPackages.findlib
    ocamlPackages.lambdasoup
    ocamlPackages.yojson
    ocamlPackages.core_unix
    ocamlPackages.dune-build-info
    ocamlPackages.uunf
    ocamlPackages.uucp
    ocamlPackages.uutf
    ocamlPackages.cmarkit
    ocamlPackages.odoc
    ocamlPackages.ocamlformat
  ];

  installPhase = ''
    mkdir -p $out
    mkdir -p $out/bin
    cp _build/default/bin/main.exe $out/bin/website-generator
  '';
}
