build: check-env
	$(MAKE) -C site-generator build

generate-help: check-env
	$(MAKE) -C site-generator generate-help

generate: check-env
	$(MAKE) -C site-generator generate

format: check-env
	$(MAKE) -C site-generator format

test:
	$(MAKE) -C site-generator test

serve: check-env
	$(MAKE) -C site-generator serve

check-env:
ifndef AIONO_WEBSITE_GENERATE_ENV_ENABLED
	echo -e "Not inside the project's environment.\nThe dependencies are provided via the shell.nix file in the project's root."
	exit 1
endif