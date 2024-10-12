{
  callPackage,
  mkShell,
  ocamlPackages,
  miniserve,
  nushell,
}:

mkShell {

  inputsFrom = [ (callPackage ./build.nix {}) ];

  packages = [
    ocamlPackages.ocaml-lsp
    ocamlPackages.ocamlformat-rpc-lib
    ocamlPackages.utop
    ocamlPackages.ocamlformat
    miniserve
    nushell
  ];

  shellHook = ''
    export PROJECT_ROOT=$(pwd);
    export AIONO_WEBSITE_GENERATE_ENV_ENABLED=true;
  '';
}
