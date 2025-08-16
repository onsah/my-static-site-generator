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
    package."ocaml-lsp-server"
    package."ocamlformat"
    # ocamlPackages.ocaml-lsp
    # ocamlPackages.ocamlformat-rpc-lib
    # ocamlPackages.ocamlformat
    # ocamlPackages.utop
  ];
}