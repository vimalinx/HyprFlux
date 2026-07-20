#!/usr/bin/env python3
"""
Named terminal-combination store + idempotent restore.

Stores multiple named combinations of terminal windows (foot, and the inner
command they run: tmux session / codex / claude / arbitrary command / bare
shell). Restore is idempotent — it only launches terminals that are missing
and never closes existing windows.

It imports and reuses the terminal-capture and idempotent-restore machinery
from HyprSessionButton.py without modifying that file. The panel calls this
via subcommands; `list` and every action emit a single-line JSON result.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

# Reuse the existing button's terminal-capture + idempotent-restore machinery
# (zero changes to HyprSessionButton.py). Resolved via sys.path[0] = this dir.
from HyprSessionButton import (  # noqa: E402
    HYPRCTL,
    STATE_DIR,
    apply_geometry,
    atomic_write_json,
    build_client_entry,
    foot_launch,
    hypr_json,
    load_tmux_tables,
    log,
    read_process_table,
    run,
    wait_for_new_client,
)

STORE_PATH = STATE_DIR / "terminal-combos.json"
LOCK_PATH = STATE_DIR / "terminal-combos.lock"
SCHEMA = 1
FOOT_CLASSES = {"foot", "footclient"}
# Maps foot_launch's launch.type -> summary bucket key.
TYPE_SUMMARY_KEYS = {
    "foot-tmux": "tmux",
    "foot-codex": "codex",
    "foot-claude": "claude",
    "foot-command": "command",
    "foot-shell": "shell",
}
RESTORE_PACE_SECONDS = 0.35
# Single-screen combos may be restored on any setup; dual-screen combos only
# when the current session has >= 2 monitors. Honors TERMINAL_COMBOS_FORCE_MODE
# for testing the eligibility path without replugging hardware.
DEFAULT_SNAPSHOT_PATH = STATE_DIR / "desktop-session-snapshot.json"


def current_monitor_mode() -> str:
    """Return 'single' (1 monitor) or 'dual' (>=2 monitors) for the live session."""
    forced = os.environ.get("TERMINAL_COMBOS_FORCE_MODE", "").strip().lower()
    if forced in ("single", "dual"):
        return forced
    try:
        monitors = hypr_json("monitors")
        return "dual" if isinstance(monitors, list) and len(monitors) >= 2 else "single"
    except Exception:  # noqa: BLE001 — fall back to permissive single
        return "single"


def combo_eligible(combo_mode: str, current_mode: str) -> bool:
    """Single-screen combos work anywhere; dual-screen combos need a dual session."""
    return combo_mode != "dual" or current_mode == "dual"


def current_foot_signatures(clients: list[dict[str, Any]] | None = None) -> dict[str, dict[str, str]]:
    """Per current foot client, the same (workspace, cwd, tag) that capture stores.

    Runs foot_launch so cwd is computed identically at capture and match time,
    making presence matching stable across dynamic window titles.
    """
    if clients is None:
        try:
            clients = hypr_json("clients")
        except Exception:  # noqa: BLE001
            return {}
    processes, children = read_process_table()
    tmux_clients, tmux_cwds = load_tmux_tables()
    out: dict[str, dict[str, str]] = {}
    for client in clients:
        if str(client.get("class") or "").lower() not in FOOT_CLASSES:
            continue
        if not client.get("mapped", True) or client.get("hidden", False):
            continue
        pid = int(client.get("pid") or 0)
        address = str(client.get("address") or "")
        if not address or pid <= 0:
            continue
        workspace = client.get("workspace", {}) if isinstance(client.get("workspace"), dict) else {}
        try:
            launch = foot_launch(client, processes, children, tmux_clients, tmux_cwds)
        except Exception:  # noqa: BLE001
            launch = {}
        out[address] = {
            "workspace": str(workspace.get("name") or workspace.get("id") or ""),
            "cwd": str((launch or {}).get("cwd") or ""),
            "tag": str(client.get("xdgTag") or ""),
        }
    return out


def foot_terminal_present(saved: dict[str, Any], signatures: dict[str, dict[str, str]]) -> bool:
    """Robust presence check for a saved foot terminal against current signatures.

    Prefers xdgTag match (windows launched via --toplevel-tag); falls back to
    workspace + working directory, which survives title changes.
    """
    launch = saved.get("launch") if isinstance(saved.get("launch"), dict) else {}
    saved_workspace = saved.get("workspace", {}) if isinstance(saved.get("workspace"), dict) else {}
    saved_tag = launch.get("tag") or saved.get("xdgTag")
    saved_cwd = launch.get("cwd")
    saved_ws_name = str(saved_workspace.get("name") or saved_workspace.get("id") or "")
    for signature in signatures.values():
        if saved_tag and signature.get("tag") == saved_tag:
            return True
        if saved_cwd and signature.get("workspace") == saved_ws_name and signature.get("cwd") == saved_cwd:
            return True
    return False


def _lock(exclusive: bool):
    """Acquire a flock on the combos lock file. Use as a context manager."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    handle = LOCK_PATH.open("a", encoding="utf-8")
    fcntl.flock(handle, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
    return handle


def _now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def load_store() -> dict[str, Any]:
    if not STORE_PATH.exists():
        return {"schema": SCHEMA, "combos": []}
    try:
        data = json.loads(STORE_PATH.read_text(encoding="utf-8"))
        if isinstance(data, dict) and isinstance(data.get("combos"), list):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return {"schema": SCHEMA, "combos": []}


def save_store(data: dict[str, Any]) -> None:
    atomic_write_json(STORE_PATH, data)


def capture_terminals() -> list[dict[str, Any]]:
    """Capture all mapped, non-hidden foot/footclient windows across every workspace."""
    clients = hypr_json("clients")
    processes, children = read_process_table()
    tmux_clients, tmux_cwds = load_tmux_tables()
    captured: list[dict[str, Any]] = []
    for client in clients:
        if not client.get("mapped", True) or client.get("hidden", False):
            continue
        window_class = str(client.get("class") or "")
        pid = int(client.get("pid") or 0)
        if window_class.lower() not in FOOT_CLASSES or pid <= 0:
            continue
        try:
            launch = foot_launch(client, processes, children, tmux_clients, tmux_cwds)
        except Exception as exc:  # noqa: BLE001 — capture is best-effort
            log(f"combos capture skip {window_class}: {exc}")
            continue
        if not launch:
            continue
        captured.append(build_client_entry(client, launch))
    return captured


def cmd_capture(name: str) -> dict[str, Any]:
    terminals = capture_terminals()
    with _lock(True):
        store = load_store()
        combos = store["combos"]
        entry = {"name": name, "saved_at": _now(), "mode": current_monitor_mode(), "terminals": terminals}
        for i, combo in enumerate(combos):
            if combo.get("name") == name:
                combos[i] = entry
                break
        else:
            combos.append(entry)
        save_store(store)
    log(f"combos captured '{name}': {len(terminals)} terminals")
    return {"success": True, "captured": len(terminals), "name": name}


def cmd_restore(name: str) -> dict[str, Any]:
    with _lock(True):
        store = load_store()
        combo = next((c for c in store["combos"] if c.get("name") == name), None)
    if not combo:
        return {"success": False, "error": f"组合 '{name}' 不存在"}

    combo_mode = str(combo.get("mode") or "single")
    if not combo_eligible(combo_mode, current_monitor_mode()):
        return {"success": False, "error": "双屏组合不能在单屏使用", "ineligible": True, "name": name}

    terminals = [
        t for t in combo.get("terminals", [])
        if isinstance(t, dict) and t.get("launch", {}).get("cmd")
    ]
    if not terminals:
        return {"success": True, "restored": 0, "skipped": 0, "failed": 0, "name": name}

    # The lock is released before the slow restore loop so concurrent captures/lists
    # are not blocked. Restore is idempotent by tag/class+workspace+title matching.
    current_clients = hypr_json("clients")
    foot_signatures = current_foot_signatures(current_clients)
    previous_addresses = {str(c.get("address")) for c in current_clients if c.get("address")}
    restored = skipped = failed = 0

    for saved in terminals:
        if foot_terminal_present(saved, foot_signatures):
            skipped += 1
            continue

        workspace = saved.get("workspace", {}) if isinstance(saved.get("workspace"), dict) else {}
        workspace_name = str(workspace.get("name") or workspace.get("id") or "1")
        command = str(saved.get("launch", {}).get("cmd") or "")
        result = run([HYPRCTL, "dispatch", "exec", f"[workspace {workspace_name} silent] {command}"], timeout=5)
        if result.returncode != 0:
            failed += 1
            log(f"combos restore dispatch failed: {saved.get('class')} {saved.get('title')} {result.stderr.strip()}")
            continue

        new_client = wait_for_new_client(previous_addresses, saved)
        if new_client:
            previous_addresses.add(str(new_client.get("address")))
            current_clients.append(new_client)
            apply_geometry(new_client, saved)
        restored += 1
        time.sleep(RESTORE_PACE_SECONDS)

    log(f"combos restored '{name}': +{restored} skipped {skipped} failed {failed}")
    return {"success": True, "restored": restored, "skipped": skipped, "failed": failed, "name": name}


def find_matching_address(saved: dict[str, Any], signatures: dict[str, dict[str, str]]) -> str:
    """Return the current foot client address matching a saved terminal, or '' if none open."""
    launch = saved.get("launch") if isinstance(saved.get("launch"), dict) else {}
    saved_workspace = saved.get("workspace", {}) if isinstance(saved.get("workspace"), dict) else {}
    saved_tag = launch.get("tag") or saved.get("xdgTag")
    saved_cwd = launch.get("cwd")
    saved_ws_name = str(saved_workspace.get("name") or saved_workspace.get("id") or "")
    if saved_tag:
        for address, signature in signatures.items():
            if signature.get("tag") == saved_tag:
                return address
    if saved_cwd and saved_ws_name:
        for address, signature in signatures.items():
            if signature.get("workspace") == saved_ws_name and signature.get("cwd") == saved_cwd:
                return address
    return ""


def cmd_open_terminal(name: str, index: int) -> dict[str, Any]:
    """Focus a combo's terminal if it's open, otherwise spawn just that one terminal."""
    with _lock(True):
        store = load_store()
        combo = next((c for c in store["combos"] if c.get("name") == name), None)
    if not combo:
        return {"success": False, "error": f"组合 '{name}' 不存在"}
    terminals = [t for t in combo.get("terminals", []) if isinstance(t, dict)]
    if index < 0 or index >= len(terminals):
        return {"success": False, "error": f"索引 {index} 越界"}
    saved = terminals[index]

    try:
        clients = hypr_json("clients")
    except Exception:  # noqa: BLE001
        clients = []
    signatures = current_foot_signatures(clients)
    address = find_matching_address(saved, signatures)

    launch = saved.get("launch") if isinstance(saved.get("launch"), dict) else {}
    saved_workspace = saved.get("workspace", {}) if isinstance(saved.get("workspace"), dict) else {}
    workspace_name = str(saved_workspace.get("name") or saved_workspace.get("id") or "1")

    if address:
        run([HYPRCTL, "dispatch", "workspace", workspace_name], timeout=3)
        run([HYPRCTL, "dispatch", "focuswindow", f"address:{address}"], timeout=3)
        return {"success": True, "focused": address, "workspace": workspace_name, "name": name}

    command = str(launch.get("cmd") or "")
    if not command:
        return {"success": False, "error": "该终端没有可执行的启动命令", "name": name}
    result = run([HYPRCTL, "dispatch", "exec", f"[workspace {workspace_name} silent] {command}"], timeout=5)
    if result.returncode != 0:
        return {"success": False, "error": f"启动失败: {result.stderr.strip()}", "name": name}
    return {"success": True, "spawned": True, "workspace": workspace_name, "name": name}


def cmd_delete(name: str) -> dict[str, Any]:
    with _lock(True):
        store = load_store()
        before = len(store["combos"])
        store["combos"] = [c for c in store["combos"] if c.get("name") != name]
        if len(store["combos"]) == before:
            return {"success": False, "error": f"组合 '{name}' 不存在"}
        save_store(store)
    log(f"combos deleted '{name}'")
    return {"success": True, "deleted": name}


def cmd_rename(old: str, new: str) -> dict[str, Any]:
    with _lock(True):
        store = load_store()
        if any(c.get("name") == new for c in store["combos"]):
            return {"success": False, "error": f"组合 '{new}' 已存在"}
        for combo in store["combos"]:
            if combo.get("name") == old:
                combo["name"] = new
                save_store(store)
                log(f"combos renamed '{old}' -> '{new}'")
                return {"success": True, "renamed_from": old, "renamed_to": new}
        return {"success": False, "error": f"组合 '{old}' 不存在"}


def _summary(terminals: list[dict[str, Any]]) -> dict[str, int]:
    summary = {value: 0 for value in TYPE_SUMMARY_KEYS.values()}
    for terminal in terminals:
        terminal_type = str(terminal.get("launch", {}).get("type") or "")
        key = TYPE_SUMMARY_KEYS.get(terminal_type, "shell")
        summary[key] = summary.get(key, 0) + 1
    return summary


def _project(terminal: dict[str, Any]) -> dict[str, Any]:
    launch = terminal.get("launch", {}) if isinstance(terminal.get("launch"), dict) else {}
    workspace = terminal.get("workspace", {}) if isinstance(terminal.get("workspace"), dict) else {}
    return {
        "type": str(launch.get("type") or ""),
        "title": str(terminal.get("title") or ""),
        "workspace": str(workspace.get("name") or workspace.get("id") or ""),
        "cwd": str(launch.get("cwd") or ""),
        "session": str(launch.get("session") or ""),
        "class": str(terminal.get("class") or ""),
        "floating": bool(terminal.get("floating")),
    }


def cmd_list() -> dict[str, Any]:
    with _lock(False):
        store = load_store()

    try:
        current_clients = hypr_json("clients")
    except Exception:  # noqa: BLE001 — list must still render without live clients
        current_clients = []

    current_mode = current_monitor_mode()
    foot_signatures = current_foot_signatures(current_clients)
    rendered: list[dict[str, Any]] = []
    best_ratio = 0.0
    best_index = -1
    for index, combo in enumerate(store["combos"]):
        terminals = [t for t in combo.get("terminals", []) if isinstance(t, dict)]
        total = len(terminals)
        matched = sum(1 for t in terminals if foot_terminal_present(t, foot_signatures))
        ratio = (matched / total) if total else 0.0
        if total and ratio > best_ratio:
            best_ratio = ratio
            best_index = index
        combo_mode = str(combo.get("mode") or "single")
        rendered.append({
            "name": str(combo.get("name") or ""),
            "saved_at": str(combo.get("saved_at") or ""),
            "mode": combo_mode,
            "eligible": combo_eligible(combo_mode, current_mode),
            "terminal_count": total,
            "match_ratio": round(ratio, 3),
            "is_current": False,
            "summary": _summary(terminals),
            "terminals": [_project(t) for t in terminals],
        })

    if best_index >= 0 and best_ratio >= 0.5:
        rendered[best_index]["is_current"] = True

    return {"updated_at": _now(), "current_mode": current_mode, "combos": rendered}


def cmd_import_snapshot(name: str) -> dict[str, Any]:
    """Import foot terminals from the desktop-session snapshot into a named combo."""
    snapshot_path = Path(os.environ.get("HYPR_SESSION_SNAPSHOT", str(DEFAULT_SNAPSHOT_PATH)))
    if not snapshot_path.exists():
        return {"success": False, "error": f"找不到桌面快照: {snapshot_path}"}
    try:
        data = json.loads(snapshot_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"success": False, "error": f"快照解析失败: {exc}"}

    clients = [
        client for client in data.get("clients", [])
        if isinstance(client, dict)
        and str(client.get("class") or "").lower() in FOOT_CLASSES
        and isinstance(client.get("launch"), dict)
        and client.get("launch", {}).get("cmd")
    ]
    snapshot_monitors = data.get("monitors") or []
    mode = "dual" if isinstance(snapshot_monitors, list) and len(snapshot_monitors) >= 2 else "single"

    with _lock(True):
        store = load_store()
        combos = store["combos"]
        entry = {
            "name": name,
            "saved_at": _now(),
            "mode": mode,
            "imported_from": str(snapshot_path),
            "terminals": clients,
        }
        for i, combo in enumerate(combos):
            if combo.get("name") == name:
                combos[i] = entry
                break
        else:
            combos.append(entry)
        save_store(store)
    log(f"combos imported '{name}': {len(clients)} terminals (mode={mode}) from {snapshot_path}")
    return {"success": True, "imported": len(clients), "mode": mode, "name": name}


def cmd_restore_active() -> dict[str, Any]:
    """Restore the combo that best matches the currently-open terminals."""
    data = cmd_list()
    active = next((c for c in data.get("combos", []) if c.get("is_current")), None)
    if not active or not active.get("name"):
        return {"success": False, "no_active": True, "error": "没有匹配当前终端的活动组合"}
    return cmd_restore(str(active["name"]))


def cmd_status() -> None:
    """Emit waybar-compatible JSON for the top-bar module."""
    data = cmd_list()
    combos = data.get("combos", [])
    active = next((c for c in combos if c.get("is_current")), None)
    if active:
        name = str(active.get("name") or "")
        count = int(active.get("terminal_count") or 0)
        mode = "双屏" if active.get("mode") == "dual" else "单屏"
        eligible = bool(active.get("eligible"))
        ratio = int(round(float(active.get("match_ratio") or 0) * 100))
        text = f"󰆍 {name}"
        tooltip = f"活动组合：{name}\n{count} 个终端 · {mode} · 匹配 {ratio}%\n左键：恢复（只补缺）\n右键：打开面板切换"
        css_class = "active" if eligible else "ineligible"
    else:
        text = "󰆍 无"
        tooltip = "没有匹配当前终端的组合\n左键/右键：打开面板选一个"
        css_class = "empty"
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css_class, "alt": css_class}, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description="Named terminal-combination manager")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list", help="emit JSON of all combos for the panel")
    sub.add_parser("status", help="emit waybar JSON for the top-bar module")
    sub.add_parser("restore-active", help="restore the combo matching the current terminals")
    p_open = sub.add_parser("open-terminal", help="focus (if open) or spawn a single terminal from a combo")
    p_open.add_argument("name")
    p_open.add_argument("index", type=int)
    p_capture = sub.add_parser("capture", help="capture current terminals into a named combo")
    p_capture.add_argument("--name", required=True)
    p_restore = sub.add_parser("restore", help="idempotently restore a named combo")
    p_restore.add_argument("name")
    p_delete = sub.add_parser("delete", help="delete a named combo")
    p_delete.add_argument("name")
    p_rename = sub.add_parser("rename", help="rename a combo")
    p_rename.add_argument("old")
    p_rename.add_argument("new")
    p_import = sub.add_parser("import-snapshot", help="import foot terminals from the desktop snapshot")
    p_import.add_argument("--name", required=True)
    args = parser.parse_args()

    if args.cmd == "status":
        cmd_status()
        return 0

    if args.cmd == "list":
        result: dict[str, Any] = cmd_list()
    elif args.cmd == "restore-active":
        result = cmd_restore_active()
    elif args.cmd == "open-terminal":
        result = cmd_open_terminal(args.name, args.index)
    elif args.cmd == "capture":
        name = (args.name or "").strip()
        result = {"success": False, "error": "组合名不能为空"} if not name else cmd_capture(name)
    elif args.cmd == "restore":
        result = cmd_restore(args.name)
    elif args.cmd == "delete":
        result = cmd_delete(args.name)
    elif args.cmd == "rename":
        new = (args.new or "").strip()
        result = {"success": False, "error": "新组合名不能为空"} if not new else cmd_rename(args.old, new)
    elif args.cmd == "import-snapshot":
        name = (args.name or "").strip()
        result = {"success": False, "error": "组合名不能为空"} if not name else cmd_import_snapshot(name)
    else:  # pragma: no cover — argparse enforces a valid subcommand
        parser.print_help(sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=False))
    return 0 if result.get("success", True) else 1


if __name__ == "__main__":
    raise SystemExit(main())
