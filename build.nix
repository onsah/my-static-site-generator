{
  stdenv,
  lib,
  callPackage,
}:
let
  fileset = lib.fileset;
  website-generator = callPackage ./site-generator/build.nix {  };
in
stdenv.mkDerivation {
  name = "aiono-website";

  src = let
    website-content = ./content;
    makefile = ./Makefile;
  in
  fileset.toSource {
    root = ./.;
    fileset = fileset.intersection
      (fileset.gitTracked ./.)
      (fileset.unions [
        website-content
        makefile
      ]);
  };

  buildInputs = [ website-generator ];

  buildPhase = ''
    ${website-generator}/bin/website-generator --content-path ./content --out-path ./dist
  '';

  installPhase = ''
    mkdir -p $out
    mkdir -p $out/dist
    cp -r ./dist $out/
  '';
}