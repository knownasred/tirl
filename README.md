# tirl

## Setup

This project uses Nix flakes with zig2nix for reproducible Zig builds.

### Using direnv

```bash
direnv allow
```

### Using nix directly

```bash
nix develop
```

## Development

```bash
zig build
zig build run
zig build test
```

## Build with nix

```bash
nix build
nix run .
nix run .#test
```

## Apps

The following nix apps are available:

- `nix run .#build` - Build the project
- `nix run .#test` - Run tests
- `nix run .#docs` - Generate docs
- `nix run .#zig2nix` - Run zig2nix tools
