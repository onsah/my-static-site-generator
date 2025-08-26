{
  system ? builtins.currentSystem,
  sources ? import ../npins,
}:
let
  pkgs = import sources.nixpkgs { inherit system; };
  opam-nix = import sources.opam-nix;
in
let
  package = (pkgs.callPackage ./build.nix { inherit opam-nix; });
in
pkgs.mkShell {

  inputsFrom = [ package.website-generator ];

  packages = [
    package.ocaml-lsp-server
    package.ocamlformat
    package.utop
    package.odoc
  ];
}