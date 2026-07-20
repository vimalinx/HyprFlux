#!/usr/bin/env python3
"""
Waybar button backend for saving and restoring a Hyprland desktop session.

It restores launchable windows, their workspaces, and floating geometry. Tiled
windows are relaunched in saved workspace order because Hyprland does not expose
a stable full-layout restore primitive.
"""

from __future__ import annotations

import fcntl
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from configparser import ConfigParser
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


HOME = Path.home()
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state"))
STATE_DIR = STATE_HOME / "hypr"
SNAPSHOT_PATH = Path(os.environ.get("HYPR_SESSION_SNAPSHOT", STATE_DIR / "desktop-session-snapshot.json"))
LOCK_PATH = STATE_DIR / "desktop-session-button.lock"
LOG_PATH = STATE_DIR / "desktop-session-button.log"

HYPRCTL = shutil.which(os.environ.get("HYPRCTL_BIN", "hyprctl")) or "hyprctl"
GTK_LAUNCH = shutil.which("gtk-launch")
NOTIFY_SEND = shutil.which("notify-send")
TERMINAL = shutil.which(os.environ.get("HYPR_SESSION_TERMINAL", "foot")) or "foot"
SHELL = os.environ.get("SHELL", "/bin/zsh")
CURRENT_BOOT_ID = Path("/proc/sys/kernel/random/boot_id").read_text(encoding="utf-8").strip()
WECHAT_SUPER_W_FALLBACK = HOME / ".local/bin/wechat-hidpi"
CODEX_FALLBACK_BIN = HOME / ".config/nvm/versions/node/v25.5.0/bin/codex"
CLAUDE_FALLBACK_BIN = HOME / ".config/nvm/versions/node/v25.5.0/bin/claude"
CODEX_BIN = os.environ.get("CODEX_BIN") or shutil.which("codex") or str(CODEX_FALLBACK_BIN)
CLAUDE_BIN = os.environ.get("CLAUDE_BIN") or shutil.which("claude") or str(CLAUDE_FALLBACK_BIN)
CODEX_RESTORE_ARGV = [CODEX_BIN, "--dangerously-bypass-approvals-and-sandbox", "resume", "--last"]
CLAUDE_RESTORE_ARGV = [CLAUDE_BIN, "--dangerously-skip-permissions", "--continue"]
SNAPSHOT_BACKUP_DIR = STATE_DIR / "desktop-session-snapshots"
MAX_AUTOSAVE_BACKUPS = 72

SHELL_NAMES = {"bash", "dash", "fish", "sh", "zsh"}
IGNORED_TERMINAL_COMMANDS = {
    "awk",
    "cat",
    "head",
    "jq",
    "less",
    "nl",
    "rg",
    "sed",
    "tail",
    "tee",
    "tr",
}


@dataclass
class DesktopEntry:
    desktop_id: str
    path: Path
    name: str
    exec_line: str
    startup_wm_class: str


def log(message: str) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(f"{timestamp} {message}\n")


def notify(title: str, body: str) -> None:
    if not NOTIFY_SEND:
        return
    subprocess.run([NOTIFY_SEND, title, body], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def run(command: list[str], timeout: float = 8.0) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, timeout=timeout, check=False)


def hypr_json(*args: str) -> Any:
    result = run([HYPRCTL, *args, "-j"])
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"hyprctl {' '.join(args)} failed")
    return json.loads(result.stdout)


def waybar_json(text: str, tooltip: str, css_class: str, alt: str = "") -> None:
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class, "alt": alt}, ensure_ascii=False))


def load_snapshot() -> dict[str, Any] | None:
    if not SNAPSHOT_PATH.exists():
        return None
    try:
        with SNAPSHOT_PATH.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            return data
    except (OSError, json.JSONDecodeError):
        return None
    return None


def atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
        tmp_path = Path(handle.name)
    tmp_path.replace(path)


