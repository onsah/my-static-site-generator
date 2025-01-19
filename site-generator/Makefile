.DEFAULT_GOAL := build

.PHONY: test

build:
	dune build

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
	xdg-open _build/default/_doc/_html/index.html
