# See: https://wiki.nixos.org/wiki/OCaml

{
  opam-nix,
}:
(opam-nix.lib."${builtins.currentSystem}".buildOpamProject {} "website-generator" ./. {
  ocaml-base-compiler = "*";
  ocaml-lsp-server = "*";
  ocamlformat = "*";
})