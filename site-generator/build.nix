# See: https://wiki.nixos.org/wiki/OCaml

{
  opam-nix,
  lib,
}:
let fileset = lib.fileset; in
let src = fileset.toSource {
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
        ./website-generator.opam
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
in
(opam-nix.lib."${builtins.currentSystem}".buildOpamProject {} "website-generator" src {
  ocaml-base-compiler = "*";
  ocaml-lsp-server = "*";
  ocamlformat = "*";
})