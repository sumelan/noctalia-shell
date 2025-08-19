{
  description = "Noctalia";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    quickshell = {
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    quickshell,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    packages.${system} = {
      noctalia-shell = pkgs.stdenvNoCC.mkDerivation {
        name = "noctalia-shell";
        src = ./.;
        installPhase = ''
          mkdir -p $out/etc/xdg/quickshell/noctalia-shell
          cp -r . $out/etc/xdg/quickshell/noctalia-shell
        '';
      };
      default = self.packages.${system}.noctalia-shell;
    };

    homeModules.noctalia-shell = {
      config,
      pkgs,
      lib,
      ...
    }: let
      cfg = config.programs.noctalia-shell;
    in {
      options.programs.noctalia-shell = {
        enable = lib.mkEnableOption "Noctalia";
        enableSystemd =
          lib.mkEnableOption "Noctalia systemd startup";
        enableSpawn =
          lib.mkEnableOption "Noctalia Niri spawn-at-startup";
      };

      config = lib.mkIf cfg.enable {
        programs.quickshell = {
          enable = true;
          package = quickshell.packages.${system}.quickshell;
          configs.noctalia-shell = "${
            self.packages.${system}.noctalia-shell
          }/etc/xdg/quickshell/noctalia-shell";
          activeConfig = lib.mkIf cfg.enableSystemd "Noctalia";
          systemd = lib.mkIf cfg.enableSystemd {
            enable = true;
            target = "graphical-session.target";
          };
        };

        programs.niri.settings = lib.mkMerge [
          {
            layout = {
              background-color = "transparent";
            };
          }
          {
            window-rules = [
              {
                geometry-cornerradisu = {
                  bottom-left = 20.0;
                  bottom-right = 20.0;
                  top-left = 20.0;
                  top-right = 20.0;
                };
                clip-to-geometry = true;
              }
            ];
          }
          {
            layer-rules = [
              {
                matches = [{namespace = "^swww-daemon$";}];
                place-within-backdrop = true;
              }
              {
                matches = [{namespace = "^quickshell-wallpaper$";}];
              }
              {
                matches = [{namespace = "^quickshell-overview$";}];
                place-within-backdrop = true;
              }
            ];
          }
          (lib.mkIf cfg.enableSpawn {
            spawn-at-startup = [{command = ["qs"];}];
          })
        ];

        # Dependencies
        home.packages = with pkgs; [
          brightnessctl # For internal/laptop monitor brightness
          cava # Audio visualizer component
          ddcutil # For desktop monitor brightness (might introduce some system instability with certain monitors)
          gpu-screen-recorder # Screen recording functionality
          material-symbols # Icon font for UI elements
          matugen # Material You color scheme generation
          swww # Wallpaper animations and effects
          xdg-desktop-portal-gnome # Desktop integration (or alternative portal)
        ];
      };
    };
  };
}
