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
      inherit (lib) types literalExpression;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.modules) mkIf mkMerge;

      cfg = config.programs.noctalia-shell;

      jsonFormat = pkgs.formats.json {};
    in {
      options.programs.noctalia-shell = with types; {
        enable = mkEnableOption "Noctalia";

        keybinds = {
          enable = mkEnableOption "Default keybinds.";
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

        colors = mkOption {
          type = jsonFormat.type;
          visible = false;
          default = null;
          description = "Color Scheme";
          example =
            literalExpression
            # Noctalia
            ''
              {
                mError = "#e9899d";
                mOnError ="#1e1418";
                mOnPrimary = "#1a151f";
                mOnSecondary = "#f3edf7";
                mOnSurface = "#e9e4f0";
                mOnSurfaceVariant = "#a79ab0";
                mOnTertiary = "#20161f";
                mOutline = "#3e364e";
                mPrimary = "#c7a1d8";
                mSecondary = "#a984c4";
                mShadow = "#120f18";
                mSurface = "#1c1822";
                mSurfaceVariant = "#262130";
                mTertiary = "#e0b7c9";
              }
            '';
        };

        settings = mkOption {
          type = jsonFormat.type;
          visible = false;
          default = null;
          description = "Noctalia Settings";
          example = literalExpression ''
            {
              "appLauncher" = {
                enableClipboardHistory = true;
                pinnedExecs = [
                ],
                position = "center";
              };
              "audio" = {
                cavaFrameRate = 60;
                showMiniplayerAlbumArt = false;
                showMiniplayerCava = false;
                visualizerType = "linear";
                volumeStep = 5;
              };
              "bar" = {
                alwaysShowBatteryPercentage = false;
                backgroundOpacity = 1;
                monitors = [
                ];
                position = "top";
                showActiveWindowIcon = true;
                widgets = {
                  center = [
                    "Workspace"
                  ];
                  left = [
                    "SystemMonitor"
                    "ActiveWindow"
                    "MediaMini"
                  ];
                  right = [
                    "ScreenRecorderIndicator"
                    "Tray"
                    "NotificationHistory"
                    "WiFi"
                    "Bluetooth"
                    "Battery"
                    "Volume"
                    "Brightness"
                    "Clock"
                    "SidePanelToggle"
                  ];
                };
              };
            "brightness" = {
              brightnessStep = 5;
            };
            "colorSchemes" = {
              darkMode = true;
              predefinedScheme = "";
              themeApps = false;
              useWallpaperColors = false;
            };
            "dock" = {
              autoHide = false;
              exclusive = false;
              monitors = [
              ];
            };
            "general" = {
              avatarImage = "/home/sumelan/.face";
              dimDesktop = false;
              radiusRatio = 1;
              showScreenCorners = false;
            };
            "location" = {
              name = "Tokyo";
              reverseDayMonth = false;
              showDateWithClock = false;
              use12HourClock = false;
              useFahrenheit = false;
            };
            "monitorsScaling" = null;
            "network" = {
              bluetoothEnabled = true;
              wifiEnabled = true;
            };
            "notifications" = {
              monitors = [
              ];
            };
            "screenRecorder" = {
              audioCodec = "opus";
              audioSource = "default_output";
              colorRange = "limited";
              directory = "~/Videos";
              frameRate = 60;
              quality = "very_high";
              showCursor = true;
              videoCodec = "h264";
              videoSource = "portal";
            };
            "ui" = {
              fontBillboard" = "Inter";
              fontDefault = "Roboto";
              fontFamily = "Roboto";
              fontFixed = "DejaVu Sans Mono";
              idleInhibitorEnabled = false;
            };
            "wallpaper": {
              current = "";
              directory = "/usr/share/wallpapers";
              isRandom = false;
              randomInterval = 300;
              swww = {
                enabled = false;
                resizeMethod = "crop";
                transitionDuration = 1.1;
                transitionFps = 60;
                transitionType = "random";
              };
            };
          '';
        };

        systemd.enable = mkEnableOption "Systemd startup.";

        spawn.enable = mkEnableOption "Niri spawn-at-startup.";
      };

      config = mkIf cfg.enable {
        programs.quickshell = {
          enable = true;
          package = quickshell.packages.${system}.quickshell;
          configs = {
            "default" = "${self.packages.${system}.noctalia-shell}/etc/xdg/quickshell/noctalia-shell";
          };
          systemd = mkIf cfg.systemd.enable {
            enable = true;
            target = "graphical-session.target";
          };
        };

        programs.niri.settings = mkMerge [
          {
            layout = {background-color = "transparent";};
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
            binds = let
              hotkeyColor = "#c7a1d8";
            in {
              "${cfg.keybinds.launcher}" = {
                action.spawn = ["qs" "ipc" "call" "appLauncher" "toggle"];
                hotkey-overlay.title = ''<i>Toggle</i> <span foreground="${hotkeyColor}">launcher</span>'';
              };
              "${cfg.keybinds.notification}" = {
                action.spawn = ["qs" "ipc" "call" "notifications" "toggleHistory"];
                hotkey-overlay.title = ''<i>Toggle</i> <span foreground="${hotkeyColor}">Notification History</span>'';
              };
              "${cfg.keybinds.settings}" = {
                action.spawn = ["qs" "ipc" "call" "settings" "toggle"];
                hotkey-overlay.title = ''<i>Toggle</i> <span foreground="${hotkeyColor}">Settings Panel</span>'';
              };
              "${cfg.keybinds.lock}" = {
                action.spawn = ["qs" "ipc" "call" "lockScreen" "toggle"];
                hotkey-overlay.title = ''<i>Toggle</i> <span foreground="${hotkeyColor}">lock screen</span>'';
              };
              "XF86MonBrightnessUp" = {
                allow-when-locked = true;
                action.spawn = ["qs" "ipc" "call" "brightness" "increase"];
              };
              "XF86MonBrightnessDown" = {
                allow-when-locked = true;
                action.spawn = ["qs" "ipc" "call" "brightness" "decrease"];
              };
            };
          })
          (mkIf cfg.spawn.enable {
            spawn-at-startup = [{command = ["qs"];}];
          })
        ];

        xdg.configFile = let
          colorSource = jsonFormat.generate "colors.json" cfg.colors;
          configSource = jsonFormat.generate "settings.json" cfg.settings;
        in {
          "noctalia/colors.json" = mkIf (cfg.colors != null) {
            source = colorSource;
            onChange = ''
              ${pkgs.procps}/bin/pkill -u $USER -USR2 quickshell && qs
            '';
          };
          "noctalia/settings.json" = mkIf (cfg.colors != null) {
            source = configSource;
            onChange = ''
              ${pkgs.procps}/bin/pkill -u $USER -USR2 quickshell && qs
            '';
          };
        };

        # # Dependencies
        programs.cava.enable = true; # Audio visualizer component
        services.swww.enable = true; # Wallpaper animations and effects

        home.packages = with pkgs; [
          brightnessctl # For internal/laptop monitor brightness
          cliphist
          ddcutil # For desktop monitor brightness (might introduce some system instability with certain monitors)
          gpu-screen-recorder # Screen recording functionality
          inter
          material-symbols # Icon font for UI elements
          matugen # Material You color scheme generation
          roboto
          wl-clipboard
        ];
      };
    };
  };
}
