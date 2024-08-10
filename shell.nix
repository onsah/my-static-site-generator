# Assumes, there is a channel called 'nixpkgs', see https://nixos.wiki/wiki/Nix_channels
{ pkgs ? import (builtins.fetchTarball "https://github.com/nixos/nixpkgs/archive/f5129fb42b9c262318130a97b47516946da3e7d7.tar.gz") {} }:
pkgs.mkShell {
	buildInputs = with pkgs; [
		# Package goes there
		# You can search packages via `nix search $term` or from https://search.nixos.org/packages
		ocaml
		ocamlPackages.findlib
		ocamlPackages.ocaml-lsp
		ocamlPackages.ocamlformat-rpc-lib
		ocamlPackages.core
		ocamlPackages.core_unix
		ocamlPackages.omd
		ocamlPackages.lambdasoup
		ocamlPackages.yojson
		ocamlPackages.ounit2
		ocamlPackages.utop
		ocamlformat
		dune_3
		miniserve
		gnumake
	];
	
	shellHook = ''
	  export PROJECT_ROOT=$(pwd);
		export AIONO_WEBSITE_GENERATE_ENV_ENABLED=true;
	'';	
}