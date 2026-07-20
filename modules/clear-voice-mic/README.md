# Clear Voice Microphone

PipeWire WebRTC echo-cancel / noise-suppression virtual microphone.

## Files

- `clear-voice-mic-webrtc.conf.template`: filter config with a placeholder capture target.
- `clear-voice-mic.service`: user systemd unit.

## Apply

1. Find your capture source: `pactl list sources short`.
2. Replace `REPLACE_WITH_YOUR_ALSA_SOURCE` in the template.
3. Install:

```bash
mkdir -p ~/.config/pipewire ~/.config/systemd/user
cp clear-voice-mic-webrtc.conf.template ~/.config/pipewire/clear-voice-mic-webrtc.conf
# edit node.target in that file
cp clear-voice-mic.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now clear-voice-mic.service
```

Only enable one of `rnnoise-mic` or `clear-voice-mic` as the default mic at a time unless you intentionally manage both.
