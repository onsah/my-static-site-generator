build:
	$(MAKE) -C site-generator build

generate-help:
	$(MAKE) -C site-generator generate-help

generate:
	$(MAKE) -C site-generator generate

format:
	$(MAKE) -C site-generator format

serve:
	$(MAKE) -C site-generator serve