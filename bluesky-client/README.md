# Bluesky OCaml Client

A simple Bluesky client built with OCaml and Jane Street's Bonsai web framework.

## Features

- Login with Bluesky handle and app password
- Create posts
- Built entirely in OCaml (including the web server!)

## Prerequisites

- OCaml and opam installed
- A Bluesky account
- An app password from Bluesky (create one at https://bsky.app/settings/app-passwords)

## Building

```bash
# Install dependencies (already done)
eval $(opam env)
opam install dune core bonsai async cohttp-async yojson ppx_jane js_of_ocaml js_of_ocaml-ppx

# Build the project
dune build
```

## Running

1. Start the OCaml web server from the project directory:
```bash
cd bluesky-client
./_build/default/bin/server.exe
# Or to use a different port:
./_build/default/bin/server.exe 3000
```

2. Open your browser to http://localhost:8000

3. Login with your Bluesky handle and app password

4. Start posting!

## Project Structure

```
bluesky-client/
├── lib/
│   ├── bluesky_api.ml    # Bluesky API client
│   ├── bluesky_api.mli   # API interface
│   ├── app.ml            # Bonsai web app
│   └── app.mli           # App interface
├── bin/
│   ├── main.ml          # Entry point for JS compilation
│   └── server.ml        # OCaml web server
├── index.html           # HTML host page
└── dune-project         # Dune project configuration
```

## Security Note

This is a demo application. In production:
- Never store app passwords in plain text
- Use HTTPS for all communications
- Implement proper error handling and validation
- Consider implementing token refresh logic

## License

MIT