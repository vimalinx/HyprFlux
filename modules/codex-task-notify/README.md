# Codex Task Notify

This module connects HyprFlux to the standalone Codex completion notifier:

```text
https://github.com/vimalinx/codex-task-notify
```

The notifier receives Codex's `notify` payload, filters for turn-completion events, and sends a desktop notification that includes the project name, working directory, and Hyprland workspace when it can be detected.

## Install

Install or clone the notifier:

```bash
git clone https://github.com/vimalinx/codex-task-notify.git ~/Projects/codex-task-notify
```

Then add a `notify` command to `~/.codex/config.toml`:

```toml
notify = ["/home/YOU/Projects/codex-task-notify/codex-task-notify"]
```

If you clone to a different location, update the path.

## Test

```bash
/home/YOU/Projects/codex-task-notify/codex-task-notify --test
```

## Why It Is Separate

The notifier is a real program with its own tests and release lifecycle. HyprFlux only records how it fits into the desktop collection.
