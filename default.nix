{
  system ? builtins.currentSystem,
  sources ? import ./npins,
}:
let
  pkgs = import sources.nixpkgs { inherit system; };
in
{
  website = pkgs.callPackage ./build.nix {};
  website-generator = pkgs.callPackage ./site-generator/build.nix {  };
}
