# Nix Setup

## Macos Installation

1. Install nix via determinate nix
2. Install nix-darwin
  ```sh
  nix run nix-darwin -- switch --flake .
  ```

## Updating

```sh
darwin-rebuild switch --flake .
```

## VPN on MacOS

#### Start
```sh
wg-quick up wg0
```

#### Stop
```sh
wg-quick down wg0
```

#### Status
```sh
sudo wg show
```