def backup_snapshot(reason: str) -> None:
    if not SNAPSHOT_PATH.exists():
        return
    try:
        existing = load_snapshot()
        if not existing:
            return
        SNAPSHOT_BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")
        target = SNAPSHOT_BACKUP_DIR / f"{timestamp}-{reason}.json"
        atomic_write_json(target, existing)
    except OSError as exc:
        log(f"snapshot backup failed: {exc}")


def prune_autosave_backups() -> None:
    if not SNAPSHOT_BACKUP_DIR.is_dir():
        return

    def modified_at(path: Path) -> float:
        try:
            return path.stat().st_mtime
        except OSError:
            return 0.0

    backups = sorted(SNAPSHOT_BACKUP_DIR.glob("*-before-autosave.json"), key=modified_at, reverse=True)
    for path in backups[MAX_AUTOSAVE_BACKUPS:]:
        try:
            path.unlink()
        except OSError as exc:
            log(f"autosave backup prune failed: {path}: {exc}")


def read_cmdline(pid: int) -> list[str]:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return []
    return [part.decode("utf-8", "replace") for part in raw.split(b"\0") if part]


def read_link(path: Path) -> str:
    try:
        return os.readlink(path)
    except OSError:
        return ""


def read_cwd(pid: int) -> str:
    return read_link(Path(f"/proc/{pid}/cwd")) or str(HOME)


def read_exe(pid: int) -> str:
    return read_link(Path(f"/proc/{pid}/exe"))


def read_process_table() -> tuple[dict[int, dict[str, Any]], dict[int, list[int]]]:
    result = run(["ps", "-eo", "pid=,ppid=,comm=,args="], timeout=5)
    processes: dict[int, dict[str, Any]] = {}
    children: dict[int, list[int]] = {}
    if result.returncode != 0:
        return processes, children

    for line in result.stdout.splitlines():
        parts = line.strip().split(None, 3)
        if len(parts) < 3:
            continue
        try:
            pid = int(parts[0])
            ppid = int(parts[1])
        except ValueError:
            continue
        comm = parts[2]
        args = parts[3] if len(parts) > 3 else ""
        processes[pid] = {"pid": pid, "ppid": ppid, "comm": comm, "args": args}
        children.setdefault(ppid, []).append(pid)
    return processes, children


def descendants(root_pid: int, children: dict[int, list[int]]) -> list[int]:
    queue = list(children.get(root_pid, []))
    found: list[int] = []
    while queue:
        pid = queue.pop(0)
        found.append(pid)
        queue.extend(children.get(pid, []))
    return found


def find_shell_child(root_pid: int, processes: dict[int, dict[str, Any]], children: dict[int, list[int]]) -> int | None:
    for child in children.get(root_pid, []):
        if processes.get(child, {}).get("comm") in SHELL_NAMES:
            return child
    return None


def find_terminal_target(root_pid: int, processes: dict[int, dict[str, Any]], children: dict[int, list[int]]) -> int | None:
    for pid in descendants(root_pid, children):
        comm = str(processes.get(pid, {}).get("comm", ""))
        if comm in SHELL_NAMES or comm in IGNORED_TERMINAL_COMMANDS:
            continue
        return pid
    return None


def load_tmux_tables() -> tuple[dict[int, str], dict[str, str]]:
    tmux = shutil.which("tmux")
    clients: dict[int, str] = {}
    cwds: dict[str, str] = {}
    if not tmux:
        return clients, cwds

    client_result = run([tmux, "list-clients", "-F", "#{client_pid}|#{session_name}"], timeout=3)
    if client_result.returncode == 0:
        for line in client_result.stdout.splitlines():
            pid_text, _, session = line.partition("|")
            try:
                pid = int(pid_text)
            except ValueError:
                continue
            if session:
                clients[pid] = session

    pane_result = run([tmux, "list-panes", "-a", "-F", "#{session_name}|#{?pane_active,1,0}|#{pane_current_path}"], timeout=3)
    if pane_result.returncode == 0:
        for line in pane_result.stdout.splitlines():
            session, _, rest = line.partition("|")
            active, _, cwd = rest.partition("|")
            if session and cwd and (active == "1" or session not in cwds):
                cwds[session] = cwd
    return clients, cwds


