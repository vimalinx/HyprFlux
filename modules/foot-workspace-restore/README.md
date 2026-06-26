# Foot Workspace Restore

Optional Hyprland helpers for restoring selected foot/tmux windows to workspaces after login.

This module is disabled by default in the source workstation because automatic restore increased login-time startup and memory pressure. Treat it as an opt-in power-user module.

## Dependencies

- Hyprland `hyprctl`
- `foot`
- `tmux`
- `jq`
- `rg`
- `ps`

## Files

- `RestoreTmuxWorkspaces.sh`: launches mapped tmux sessions and previously saved foot windows.
- `SaveFootWorkspaceSnapshot.sh`: records selected foot windows to a state JSON file.
- `FootWorkspaceSnapshotDaemon.sh`: periodically refreshes that snapshot.
- `tmux-workspaces.conf.example`: maps Hyprland workspaces to tmux session names.
- `foot-workspace-allowlist.conf`: process allowlist for snapshot restore.

## Apply

Copy files to your Hyprland user scripts directory:

```bash
mkdir -p ~/.config/hypr/UserScripts
cp RestoreTmuxWorkspaces.sh SaveFootWorkspaceSnapshot.sh FootWorkspaceSnapshotDaemon.sh ~/.config/hypr/UserScripts/
cp tmux-workspaces.conf.example ~/.config/hypr/UserScripts/tmux-workspaces.conf
cp foot-workspace-allowlist.conf ~/.config/hypr/UserScripts/foot-workspace-allowlist.conf
chmod +x ~/.config/hypr/UserScripts/*.sh
```

Then add these only if you accept the startup cost:

```text
exec-once = $UserScripts/RestoreTmuxWorkspaces.sh
exec-once = $UserScripts/FootWorkspaceSnapshotDaemon.sh
```

## Disable

Comment both `exec-once` lines and restart the Hyprland session.
