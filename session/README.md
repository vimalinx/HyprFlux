# Session startup

`hyprflux-session-start.sh` is installed by `./install.sh` to:

`~/.config/hypr/UserScripts/hyprflux-session-start.sh`

Hyprland should source:

```conf
source = $UserConfigs/HyprFluxStartup.conf
```

Behavior:

- Detects ASUS vs generic.
- Starts shared helpers (clipboard, wallpaper daemon, enabled mic units).
- Never auto-starts the ASUS power stack on non-ASUS machines.
- Interactive / `HYPRFLUX_FORCE_UI=1`: pretty terminal banner.
- Hyprland `exec-once` (non-TTY): compact `notify-send` splash.
