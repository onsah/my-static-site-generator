# Assumes, there is a channel called 'nixpkgs', see https://nixos.wiki/wiki/Nix_channels
{ pkgs ? import <nixpkgs> {} }:
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
		ocamlformat
		dune_3
		just
	];
}