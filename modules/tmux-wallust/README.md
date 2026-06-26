# Tmux Wallust Theme

Small tmux setup for a low-noise status line that follows the current Kitty/Wallust palette.

## Behavior

- Reads colors from `~/.config/kitty/kitty-colors.conf`.
- Falls back to built-in colors if the palette file is missing.
- Avoids expensive shell status commands.
- Keeps `status-interval` at `15` instead of very frequent redraws.
- Uses tmux's built-in basename formatter for automatic window names.

## Apply

Copy the script:

```bash
mkdir -p ~/.config/tmux
cp apply-wallust-theme.sh ~/.config/tmux/apply-wallust-theme.sh
chmod +x ~/.config/tmux/apply-wallust-theme.sh
```

Merge `tmux.conf.snippet` into `~/.tmux.conf`.

Reload tmux:

```bash
tmux source-file ~/.tmux.conf
```
