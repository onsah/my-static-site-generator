content_path = $$PROJECT_ROOT/content/
dist_path = $$PROJECT_ROOT/dist/

.DEFAULT_GOAL := build

.PHONY: test

build:
	dune build

generate-help:
	dune exec bin/main.exe -- -help

generate: build
	test -d $(content_path) || (echo "Error: $(content_path) is not a directory" && exit 1)
	dune exec bin/main.exe -- --content-path $(content_path) --out-path $(dist_path)

format:
	dune fmt

test:
	dune test

serve: generate
	miniserve $(dist_path) --index index.html

repl:
	dune utop
