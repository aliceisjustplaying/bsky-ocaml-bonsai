(lang dune 3.0)

(name bluesky_client)

(generate_opam_files true)

(source
 (github yourusername/bluesky-client))

(authors "Your Name")

(maintainers "Your Name")

(license MIT)

(documentation https://github.com/yourusername/bluesky-client)

(package
 (name bluesky_client)
 (synopsis "A simple Bluesky client built with Bonsai")
 (description "A web-based Bluesky client that supports authentication with app passwords and posting")
 (depends
  ocaml
  dune
  bonsai
  core
  async
  cohttp-async
  yojson
  ppx_jane
  js_of_ocaml
  js_of_ocaml-ppx))