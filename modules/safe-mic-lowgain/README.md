# Safe Mic Low Gain

Creates a PipeWire filter-chain virtual microphone with reduced gain. This is useful when a hardware microphone clips or remote calls sound overdriven.

## Dependencies

- PipeWire
- WirePlumber
- `jq`
- `wpctl`
- `pactl`
- systemd user services

## Files

- `safe-mic-lowgain-filter.conf.template`: PipeWire filter-chain config.
- `safe-mic-lowgain.service`: user service that starts the filter chain.
- `safe-mic-set-default`: helper that waits for the virtual source and sets it as default.

## Apply

Copy files:

```bash
mkdir -p ~/.config/pipewire ~/.config/systemd/user ~/.local/bin
cp safe-mic-lowgain-filter.conf.template ~/.config/pipewire/safe-mic-lowgain-filter.conf
cp safe-mic-lowgain.service ~/.config/systemd/user/safe-mic-lowgain.service
cp safe-mic-set-default ~/.local/bin/safe-mic-set-default
chmod +x ~/.local/bin/safe-mic-set-default
```

Edit `node.target` in `~/.config/pipewire/safe-mic-lowgain-filter.conf` to your real microphone source. Find candidates with:

```bash
wpctl status
pactl list short sources
```

Then enable:

```bash
systemctl --user daemon-reload
systemctl --user enable --now safe-mic-lowgain.service
```

## Default Gain

The template uses `0.70` on both channels, matching the stable local setting from the source workstation. Adjust both `Gain 1` values if needed.
