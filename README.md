# foxy

A quickshell config that rolls once a second against a 1-in-604800 chance. On a
hit it throws the FNAF Foxy jumpscare across every monitor.

## Run

Straight from the repo, no clone needed:

    nix run github:jesperls/foxy-qs

To test without waiting a week, `FOXY_TEST=N` skips the roll and fires a scare
every N seconds:

    FOXY_TEST=10 nix run github:jesperls/foxy-qs

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
