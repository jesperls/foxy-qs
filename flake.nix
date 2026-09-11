{
  description = "A 1/604800-per-second Foxy jumpscare for every monitor";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Defaults, exported by the wrapper. Durations in ms; env overrides.
      settings = {
        chance = 604800; # 1-in-N per tick
        tickMs = 1000; # roll interval
        scareMs = 2000; # how long the overlay stays up
        frameMs = 50; # animation frame interval
        volume = 1.0; # scream volume, 0.0-1.0
        sound = true; # play the scream at all
      };

      config = nixpkgs.lib.fileset.toSource {
        root = ./.;
        fileset = nixpkgs.lib.fileset.unions [
          ./shell.qml
          ./assets
        ];
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # QtMultimedia is not part of the quickshell wrapper's QML path.
          qmlEnv = pkgs.buildEnv {
            name = "foxy-qml";
            paths = [
              pkgs.kdePackages.qtmultimedia
              pkgs.qt6.qtdeclarative
              pkgs.qt6.qtimageformats
            ];
            pathsToLink = [
              "/lib/qt-6/qml"
              "/lib/qt-6/plugins"
            ];
          };

          foxy = pkgs.writeShellApplication {
            name = "foxy";

            runtimeInputs = [ pkgs.quickshell ];

            text = ''
              # Defaults from flake.nix; a FOXY_* already in the environment wins.
              : "''${FOXY_CHANCE:=${toString settings.chance}}"
              : "''${FOXY_TICK_MS:=${toString settings.tickMs}}"
              : "''${FOXY_SCARE_MS:=${toString settings.scareMs}}"
              : "''${FOXY_FRAME_MS:=${toString settings.frameMs}}"
              : "''${FOXY_VOLUME:=${toString settings.volume}}"
              : "''${FOXY_SOUND:=${if settings.sound then "1" else "0"}}"
              export FOXY_CHANCE FOXY_TICK_MS FOXY_SCARE_MS FOXY_FRAME_MS
              export FOXY_VOLUME FOXY_SOUND

              export QML2_IMPORT_PATH="${qmlEnv}/lib/qt-6/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
              export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
              export QT_PLUGIN_PATH="${qmlEnv}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

              exec quickshell --path ${config} "$@"
            '';

            meta = {
              description = "Foxy jumpscare overlay (FOXY_TEST=N: scare every N seconds)";
              mainProgram = "foxy";
              platforms = pkgs.lib.platforms.linux;
            };
          };
        in
        {
          default = foxy;
          inherit foxy;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          foxy-qml = pkgs.runCommand "foxy-qml-check" {
            nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
          } ''
            find ${config} -name '*.qml' -exec qmllint {} + >qmllint.log 2>&1 || true
            if grep -F '[syntax]' qmllint.log; then
              cat qmllint.log >&2
              exit 1
            fi
            touch $out
          '';
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.foxy}/bin/foxy";
          meta.description = "Run the Foxy jumpscare shell";
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
