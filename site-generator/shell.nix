{
  callPackage,
  mkShell,
  ocamlPackages,
  miniserve,
}:

mkShell {

  inputsFrom = [ (callPackage ./build.nix {}) ];

  packages = [
    ocamlPackages.ocaml-lsp
    ocamlPackages.ocamlformat-rpc-lib
    ocamlPackages.utop
    ocamlPackages.ocamlformat
    miniserve
  ];

  shellHook = ''
    export PROJECT_ROOT=$(pwd);
    export AIONO_WEBSITE_GENERATE_ENV_ENABLED=true;
  '';
}