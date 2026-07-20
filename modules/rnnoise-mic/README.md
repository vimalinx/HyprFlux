# RNNoise Microphone

PipeWire filter-chain that builds an RNNoise virtual microphone on top of the low-gain safe mic stack.

## Files

- `rnnoise-mic-filter.conf`: PipeWire filter graph.
- `rnnoise-mic.service.template`: user systemd unit (`LADSPA_PATH=%h/.local/lib/ladspa`).

## Requirements

- `librnnoise_ladspa` installed where PipeWire can load it (often `~/.local/lib/ladspa`).
- `safe-mic-lowgain` module applied first.

## Apply

```bash
mkdir -p ~/.config/pipewire ~/.config/systemd/user
cp rnnoise-mic-filter.conf ~/.config/pipewire/
cp rnnoise-mic.service.template ~/.config/systemd/user/rnnoise-mic.service
systemctl --user daemon-reload
systemctl --user enable --now rnnoise-mic.service
```

## Verify

```bash
pactl list sources short | grep -i rnnoise
systemctl --user status rnnoise-mic.service
```
