# psst development recipes

# Build
build:
    @opam exec -- dune build

# Run psst CLI
run *ARGS:
    @opam exec -- dune exec psst -- {{ARGS}}

# Run tests
test:
    @opam exec -- dune test

# Run tests with full output
test-verbose:
    @opam exec -- dune test --force

# Clean and test
retest:
    @opam exec -- dune clean
    @opam exec -- dune test

# Clean
clean:
    @opam exec -- dune clean

# Format
fmt:
    @opam exec -- dune fmt

# Install
install:
    @opam exec -- dune install

# Watch
watch:
    @opam exec -- dune build --watch