def desktop_search_dirs() -> list[Path]:
    dirs = [
        HOME / ".local/share/applications",
        Path("/usr/local/share/applications"),
        Path("/usr/share/applications"),
        Path("/var/lib/flatpak/exports/share/applications"),
        HOME / ".local/share/flatpak/exports/share/applications",
    ]
    return [path for path in dirs if path.is_dir()]


def desktop_id_from_path(path: Path, root: Path) -> str:
    try:
        relative = path.relative_to(root)
    except ValueError:
        return path.name
    return str(relative).replace("/", "-")


def load_desktop_entries() -> list[DesktopEntry]:
    entries: list[DesktopEntry] = []
    for root in desktop_search_dirs():
        for path in root.rglob("*.desktop"):
            parser = ConfigParser(interpolation=None)
            parser.optionxform = str
            try:
                parser.read(path, encoding="utf-8")
            except Exception:
                continue
            if not parser.has_section("Desktop Entry"):
                continue
            section = parser["Desktop Entry"]
            if section.get("Type", "Application") != "Application":
                continue
            if section.get("NoDisplay", "").lower() == "true" and "StartupWMClass" not in section:
                continue
            exec_line = section.get("Exec", "").strip()
            if not exec_line:
                continue
            entries.append(
                DesktopEntry(
                    desktop_id=desktop_id_from_path(path, root),
                    path=path,
                    name=section.get("Name", "").strip(),
                    exec_line=exec_line,
                    startup_wm_class=section.get("StartupWMClass", "").strip(),
                )
            )
    return entries


def first_exec_token(exec_line: str) -> str:
    try:
        parts = shlex.split(strip_desktop_field_codes(exec_line))
    except ValueError:
        parts = exec_line.split()
    return Path(parts[0]).name.lower() if parts else ""


def strip_desktop_field_codes(exec_line: str) -> str:
    return re.sub(r"\s*%[fFuUdDnNickvm]", "", exec_line).strip()


def find_desktop_entry(client: dict[str, Any], exe: str, entries: list[DesktopEntry]) -> DesktopEntry | None:
    candidates = {str(client.get("class", "")), str(client.get("initialClass", ""))}
    candidates = {value.lower() for value in candidates if value}
    exe_base = Path(exe).name.lower() if exe else ""

    best_score = 0
    best_entry: DesktopEntry | None = None
    for entry in entries:
        stem = entry.desktop_id.removesuffix(".desktop").lower()
        name = entry.name.lower()
        startup = entry.startup_wm_class.lower()
        exec_base = first_exec_token(entry.exec_line)

        score = 0
        if startup and startup in candidates:
            score = 100
        elif stem in candidates:
            score = 90
        elif name in candidates:
            score = 80
        elif exe_base and exec_base == exe_base:
            score = 70
        elif any(candidate and candidate in stem for candidate in candidates):
            score = 45
        elif any(candidate and candidate in exec_base for candidate in candidates):
            score = 35

        if score > best_score:
            best_score = score
            best_entry = entry
    return best_entry


def desktop_launch_command(entry: DesktopEntry) -> str:
    if GTK_LAUNCH:
        desktop_name = entry.desktop_id.removesuffix(".desktop")
        return shlex.join([GTK_LAUNCH, desktop_name])
    return strip_desktop_field_codes(entry.exec_line)


def super_w_wechat_command() -> str:
    result = run([HYPRCTL, "binds", "-j"], timeout=5)
    if result.returncode == 0:
        try:
            binds = json.loads(result.stdout)
        except json.JSONDecodeError:
            binds = []
        for bind in binds if isinstance(binds, list) else []:
            if (
                str(bind.get("key") or "").upper() == "W"
                and int(bind.get("modmask") or 0) == 64
                and str(bind.get("dispatcher") or "") == "exec"
                and not bind.get("mouse")
                and not bind.get("submap")
                and bind.get("arg")
            ):
                return str(bind["arg"])

    if WECHAT_SUPER_W_FALLBACK.exists():
        return str(WECHAT_SUPER_W_FALLBACK)
    return "/opt/wechat/wechat"


