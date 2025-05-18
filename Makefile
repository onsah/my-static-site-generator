content_path = $$PROJECT_ROOT/content/
dist_path = $$PROJECT_ROOT/dist/
website_generator_path = website-generator-result
website_path = website-result

generate:
	nix-build

serve: generate
	miniserve result/dist --index index.html --port 9090

deploy:	generate
<<<<<<< HEAD
ifndef ip
	$(error "required argument: 'ip'")
endif
	SERVER_IP="$(ip)" scripts/deploy.nu
=======
	scripts/deploy.nu
>>>>>>> main
