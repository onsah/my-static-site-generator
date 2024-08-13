{
  stdenv,
  lib,
  dune_3,
  ocaml,
  ocamlPackages,
}:
# See: https://wiki.nixos.org/wiki/OCaml
let
  fileset = lib.fileset;
in
stdenv.mkDerivation {
  name = "website-generator";
  src = fileset.toSource {
    root = ./.;
    fileset = let
      ocamlFiles  = 
        (fileset.fileFilter
          (file: file.hasExt "ml" || file.hasExt "mli")
          ./bin);
      duneFiles = (fileset.unions [
        ./dune-project
        ./bin/dune
      ]);
    in
    fileset.intersection
      (fileset.gitTracked ../.)
      (fileset.unions [
        ocamlFiles
        duneFiles
        ./Makefile
      ]);
  };

  buildInputs = [
    ocaml
		dune_3
    ocamlPackages.findlib
		ocamlPackages.lambdasoup
		ocamlPackages.omd
		ocamlPackages.yojson
		ocamlPackages.core_unix
  ];

  installPhase = ''
    mkdir -p $out
    mkdir -p $out/bin
    cp _build/default/bin/main.exe $out/bin/website-generator
  '';
}