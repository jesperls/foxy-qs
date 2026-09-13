

# foxy

A quickshell config that rolls once a second against a 1-in-604800 chance. On a
hit it throws the FNAF Foxy jumpscare across every monitor.

## Demo

https://github.com/user-attachments/assets/2fcf989d-34f6-486b-89d0-b7257928c736

## Run

### Nix

Straight from the repo, no clone needed:

    nix run github:jesperls/foxy-qs

To test without waiting a week, `FOXY_TEST=N` skips the roll and fires a scare
every N seconds:

    FOXY_TEST=10 nix run github:jesperls/foxy-qs

### Other Linux distros

This is just a Quickshell config, so install `quickshell`, point it at a clone,
and go. Clone once:

    git clone https://github.com/jesperls/foxy-qs
    cd foxy-qs

Then install Quickshell and its Qt6 QML modules:

- **Arch:** `sudo pacman -S quickshell qt6-declarative qt6-multimedia qt6-imageformats qt6-svg`
- **Fedora:** `sudo dnf install quickshell qt6-qtdeclarative qt6-qtmultimedia qt6-qtimageformats qt6-qtsvg`
  (older releases: `sudo dnf copr enable errornointernet/quickshell` first)
- **Debian/Ubuntu:** Quickshell is not packaged yet; build it from
  [upstream](https://quickshell.org/docs/guide/install-setup), then
  `sudo apt install qml6-module-qtmultimedia qt6-image-formats-plugins`
- **Any distro with Nix:** `nix run .` from the clone; the flake wires up
  QtMultimedia for you.

Run it from the repo, and the same overrides apply:

    quickshell --path .
    FOXY_TEST=10 quickshell --path .

## Install as a flake input

Add it to your flake and reference the package by system:

```nix
{
  inputs.foxy.url = "github:jesperls/foxy-qs";

  # somewhere with `pkgs` in scope:
  # inputs.foxy.packages.${pkgs.stdenv.hostPlatform.system}.foxy
}
```

Under Home Manager it is just a package plus an autostart, e.g.:

```nix
{ inputs, lib, pkgs, ... }:

let
  foxy = inputs.foxy.packages.${pkgs.stdenv.hostPlatform.system}.foxy;
in
{
  home.packages = [ foxy ];

  systemd.user.services.foxy = {
    Unit = {
      Description = "Foxy — jumpscare overlay";
      After = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = lib.getExe foxy;
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
```

It needs a layer-shell compositor (Hyprland, etc.) and PipeWire/PulseAudio; it
runs fine next to another quickshell instance because its `ShellId` is `foxy`.

## Settings

`settings` at the top of `flake.nix` holds the defaults; edit and rebuild. Every
value is also an environment variable that overrides the default at runtime, so
a consumer can tune it without touching this repo.

| key       | default  | meaning                       | override        |
| --------- | -------- | ----------------------------- | --------------- |
| `chance`  | `604800` | 1-in-N chance per roll        | `FOXY_CHANCE`   |
| `tickMs`  | `1000`   | roll interval                 | `FOXY_TICK_MS`  |
| `scareMs` | `2000`   | how long the overlay stays up | `FOXY_SCARE_MS` |
| `frameMs` | `50`     | animation frame delay         | `FOXY_FRAME_MS` |
| `volume`  | `1.0`    | scream volume, 0.0–1.0        | `FOXY_VOLUME`   |
| `sound`   | `true`   | play the scream at all        | `FOXY_SOUND`    |

Durations are milliseconds, and volume is clamped to 0.0–1.0. `FOXY_SOUND` is
false only for `0` or `false`. `FOXY_TEST=N` skips the roll and fires every N
seconds; it has no default and stays off unless set.
