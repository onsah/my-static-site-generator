{
  system ? builtins.currentSystem,
  sources ? import ./npins,
}:
let
  pkgs = import sources.nixpkgs { inherit system; };
in
pkgs.mkShell {

  packages = with pkgs; [
    miniserve
    nushell
  ];
}