def stable_key(*parts: Any) -> str:
    import hashlib

    raw = "|".join(str(part or "") for part in parts)
    return hashlib.sha1(raw.encode("utf-8", "replace")).hexdigest()[:12]


def is_codex_cmdline(argv: list[str]) -> bool:
    return any(Path(arg).name == "codex" for arg in argv)


def is_claude_cmdline(argv: list[str]) -> bool:
    return any(Path(arg).name == "claude" for arg in argv)


def foot_launch(client: dict[str, Any], processes: dict[int, dict[str, Any]], children: dict[int, list[int]], tmux_clients: dict[int, str], tmux_cwds: dict[str, str]) -> dict[str, Any]:
    pid = int(client.get("pid") or 0)
    title = str(client.get("title") or "Foot")
    tag = str(client.get("xdgTag") or "") or f"hypr-session-foot-{stable_key(client.get('workspace', {}).get('name'), title, pid)}"
    shell_pid = find_shell_child(pid, processes, children)
    cwd = read_cwd(shell_pid or pid)

    for descendant_pid in descendants(pid, children):
        session = tmux_clients.get(descendant_pid)
        if not session:
            continue
        cwd = tmux_cwds.get(session) or read_cwd(descendant_pid) or cwd
        inner = "exec " + shlex.join(["tmux", "new-session", "-A", "-s", session])
        cmd = shlex.join([TERMINAL, "--toplevel-tag", tag, "-T", f"tmux:{session}", "-D", cwd, SHELL, "-lc", inner])
        return {"type": "foot-tmux", "cmd": cmd, "cwd": cwd, "tag": tag, "session": session}

    target_pid = find_terminal_target(pid, processes, children)
    if target_pid:
        target_cmdline = read_cmdline(target_pid)
        target_cwd = read_cwd(target_pid)
        if target_cmdline:
            if is_codex_cmdline(target_cmdline):
                inner = "exec " + shlex.join(CODEX_RESTORE_ARGV)
                cmd = shlex.join([TERMINAL, "--toplevel-tag", tag, "-T", title, "-D", target_cwd, SHELL, "-lc", inner])
                return {
                    "type": "foot-codex",
                    "cmd": cmd,
                    "cwd": target_cwd,
                    "tag": tag,
                    "argv": CODEX_RESTORE_ARGV,
                    "source_argv": target_cmdline,
                }

            if is_claude_cmdline(target_cmdline):
                inner = "exec " + shlex.join(CLAUDE_RESTORE_ARGV)
                cmd = shlex.join([TERMINAL, "--toplevel-tag", tag, "-T", title, "-D", target_cwd, SHELL, "-lc", inner])
                return {
                    "type": "foot-claude",
                    "cmd": cmd,
                    "cwd": target_cwd,
                    "tag": tag,
                    "argv": CLAUDE_RESTORE_ARGV,
                    "source_argv": target_cmdline,
                }

            inner = "exec " + shlex.join(target_cmdline)
            cmd = shlex.join([TERMINAL, "--toplevel-tag", tag, "-T", title, "-D", target_cwd, SHELL, "-lc", inner])
            return {"type": "foot-command", "cmd": cmd, "cwd": target_cwd, "tag": tag, "argv": target_cmdline}

    cmd = shlex.join([TERMINAL, "--toplevel-tag", tag, "-T", title, "-D", cwd])
    return {"type": "foot-shell", "cmd": cmd, "cwd": cwd, "tag": tag}


