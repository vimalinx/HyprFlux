# Hypr Session Button

Desktop session save / restore helper for Hyprland + Waybar, extracted from the live workstation and also published as [vimalinx/hypr-session-button](https://github.com/vimalinx/hypr-session-button).

## Files

- `HyprSessionButton.py`
- `hypr-desktop-session-autosave.service`
- `hypr-desktop-session-autosave.timer`

## Apply

```bash
cp HyprSessionButton.py ~/.config/hypr/UserScripts/
chmod +x ~/.config/hypr/UserScripts/HyprSessionButton.py
cp hypr-desktop-session-autosave.service hypr-desktop-session-autosave.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now hypr-desktop-session-autosave.timer
```

Prefer the dedicated repo when you only want this feature.
