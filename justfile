# psst development recipes

# Build the project
build:
    opam exec -- dune build

# Run psst CLI with args
run *ARGS:
    opam exec -- dune exec psst -- {{ARGS}}

# Run tests
test:
    opam exec -- dune test

# Clean build artifacts
clean:
    opam exec -- dune clean

# Format code
fmt:
    opam exec -- dune fmt

# Install to opam switch
install:
    opam exec -- dune install

# Watch and rebuild on changes
watch:
    opam exec -- dune build --watch
