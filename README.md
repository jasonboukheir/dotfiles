# Experimental Nix Setup!

This is an experimental setup for using nix on my macbook (for now)!

## (Experimental) Installation

1. Install nix
  ```sh
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  ```
2. Install nix-darwin
  ```sh
  nix run nix-darwin -- switch --flake .
  ```

## (Experimental) Updating

```sh
darwin-rebuild switch --flake .
```
