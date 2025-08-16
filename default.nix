{
  system ? builtins.currentSystem,
  sources ? import ./npins,
}:
let
  pkgs = import sources.nixpkgs { inherit system; };
  opam-nix = import sources.opam-nix;
in
pkgs.callPackage ./build.nix { inherit opam-nix; }