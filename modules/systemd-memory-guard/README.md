# Systemd Memory Guard

User-level `systemd-oomd` pressure limits for desktop sessions.

This module keeps browser, Electron, and other app workloads under `app.slice`
from pushing the whole Wayland session into kernel OOM first, while giving
terminal/session workloads more headroom under `session.slice`.

Treat these values as policy templates. They can kill memory-heavy apps when the
machine is under sustained pressure.

## Files

- `app.slice-memory-guard.conf`: stricter pressure limits for GUI app workloads.
- `session.slice-memory-guard.conf`: wider headroom for the interactive session.

## Apply

```bash
install -D -m 0644 app.slice-memory-guard.conf \
  ~/.config/systemd/user/app.slice.d/10-memory-guard.conf

install -D -m 0644 session.slice-memory-guard.conf \
  ~/.config/systemd/user/session.slice.d/10-memory-guard.conf

systemctl --user daemon-reload
```

The policy applies to newly started units and slice members. Restart affected
apps or log out and back in if you need full coverage.

## Verify

```bash
systemctl --user cat app.slice
systemctl --user cat session.slice
systemctl --user show app.slice -p MemoryHigh -p ManagedOOMMemoryPressure
systemctl --user show session.slice -p MemoryHigh -p ManagedOOMMemoryPressure
```

## Tune

- Lower `MemoryHigh` if browser/Electron workloads should be pressured earlier.
- Raise `ManagedOOMMemoryPressureLimit` or duration if oomd is too aggressive.
- Remove the drop-ins and run `systemctl --user daemon-reload` to revert.
