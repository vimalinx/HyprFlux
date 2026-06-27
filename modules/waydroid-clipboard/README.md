# Waydroid Clipboard

Small host-to-Waydroid paste bridge using ADB Keyboard.

## Behavior

- Reads text from `wl-paste` or stdin.
- Enables and selects `com.android.adbkeyboard/.AdbIME`.
- Sends the text as base64 through the ADB Keyboard broadcast.

This is intentionally limited to paste/type. Larger Waydroid networking, camera, and app-specific bootstrapping scripts are not included because they are more host-specific and often require sudo/network policy decisions.

## Apply

```bash
mkdir -p ~/.local/bin
cp waydroid-type waydroid-paste ~/.local/bin/
chmod +x ~/.local/bin/waydroid-type ~/.local/bin/waydroid-paste
```

Set the target if needed:

```bash
export WAYDROID_ADB_TARGET=192.168.240.2:5555
```

## Keybind

```text
bind = $mainMod ALT, V, exec, $HOME/.local/bin/waydroid-paste
```

## Dependencies

- `adb`
- `wl-paste`
- ADB Keyboard installed inside Waydroid