def generic_launch(client: dict[str, Any], entries: list[DesktopEntry]) -> dict[str, Any] | None:
    pid = int(client.get("pid") or 0)
    exe = read_exe(pid)
    cmdline = read_cmdline(pid)
    window_classes = {str(client.get("class") or "").lower(), str(client.get("initialClass") or "").lower()}
    if "wechat" in window_classes:
        return {
            "type": "super-w-wechat",
            "cmd": super_w_wechat_command(),
            "cwd": str(HOME),
            "source": "SUPER+W",
        }

    entry = find_desktop_entry(client, exe, entries)
    if entry:
        return {
            "type": "desktop",
            "cmd": desktop_launch_command(entry),
            "desktop_id": entry.desktop_id,
            "desktop_file": str(entry.path),
            "cwd": str(HOME),
        }

    if cmdline and not any(arg.startswith("--type=") for arg in cmdline):
        first = cmdline[0]
        if first.startswith("/") and Path(first).exists():
            return {"type": "cmdline", "cmd": shlex.join(cmdline), "cwd": read_cwd(pid), "argv": cmdline}
        if shutil.which(first):
            return {"type": "cmdline", "cmd": shlex.join(cmdline), "cwd": read_cwd(pid), "argv": cmdline}

    if exe and Path(exe).exists():
        return {"type": "executable", "cmd": shlex.join([exe]), "cwd": read_cwd(pid)}

    return None


def build_client_entry(client: dict[str, Any], launch: dict[str, Any]) -> dict[str, Any]:
    workspace = client.get("workspace") if isinstance(client.get("workspace"), dict) else {}
    return {
        "address": client.get("address"),
        "pid": client.get("pid"),
        "class": client.get("class") or "",
        "initialClass": client.get("initialClass") or "",
        "title": client.get("title") or "",
        "workspace": {"id": workspace.get("id"), "name": workspace.get("name")},
        "monitor": client.get("monitor"),
        "floating": bool(client.get("floating")),
        "at": client.get("at") or [],
        "size": client.get("size") or [],
        "fullscreen": client.get("fullscreen") or 0,
        "pinned": bool(client.get("pinned")),
        "xdgTag": client.get("xdgTag") or "",
        "launch": launch,
        "identity": stable_key(client.get("class"), client.get("initialClass"), client.get("title"), workspace.get("name"), launch.get("cmd")),
    }


def save_snapshot(*, notify_user: bool = True, backup_reason: str = "before-save", log_action: str = "saved") -> dict[str, Any]:
    clients = hypr_json("clients")
    active_workspace = hypr_json("activeworkspace")
    monitors = hypr_json("monitors")
    processes, children = read_process_table()
    tmux_clients, tmux_cwds = load_tmux_tables()
    desktop_entries = load_desktop_entries()
    saved: list[dict[str, Any]] = []
    skipped: list[dict[str, str]] = []

    for client in sorted(clients, key=lambda item: (item.get("workspace", {}).get("id", 0), item.get("at", [0, 0])[1], item.get("at", [0, 0])[0])):
        if not client.get("mapped", True) or client.get("hidden", False):
            continue
        window_class = str(client.get("class") or "")
        pid = int(client.get("pid") or 0)
        if not window_class or pid <= 0:
            skipped.append({"class": window_class, "title": str(client.get("title") or ""), "reason": "missing class or pid"})
            continue

        try:
            if window_class.lower() in {"foot", "footclient"}:
                launch = foot_launch(client, processes, children, tmux_clients, tmux_cwds)
            else:
                launch = generic_launch(client, desktop_entries)
        except Exception as exc:
            skipped.append({"class": window_class, "title": str(client.get("title") or ""), "reason": str(exc)})
            continue

        if not launch:
            skipped.append({"class": window_class, "title": str(client.get("title") or ""), "reason": "no launch command"})
            continue
        saved.append(build_client_entry(client, launch))

    snapshot = {
        "schema": 1,
        "saved_at": datetime.now().astimezone().isoformat(timespec="seconds"),
        "boot_id": CURRENT_BOOT_ID,
        "active_workspace": active_workspace,
        "monitors": monitors,
        "clients": saved,
        "skipped": skipped,
    }
    backup_snapshot(backup_reason)
    atomic_write_json(SNAPSHOT_PATH, snapshot)
    log(f"{log_action} {len(saved)} windows, skipped {len(skipped)}")
    if notify_user:
        notify("桌面会话已保存", f"已保存 {len(saved)} 个窗口。重启后点顶栏按钮即可恢复。")
    return snapshot


