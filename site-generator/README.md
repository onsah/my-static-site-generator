# Site Generator

This is my homegrown site generator software. It's a basic templating program written in OCaml.

## Development

Requirements:
- direnv
- nix

When `cd`'ed into the directory, the necessary dependencies will be provided via `nix-shell`.

To get IDE feedback, run:

```shell
make watch
```

and keep it open.

## Building

```shell
make build
```

## Packaging

This builds the program in an isolated enviornment with nix:

```shell
make package
```

## Testing

```shell
make test
```

## REPL

Useful for discovering API from dependencies and quick prototyping.

```shell
make repl
```

## Documentation

```shell
make open-docs
```
