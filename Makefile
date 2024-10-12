content_path = $$PROJECT_ROOT/content/
dist_path = $$PROJECT_ROOT/dist/
website_generator_path = website-generator-result
website_path = website-result

build: format
	nix-build -A website-generator --out-link $(website_generator_path)

help: build
	$(website_generator_path)/bin/website-generator -help

format:
	$(MAKE) -C site-generator format

test:
	$(MAKE) -C site-generator test

repl:
	$(MAKE) -C site-generator repl

generate:
	nix-build -A website --out-link $(website_path)

serve: generate
	miniserve $(website_path)/dist --index index.html --port 9090

deploy:
	scripts/deploy.nu
