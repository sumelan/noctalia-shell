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
      inherit (lib) mkEnableOption mkOption mkIf mkMerge;
      inherit (lib.types) str;
      cfg = config.programs.noctalia-shell;
    in {
      options.programs.noctalia-shell = {
        enable = mkEnableOption "Noctalia";
        keybinds = {
          enable = mkEnableOption "Niri keybinds";
          launcher = mkOption {
            type = str;
            default = "Mod+Space";
            description = "Keybind to toggle launcher.";
          };
          notification = mkOption {
            type = str;
            default = "Mod+N";
            description = "Keybind to toggle notification history.";
          };
          settings = mkOption {
            type = str;
            default = "Mod+Comma";
            description = "Keybind to toggle settings panel.";
          };
          lock = mkOption {
            type = str;
            default = "Mod+Ctrl+L";
            description = "Keybind to toggle lock screen";
          };
        };
        systemd.enable = mkEnableOption "Systemd startup";
        spawn.enable = mkEnableOption "Niri spawn-at-startup";
      };

      config = mkIf cfg.enable {
        programs.quickshell = {
          enable = true;
          package = quickshell.packages.${system}.quickshell;
          configs.noctalia-shell = "${self.packages.${system}.noctalia-shell}/etc/xdg/quickshell/noctalia-shell";
          activeConfig = lib.mkIf cfg.systemd.enable "noctalia-shell";
          systemd = lib.mkIf cfg.systemd.enable {
            enable = true;
            target = "graphical-session.target";
          };
        };

        programs.niri.settings = mkMerge [
          {
            layout = {
              background-color = "transparent";
            };
          }
          {
            window-rules = [
              {
                geometry-corner-radius = {
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
          (mkIf cfg.keybinds.enable {
            binds = {
              cfg.keybinds.launcher = {
                action.spawn = ["qs" "-c" "noctalia-shell" "ipc" "call" "appLauncher" "toggle"];
                hotkey-overlay.title = "Toggle launcher";
              };
              cfg.keybinds.notification = {
                action.spawn = ["qs" "-c" "noctalia-shell" "ipc" "call" "notifications" "toggleHistory"];
                hotkey-overlay.title = "Toggle Notification History";
              };
              cfg.keybinds.settings = {
                action.spawn = ["qs" "-c" "noctalia-shell" "ipc" "call" "settings" "toggle"];
                hotkey-overlay.title = "Toggle Settings Panel";
              };
              cfg.keybinds.lock = {
                action.spawn = ["qs" "-c" "noctalia-shell" "ipc" "call" "lockScreen" "toggle"];
                hotkey-overlay.title = "Toggle lock screen";
              };
            };
          })
          (mkIf cfg.spawn.enable {
            spawn-at-startup = [{command = ["qs" "-c noctalia-shell"];}];
          })
        ];

        # # Dependencies
        programs.cava.enable = true; # Audio visualizer component
        services.swww.enable = true; # Wallpaper animations and effects

        home.packages = with pkgs; [
          brightnessctl # For internal/laptop monitor brightness
          ddcutil # For desktop monitor brightness (might introduce some system instability with certain monitors)
          gpu-screen-recorder # Screen recording functionality
          material-symbols # Icon font for UI elements
          matugen # Material You color scheme generation
          xdg-desktop-portal-gnome # Desktop integration (or alternative portal)
        ];
      };
    };
  };
}
