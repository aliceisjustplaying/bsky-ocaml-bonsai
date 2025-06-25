# Bluesky OCaml Client

A simple Bluesky client built with OCaml and Jane Street's Bonsai web framework.

## Features

- Login with Bluesky handle and app password
- Create posts
- Built entirely in OCaml (including the web server!)
- Clean event-driven architecture without polling
- Direct callback integration with Bonsai's state management

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

1. Start the OCaml web server:
```bash
./_build/default/bin/server.exe
# Or to use a different port:
./_build/default/bin/server.exe 3000
```

2. Open your browser to http://localhost:8000

3. Login with your Bluesky handle and app password

4. Start posting!

## Project Structure

```
ocaml/
├── lib/
│   ├── bluesky_api.ml    # Bluesky API client with JavaScript interop
│   ├── bluesky_api.mli   # API interface
│   ├── app.ml            # Bonsai web app with event-driven state management
│   ├── app.mli           # App interface
│   └── dune              # Library build configuration
├── bin/
│   ├── main.ml           # Entry point for JS compilation
│   ├── server.ml         # OCaml web server using Cohttp-async
│   └── dune              # Executables build configuration
├── test/                 # Test directory
├── index.html            # HTML host page
├── dune-project          # Dune project configuration
└── bluesky_client.opam   # OPAM package file
```

## Architecture Notes

- The app uses Bonsai's state machine for managing UI state
- API calls are handled through JavaScript interop using `js_of_ocaml`
- Callbacks from JavaScript promises are integrated directly into Bonsai's effect system
- No polling or global mutable state - all updates flow through the state machine

## Security Note

This is a demo application. In production:
- Never store app passwords in plain text
- Use HTTPS for all communications
- Implement proper error handling and validation
- Consider implementing token refresh logic
- Add rate limiting and request validation

## License

MIT