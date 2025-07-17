# Nix Setup

## Macos Installation

1. Install nix (via lix)
  ```sh
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  ```
2. Install nix-darwin
  ```sh
  nix run nix-darwin -- switch --flake .
  ```

## Updating

```sh
darwin-rebuild switch --flake .
```
