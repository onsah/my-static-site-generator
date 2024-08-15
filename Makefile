content_path = $$PROJECT_ROOT/content/
dist_path = $$PROJECT_ROOT/dist/

build: format
	$(MAKE) -C site-generator build

help:
	$(MAKE) -C site-generator help

format:
	$(MAKE) -C site-generator format

test:
	$(MAKE) -C site-generator test

repl:
	$(MAKE) -C site-generator repl

generate: build
	site-generator/_build/default/bin/main.exe --content-path $(content_path) --out-path $(dist_path)

serve: generate
	miniserve $(dist_path) --index index.html
