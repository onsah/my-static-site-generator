.DEFAULT_GOAL := build

.PHONY: test

build:
	dune build

help:
	dune exec bin/main.exe -- -help

format:
	dune fmt

test:
	dune test

repl:
	dune utop
