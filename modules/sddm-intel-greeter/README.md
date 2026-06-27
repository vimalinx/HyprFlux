# SDDM Intel Greeter

Optional SDDM X11 greeter config that pins the login screen Xorg server to Intel iGPU.

## Why

On hybrid NVIDIA laptops, the display manager can keep the NVIDIA dGPU awake before the user session starts. This template adds:

```text
ServerArguments=-nolisten tcp -isolateDevice PCI:0:2:0
```

Adjust `PCI:0:2:0` for your own Intel iGPU if needed.

## Apply

```bash
sudo ./install-sddm-intel-greeter-fix.sh
```

Log out and back in, or reboot. Then check whether the greeter no longer appears as an NVIDIA client.

## Remove

```bash
sudo ./remove-sddm-intel-greeter-fix.sh
```

If the greeter fails to start, switch to a TTY and run the remove script.
