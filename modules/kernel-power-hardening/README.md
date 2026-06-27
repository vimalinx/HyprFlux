# Kernel Power And Hardening

Small modprobe templates for laptop power saving and unused network protocol
hardening.

These are system-level examples. Inspect them before installing because kernel
module options affect all users and can require a reboot or module reload.

## Files

- `audio-powersave.conf`: enables HDA Intel audio power save after idle time.
- `iwlwifi-powersave.conf`: enables Intel Wi-Fi powersave defaults.
- `rare-network-protocol-blacklist.conf`: disables rarely used network protocol
  modules such as DCCP, SCTP, RDS, TIPC, and N_HDLC.

## Apply

```bash
sudo install -m 0644 audio-powersave.conf /etc/modprobe.d/audio-powersave.conf
sudo install -m 0644 iwlwifi-powersave.conf /etc/modprobe.d/iwlwifi-powersave.conf
sudo install -m 0644 rare-network-protocol-blacklist.conf /etc/modprobe.d/60-local-blacklist-rare-network.conf
```

Reboot, or reload affected modules only if you know no active device depends on
them.

## Verify

```bash
systool -vm snd_hda_intel 2>/dev/null | rg 'power_save|power_save_controller'
systool -vm iwlwifi 2>/dev/null | rg 'power_save'
lsmod | rg '^(dccp|sctp|rds|tipc|n_hdlc)\b' || true
```

## Caveats

- Audio power save can cause pops or delayed wakeup on some codecs.
- Wi-Fi powersave can reduce throughput or increase latency on weak networks.
- The blacklist can break niche networking workloads that intentionally use
  SCTP, DCCP, RDS, TIPC, or N_HDLC.
