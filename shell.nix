{
  system ? builtins.currentSystem,
  sources ? import ./npins,
}:
let
  pkgs = import sources.nixpkgs { inherit system; };
  website-generator-shell = pkgs.callPackage ./site-generator/shell-template.nix {};
in
website-generator-shell