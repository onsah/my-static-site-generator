(lang dune 3.11)

(name my_static_site_generator)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Author Name")

(maintainers "Maintainer Name")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name my_static_site_generator)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml dune core)
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
