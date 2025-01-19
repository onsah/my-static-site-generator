.DEFAULT_GOAL := build

.PHONY: test

help: build
	result/bin/website-generator -help

build: format
	dune build

package:
	nix-build

watch:
	dune build --watch

format:
	dune fmt

test:
	dune test

repl:
	dune utop

docs:
	dune build @doc

open-docs: docs
	xdg-open _build/default/_doc/_html/index.html