def autosave_snapshot() -> dict[str, Any] | None:
    snapshot = load_snapshot()
    if snapshot and snapshot.get("boot_id") != CURRENT_BOOT_ID and snapshot.get("last_restored_boot_id") != CURRENT_BOOT_ID:
        clients = snapshot.get("clients", [])
        count = len(clients) if isinstance(clients, list) else 0
        saved_at = str(snapshot.get("saved_at") or "unknown")
        log(f"autosave skipped: previous-boot snapshot pending restore ({saved_at}, {count} windows)")
        return None

    try:
        saved = save_snapshot(notify_user=False, backup_reason="before-autosave", log_action="autosaved")
        prune_autosave_backups()
        return saved
    except Exception as exc:
        log(f"autosave failed: {exc}")
        return None


def client_matches_saved(current: dict[str, Any], saved: dict[str, Any]) -> bool:
    current_workspace = current.get("workspace", {}) if isinstance(current.get("workspace"), dict) else {}
    saved_workspace = saved.get("workspace", {}) if isinstance(saved.get("workspace"), dict) else {}
    saved_tag = saved.get("launch", {}).get("tag") or saved.get("xdgTag")
    if saved_tag and current.get("xdgTag") == saved_tag:
        return True
    return (
        str(current.get("class") or "").lower() == str(saved.get("class") or "").lower()
        and str(current_workspace.get("name") or "") == str(saved_workspace.get("name") or "")
        and str(current.get("title") or "") == str(saved.get("title") or "")
    )


def wait_for_new_client(previous_addresses: set[str], saved: dict[str, Any], timeout: float = 10.0) -> dict[str, Any] | None:
    deadline = time.monotonic() + timeout
    best: dict[str, Any] | None = None
    while time.monotonic() < deadline:
        try:
            clients = hypr_json("clients")
        except Exception:
            time.sleep(0.25)
            continue
        new_clients = [client for client in clients if client.get("address") not in previous_addresses]
        if new_clients:
            saved_class = str(saved.get("class") or "").lower()
            saved_initial = str(saved.get("initialClass") or "").lower()
            saved_title = str(saved.get("title") or "")
            saved_workspace = saved.get("workspace", {}) if isinstance(saved.get("workspace"), dict) else {}
            saved_workspace_name = str(saved_workspace.get("name") or "")

            def score(client: dict[str, Any]) -> int:
                workspace = client.get("workspace", {}) if isinstance(client.get("workspace"), dict) else {}
                value = 0
                if str(client.get("class") or "").lower() == saved_class:
                    value += 50
                if str(client.get("initialClass") or "").lower() == saved_initial:
                    value += 30
                if saved_title and str(client.get("title") or "") == saved_title:
                    value += 20
                if str(workspace.get("name") or "") == saved_workspace_name:
                    value += 10
                return value

            best = max(new_clients, key=score)
            if score(best) > 0:
                return best
            return best
        time.sleep(0.25)
    return best


def apply_geometry(client: dict[str, Any], saved: dict[str, Any]) -> None:
    address = str(client.get("address") or "")
    if not address:
        return
    selector = f"address:{address}"

    if saved.get("floating"):
        run([HYPRCTL, "dispatch", "setfloating", selector], timeout=3)
        size = saved.get("size") or []
        at = saved.get("at") or []
        if len(size) == 2:
            run([HYPRCTL, "dispatch", "resizewindowpixel", f"exact {int(size[0])} {int(size[1])},{selector}"], timeout=3)
        if len(at) == 2:
            run([HYPRCTL, "dispatch", "movewindowpixel", f"exact {int(at[0])} {int(at[1])},{selector}"], timeout=3)


