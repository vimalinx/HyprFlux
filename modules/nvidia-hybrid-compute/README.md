# NVIDIA Hybrid Compute

Hybrid-laptop setup where the desktop GUI stays on Intel/Mesa while the NVIDIA dGPU remains available for CUDA or explicit offload workloads.

This is not a generic "turn on every NVIDIA Wayland variable" module. The source workstation uses an RTX 5070 Ti Laptop GPU mostly as a compute accelerator, while Hyprland, Chromium, GTK, and normal desktop apps should avoid waking the NVIDIA graphics stack.

## Current Source Pattern

- GUI defaults to Intel/Mesa with `DRI_PRIME=0`.
- EGL/Vulkan ICDs are pinned to Mesa/Intel for normal desktop apps.
- `AQ_DRM_DEVICES` is intentionally left unset to avoid login loops when card numbering changes.
- `nvidia` core driver remains available for CUDA.
- Strict compute-only mode can block `nvidia_drm` and `nvidia_modeset`.
- TLP can explicitly allow runtime PM for the NVIDIA PCI functions.

## Files

- `91-igpu-gui-stack.conf`: user environment.d template for GUI apps.
- `10-force-mesa-egl.conf`: optional systemd user drop-in for the Hyprland
  unit itself, because compositor environment must be set before Hyprland starts.
- `hypr-env.snippet`: Hyprland `env = ...` equivalent.
- `nvidia-compute.conf`: core NVIDIA dynamic power management option.
- `zz-nvidia-compute-only.conf.template`: stricter template that blocks NVIDIA display/KMS modules.
- `tlp-nvidia-compute-only.conf`: TLP runtime PM allow-list for NVIDIA PCI functions.
- `setup-nvidia-hybrid-compute.sh`: requests Hybrid mode without pinning Hyprland to the dGPU.
- `test-nvidia-compute.sh`: non-destructive status check.
- `diagnose-nvidia-power.sh`: quick power-state evidence collection.

## Apply Carefully

For the user environment path:

```bash
mkdir -p ~/.config/environment.d
cp 91-igpu-gui-stack.conf ~/.config/environment.d/
```

For Hyprland-only environment variables, copy the `env = ...` lines from `hypr-env.snippet` into your Hyprland env config.

If Hyprland is launched through `wayland-wm@hyprland.desktop.service`, install
the unit drop-in so the compositor itself starts on Mesa:

```bash
mkdir -p ~/.config/systemd/user/wayland-wm@hyprland.desktop.service.d
cp 10-force-mesa-egl.conf ~/.config/systemd/user/wayland-wm@hyprland.desktop.service.d/
systemctl --user daemon-reload
```

For system-level NVIDIA templates, inspect first. They require root and may conflict with `supergfxd` generated config:

```bash
sudo install -m 0644 nvidia-compute.conf /etc/modprobe.d/nvidia-compute.conf
sudo install -m 0644 tlp-nvidia-compute-only.conf /etc/tlp.d/02-nvidia-compute-only.conf
```

Only use `zz-nvidia-compute-only.conf.template` if you intentionally want strict compute-only behavior and understand that blocking `nvidia_drm`/`nvidia_modeset` can break NVIDIA display offload.

## Verify

```bash
./test-nvidia-compute.sh
./diagnose-nvidia-power.sh
```

Good idle evidence on the source workstation was `supergfxctl -S` showing `suspended` and `/sys/bus/pci/devices/0000:01:00.0/power/runtime_status` showing `suspended`.

To confirm the Hyprland unit drop-in was loaded:

```bash
systemctl --user cat 'wayland-wm@hyprland.desktop.service'
systemctl --user show 'wayland-wm@hyprland.desktop.service' -p Environment
```
