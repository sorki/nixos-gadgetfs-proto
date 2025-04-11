{ config, lib, pkgs, ... }:
let
  cfg = config.hardware.usb-gadget;
in
{
  options = {
    hardware.usb-gadget = {
      enable = lib.mkEnableOption "Enable USB Gadget creation.";
      gadgets = lib.mkOption {
        description = "Gadget definition.";
        type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              description = "Enable this gadget.";
              default = true;
            };
            default = lib.mkEnableOption "Make this gadget a default gadget, loaded on start.";
            # IDs
            vendorID = lib.mkOption {
              type = lib.types.str;
              description = "USB vendor ID (idVendor).";
              default = "0x1d6b"; # Linux Foundation
            };
            productID = lib.mkOption {
              type = lib.types.str;
              description = "USB product ID (idProduct).";
              default = "0x0104"; # Multifunction Composite Gadget
            };
            bcdDevice = lib.mkOption {
              type = lib.types.str;
              description = "USB device defined revision number (bcdDevice).";
              default = "0x0100"; # v1.0.0
            };
            bcdUSB = lib.mkOption {
              type = lib.types.str;
              description = "USB version this device conforms to (bcdUSB).";
              default = "0x0200"; # USB 2.0
            };
            # FIXME NOT YET
            # echo 0xEF > bDeviceClass
            # echo 0x02 > bDeviceSubClass
            # echo 0x01 > bDeviceProtocol
            # strings
            manufacturer = lib.mkOption {
              type = lib.types.str;
              description = "Device manufacturer.";
              default = "NixOS";
            };
            product = lib.mkOption {
              type = lib.types.str;
              description = "Product name.";
              default = "USB Gadget";
            };
            serialNumber = lib.mkOption {
              type = lib.types.str;
              description = "Serial number (actually a string).";
              default = "alpha";
            };
            # functions
            # ls /run/booted-system/kernel-modules/lib/modules/*/kernel/drivers/usb/gadget/function/usb_f*
            # ls linux/Documentation/ABI/testing/config-usb-gadget*

            # type = lib.types.enum [ "ecm" "ecm_subset" "fs" "hid" "mass_storage" "midi" "ncm" "obex"
            #  "phonet" "printer" "rndis" "serial" "ss_lb" "tcm" "uac2" "uvc" ];
            functions = {
              acm = lib.mkOption {
                description = "ACM function configuration.";
                type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
                  options = {
                  };
                }));
              };
              ecm = lib.mkOption {
                description = "ECM function configuration.";
                type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
                  options = {
                    deviceAddress = lib.mkOption {
                      type = lib.types.str;
                      description = "MAC address of device's end of this Ethernet over USB link.";
                      example = "00:11:22:33:44:55";
                    };
                    hostAddress = lib.mkOption {
                      type = lib.types.str;
                      description = "MAC address of host's end of this Ethernet over USB link.";
                      example = "00:11:22:33:44:55";
                    };
                    qmult = lib.mkOption {
                      type = lib.types.ints.u32;
                      default = 5;
                      description = "Queue length multiplier for high and super speed.";
                    };
                  };
                }));
              };
            };
            # configs
            configs = lib.mkOption {
              description = "Gadget configurations";
              type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
                options = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    description = "Enable this configuration.";
                    default = true;
                  };
                  id = lib.mkOption {
                    type = lib.types.ints.between 1 255;
                    description = "Configuration ID";
                  };
                  maxPower = lib.mkOption {
                    type = lib.types.ints.u8;
                    description = "Maximum power consumption from the bus.";
                    default = 120;
                  };
                  # this is a list so mkOrder (mkAfter,mkBefore) can be used
                  functions = lib.mkOption {
                    type = lib.types.listOf (lib.types.str);
                    description = "Functions linked to this configuration.";
                  };
                };
              }));
            };
          };
        }));
      };
    };
  };
  config = lib.mkIf cfg.enable {

    boot.kernelModules = [ "libcomposite" ];
    systemd.additionalUpstreamSystemUnits = [ "usb-gadget.target" ];

    systemd.services."usb-gadget" = {
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      unitConfig = {
        Description = "Configure USB Gadget device";
        After = [ "sys-kernel-config.mount" ];
        Requires = [ "sys-kernel-config.mount" ];
      };
      wantedBy = [ "usb-gadget.target" ];
      script = ''
        ${lib.concatStringsSep
          "\n"
          (lib.mapAttrsToList
            (n: g:
            ''
              ${lib.optionalString
                g.enable
                ''
                  # Create gadget ${n}
                  cd /sys/kernel/config/usb_gadget
                  mkdir ${n} && cd ${n}

                  echo ${g.vendorID} > idVendor
                  echo ${g.productID} > idProduct
                  echo ${g.bcdDevice} > bcdDevice
                  echo ${g.bcdUSB} > bcdUSB

                  mkdir strings/0x409
                  echo "${g.manufacturer}" > strings/0x409/manufacturer
                  echo "${g.product}" > strings/0x409/product
                  echo "${g.serialNumber}" > strings/0x409/serialnumber

                  ${lib.concatStringsSep
                    "\n"
                    (lib.mapAttrsToList
                      (fn: fv:
                      let
                        funcDir = "functions/acm.${fn}";
                      in
                      ''
                        ${pkgs.kmod}/bin/modprobe usb_f_acm
                        # Create acm functions
                        mkdir ${funcDir}
                      ''
                      )
                      g.functions.acm
                    )
                  }

                  ${lib.concatStringsSep
                    "\n"
                    (lib.mapAttrsToList
                      (fn: fv:
                      let
                        funcDir = "functions/ecm.${fn}";
                      in
                      ''
                        ${pkgs.kmod}/bin/modprobe usb_f_ecm
                        # Create ecm functions
                        mkdir ${funcDir}
                        echo ${builtins.toString fv.qmult} > ${funcDir}/qmult
                        echo "${fv.deviceAddress}" > ${funcDir}/dev_addr
                        echo "${fv.hostAddress}" > ${funcDir}/host_addr
                      ''
                      )
                      g.functions.ecm
                    )
                  }


                  # Create configs
                  ${lib.concatStringsSep
                    "\n"
                    (lib.mapAttrsToList
                      (cn: cv:
                      let
                        confDir = "configs/${cn}.${builtins.toString cv.id}";
                      in
                      ''
                        mkdir ${confDir}
                        echo ${builtins.toString cv.maxPower} > ${confDir}/MaxPower

                        # Assign functions
                        ${lib.concatMapStringsSep
                          "\n"
                          (x: "ln -s functions/${x} ${confDir}/")
                          cv.functions
                        }
                      ''
                      )
                      g.configs
                    )
                  }

                  # questionable
                  ${config.systemd.package}/bin/udevadm settle -t 5 || :

                  ${lib.optionalString g.default
                  ''
                    # Enable this gadget by binding it to a UDC from /sys/class/udc
                    ls /sys/class/udc > UDC
                  ''}
                ''
              }
            ''
            )
            cfg.gadgets
          )
        }
      '';
    };
  };
}

# TODO: assert that gadgets.x.configs.x.functions are actually defined
# TODO: if only one gadget, make it default, impossible!! assert instead
# TODO: unloading
# TODO: multiple UDCs
#       # echo 0x20980000:usb > UDC
#       ls /sys/class/udc > UDC
# udevadm trigger?
