# WIP

## Usage

Create `CDC ACM` and `ECM` gadgets

```nix
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
```
