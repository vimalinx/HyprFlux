# Fcitx WeChat Scale

Hyprland helper that increases the Fcitx5 classic UI font only while WeChat is focused.

This fixes tiny candidate windows on scaled displays without globally enlarging input-method UI for every app.

## Files

- `FcitxWechatCandidateScale.sh`: watches Hyprland focus events and rewrites Fcitx5 classic UI font.
- `wechat-hidpi`: launches native WeChat with monitor-aware Qt scaling and focuses an existing WeChat window if present.
- `startup.snippet`: Hyprland startup command.
- `keybind.snippet`: optional WeChat launcher keybind.

## Apply

```bash
mkdir -p ~/.config/hypr/UserScripts ~/.local/bin
cp FcitxWechatCandidateScale.sh ~/.config/hypr/UserScripts/
cp wechat-hidpi ~/.local/bin/
chmod +x ~/.config/hypr/UserScripts/FcitxWechatCandidateScale.sh ~/.local/bin/wechat-hidpi
```

Add startup:

```text
exec-once = systemd-run --user --unit=fcitx-wechat-candidate-scale -E HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE -E XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR $UserScripts/FcitxWechatCandidateScale.sh --listener
```

## Tune

Edit the font variables in the script:

```bash
NORMAL_FONT='Adwaita Sans 10'
WECHAT_FONT='Adwaita Sans 18'
```
