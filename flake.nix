{
  description = "NixOS Raspberry Pi 5 Kodi system";

  inputs = {
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
  };

  nixConfig = {
    extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    extra-trusted-public-keys = [ "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI=" ];
  };

  outputs = { nixos-raspberrypi, ... }@inputs: {
    nixosConfigurations.kodi-pi = nixos-raspberrypi.lib.nixosSystemFull {
      specialArgs = { inherit nixos-raspberrypi; };
      modules = [
        ({ nixos-raspberrypi, pkgs, lib, ... }:
        let
          myKodi = pkgs.kodi-wayland.withPackages (kodiPkgs: with kodiPkgs; [
            jellyfin
          ]);
        in {
          imports = with nixos-raspberrypi.nixosModules; [
            raspberry-pi-5.base
            raspberry-pi-5.page-size-16k
            raspberry-pi-5.display-vc4
          ];

          # Disable SDL3 test suite (testprocess fails in Nix sandbox)
          nixpkgs.overlays = [
            (final: prev: {
              sdl3 = prev.sdl3.overrideAttrs (old: {
                doCheck = false;
              });
            })
          ];

          networking.hostName = "kodi-pi";

          # Bootloader
          boot.loader.raspberry-pi.bootloader = "kernel";

          # Filesystems (matching nixos-raspberrypi installer layout)
          fileSystems."/" = {
            device = "/dev/disk/by-label/NIXOS_SD";
            fsType = "ext4";
            options = [ "noatime" ];
          };
          fileSystems."/boot/firmware" = {
            device = "/dev/disk/by-label/FIRMWARE";
            fsType = "vfat";
            options = [ "noatime" "noauto" "x-systemd.automount" "x-systemd.idle-timeout=1min" ];
          };

          # Graphics
          hardware.graphics.enable = true;

          # Pi firmware config.txt settings for Kodi
          hardware.raspberry-pi.config.all.options = {
            gpu_mem = { enable = true; value = 256; };
            hdmi_force_hotplug = { enable = true; value = true; };
          };

          # Audio: ALSA only for HDMI passthrough
          services.pipewire.enable = false;
          services.pulseaudio.enable = false;

          # Kodi via Cage (Wayland kiosk)
          services.cage = {
            enable = true;
            user = "kodi";
            program = "${myKodi}/bin/kodi-standalone";
            environment = {
              WLR_LIBINPUT_NO_DEVICES = "1";
            };
          };

          # Kodi user
          users.users.kodi = {
            isNormalUser = true;
            extraGroups = [ "video" "audio" "input" "render" ];
          };

          # Admin user
          users.users.sean = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            openssh.authorizedKeys.keys = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDCIqgZ7kedxo+mOW7YG73Vp3zel3h180y3GKvHtRsXfGlpIIvRDy7pgCBQ4AGXYD4y78URQmFohYSAPqCPOPaWcU2un3XG9KvCzEsHmsbskPonitUmCiKvrKkb6oW4jCBtd7AEtBn+AiajAQFtPZ7NN2Df3AmTypvR6Irg7R+nxnfc9NTIHmGvxSDyWcbb4pguL20sctUSqGL6xGh8q/bqhdOThSimM+z9bEUNxK/5rPhwkNniMrp4pJcUrUiAh5/4DiRFG6KT+oeg+/myoz/Z1sPvAs7u/8JDQI4RshRD8Hu0oTkRBN6Hxj478q2SXbeBUZlD6IdjP3RhGpmSecoDdtWqKbpuV3eVRtQtba3KL86GBeV/bugaOdJ1Aud+1SOFJreAAuvxzMMKT+cdQZk6oOPP148DA/No+mDm/2S43lcdCXh79wA6YRAmKQ8jmZxTCtPutrvuZK1rguvvUlEoG/vhdNHh7eDa4Td07V6bjCRPUl8qk/e4M0E3pwsTlZc="
              "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOIgEteUEW06dnBHe2z8vNLwz2iMKe8bba6JgMmOUpcBAAAABHNzaDo= sean@framework16"
            ];
          };

          # SSH
          services.openssh = {
            enable = true;
            settings = {
              PasswordAuthentication = false;
              PermitRootLogin = "no";
            };
          };

          # Networking
          networking.useDHCP = true;
          security.sudo.wheelNeedsPassword = false;

          # Firewall
          networking.firewall.allowedTCPPorts = [
            22   # SSH
            8080 # Kodi web remote
          ];

          environment.systemPackages = [ myKodi ];

          system.stateVersion = "24.11";
        })
      ];
    };
  };
}