def restore_snapshot(dry_run: bool = False) -> tuple[int, int, int]:
    snapshot = load_snapshot()
    if not snapshot:
        notify("没有保存的桌面会话", "先点一次顶栏按钮保存当前窗口。")
        return (0, 0, 0)

    saved_clients = [item for item in snapshot.get("clients", []) if isinstance(item, dict) and item.get("launch", {}).get("cmd")]
    current_clients = hypr_json("clients") if not dry_run else []
    previous_addresses = {str(client.get("address")) for client in current_clients if client.get("address")}
    restored = 0
    skipped = 0
    failed = 0

    for saved in saved_clients:
        if any(client_matches_saved(current, saved) for current in current_clients):
            skipped += 1
            continue

        workspace = saved.get("workspace", {}) if isinstance(saved.get("workspace"), dict) else {}
        workspace_name = str(workspace.get("name") or workspace.get("id") or "1")
        command = str(saved.get("launch", {}).get("cmd") or "")
        if dry_run:
            print(f"[{workspace_name}] {saved.get('class')} | {saved.get('title')} -> {command}")
            continue

        result = run([HYPRCTL, "dispatch", "exec", f"[workspace {workspace_name} silent] {command}"], timeout=5)
        if result.returncode != 0:
            failed += 1
            log(f"restore dispatch failed: {saved.get('class')} {saved.get('title')} {result.stderr.strip()}")
            continue

        new_client = wait_for_new_client(previous_addresses, saved)
        if new_client:
            previous_addresses.add(str(new_client.get("address")))
            current_clients.append(new_client)
            apply_geometry(new_client, saved)
        restored += 1
        time.sleep(0.35)

    if not dry_run:
        active_workspace = snapshot.get("active_workspace", {})
        if isinstance(active_workspace, dict):
            name = str(active_workspace.get("name") or active_workspace.get("id") or "")
            if name:
                run([HYPRCTL, "dispatch", "workspace", name], timeout=3)
        snapshot["last_restored_boot_id"] = CURRENT_BOOT_ID
        snapshot["last_restored_at"] = datetime.now().astimezone().isoformat(timespec="seconds")
        atomic_write_json(SNAPSHOT_PATH, snapshot)
        log(f"restored {restored} windows, skipped {skipped}, failed {failed}")
        notify("桌面会话恢复完成", f"已恢复 {restored} 个窗口，跳过 {skipped} 个，失败 {failed} 个。")
    return restored, skipped, failed


def status() -> None:
    snapshot = load_snapshot()
    if not snapshot:
        waybar_json("", "桌面会话：未保存\n左键：保存当前窗口\n中键：恢复上次保存", "empty", "empty")
        return

    clients = snapshot.get("clients", [])
    count = len(clients) if isinstance(clients, list) else 0
    saved_at = str(snapshot.get("saved_at") or "unknown")
    saved_boot = str(snapshot.get("boot_id") or "")
    restored_boot = str(snapshot.get("last_restored_boot_id") or "")
    skipped = snapshot.get("skipped", [])
    skipped_count = len(skipped) if isinstance(skipped, list) else 0

    if saved_boot != CURRENT_BOOT_ID:
        restore_note = "\n状态：本次开机已恢复过，可再次左键重放" if restored_boot == CURRENT_BOOT_ID else ""
        waybar_json(
            f"󰑓 {count}",
            f"桌面会话：可恢复\n保存时间：{saved_at}\n窗口：{count}，未支持：{skipped_count}{restore_note}\n左键：恢复\n右键：另存当前窗口",
            "restore",
            "restore",
        )
        return

    waybar_json(
        f" {count}",
        f"桌面会话：已保存\n保存时间：{saved_at}\n窗口：{count}，未支持：{skipped_count}\n左键/右键：保存当前窗口\n中键：恢复上次保存",
        "saved",
        "saved",
    )


def toggle() -> None:
    snapshot = load_snapshot()
    if snapshot and snapshot.get("boot_id") != CURRENT_BOOT_ID:
        restore_snapshot()
    else:
        save_snapshot()


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    if action == "status":
        status()
        return 0

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with LOCK_PATH.open("w", encoding="utf-8") as lock_handle:
        fcntl.flock(lock_handle, fcntl.LOCK_EX)
        if action in {"save", "snapshot"}:
            save_snapshot()
        elif action == "restore":
            restore_snapshot()
        elif action == "dry-run":
            restore_snapshot(dry_run=True)
        elif action == "autosave":
            autosave_snapshot()
        elif action == "toggle":
            toggle()
        else:
            print("usage: HyprSessionButton.py [status|toggle|save|restore|dry-run|autosave]", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
