{ config, lib, pkgs, ... }:
{
  imports = [
    ../profiles/pi/pi01.nix
    ../usb-gadget.nix
  ];

  services.openssh = {
    enable = true;
  };

  services.getty.autologinUser = "root";
  users.extraUsers.root.initialHashedPassword = "";

  networking = {
    hostName = "pi0";
    interfaces.usb0.ipv4.addresses = [
      {
        address = "10.3.14.1";
        prefixLength = 24;
      }
    ];
    firewall = {
      allowedUDPPorts = [ 67 ];
    };
  };
  systemd.services."network-addresses-usb0".after = [ "usb-gadget.service" ];
  systemd.services."kea-dhcp4-server.service".after = [ "network-addresses-usb0.service" ];
  systemd.services."serial-getty@ttyGS0" = {
    enable = true;
    after = [ "usb-gadget.service" ];
  };

  services.udev.extraRules =
  ''
    ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyGS0", TAG+="systemd", ENV{SYSTEMD_WANTS}="serial-getty@ttyGS0.service"
  '';

  services.kea = {
    dhcp4 = {
      enable = true;
      settings = {
        interfaces-config = {
          dhcp-socket-type = "raw";
          interfaces = [ "usb0" ];
          # https://www.reddit.com/r/homelab/comments/1b4uob7/kea_dhcp_server_not_listening_when_started/
          # alternatively use systemd to restart
          # or even better a dummy bridge
          service-sockets-max-retries = 200000;
          service-sockets-retry-wait-time = 5000;
        };
        lease-database = {
          name = "/var/lib/kea/dhcp4.leases";
          persist = true;
          type = "memfile";
        };
        rebind-timer = 2000;
        renew-timer = 1000;
        subnet4 = [
          {
            id = 1;
            pools = [
              {
                pool = "10.3.14.100 - 10.3.14.200";
              }
            ];
            subnet = "10.3.14.0/24";
            reservations = [
              { # host side
                hw-address = "aa:bb:cc:dd:ee:ff";
                ip-address = "10.3.14.2";
              }
            ];
          }
        ];
        valid-lifetime = 4000;
      };
    };
  };

  hardware.usb-gadget = {
    enable = true;
    gadgets.g = {
      default = true;
      functions.acm."0" = {};
      functions.ecm.usb0 = {
        deviceAddress = "00:11:22:33:44:55";
        hostAddress = "aa:bb:cc:dd:ee:ff";
      };
      configs.def = {
        id = 1;
        functions = [
          "acm.0"
          "ecm.usb0"
        ];
      };
    };
  };

  nixpkgs = {
    crossSystem = lib.systems.elaborate lib.systems.examples.raspberryPi;
  };

  system.stateVersion = "25.05";
}
