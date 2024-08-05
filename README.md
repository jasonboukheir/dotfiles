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
darwin-rebuild build --flake .#{{ your special setup here }}
```
Specifically, run the command in the [`flake.nix`](https://github.com/jasonboukheir/dotfiles/blob/725d475a6b5980e2a1787a2aea77e1e8f65b1609/flake.nix#L32) file.
