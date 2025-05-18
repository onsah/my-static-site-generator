{
  system ? builtins.currentSystem,
  sources ? import ../npins,
}:
let
  pkgs = import sources.nixpkgs { inherit system; };
in
pkgs.mkShell {

  inputsFrom = [ (pkgs.callPackage ./build.nix {}) ];

  packages = with pkgs; [
    ocamlPackages.ocaml-lsp
    ocamlPackages.ocamlformat-rpc-lib
    ocamlPackages.utop
  ];
}