#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
import datetime as dt
import json
import os
import re
import sqlite3
import subprocess
from collections import Counter, defaultdict, deque

HOME = os.path.expanduser("~")
CODEX_STATE_DB = os.path.join(HOME, ".codex", "state_5.sqlite")
CODEX_GOALS_DB = os.path.join(HOME, ".codex", "goals_1.sqlite")
HERMES_STATE_FILE = os.path.join(os.environ.get("HERMES_HOME", os.path.join(HOME, ".hermes")), "gateway_state.json")

AGENT_ORDER = ["codex", "claude", "omp", "genericagent", "openclaw", "hermes", "webagent"]
AGENT_LABELS = {
    "codex": "Codex",
    "claude": "Claude Code",
    "omp": "OMP",
    "genericagent": "GenericAgent",
    "openclaw": "OpenClaw",
    "hermes": "Hermes",
    "webagent": "Web Agent",
}
AGENT_SHORT = {
    "codex": "C",
    "claude": "CL",
    "omp": "O",
    "genericagent": "G",
    "openclaw": "OC",
    "hermes": "H",
    "webagent": "W",
}
TERMINAL_CLASSES = {"foot", "kitty", "alacritty", "wezterm", "gnome-terminal", "konsole"}
PROBLEM_STATUSES = {"blocked", "budget_limited", "usage_limited"}
RUNNING_STATUSES = {"active"}


def emit(text, css_class, tooltip):
    print(json.dumps({"text": text, "class": css_class, "tooltip": tooltip}, ensure_ascii=False))


def run_json(command, timeout=1.5):
    proc = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"{command[0]} exited {proc.returncode}")
    return json.loads(proc.stdout)


def run_text(command, timeout=1.5):
    proc = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout)
    if proc.returncode != 0:
        return ""
    return proc.stdout


def readlink(path):
    try:
        return os.readlink(path)
    except OSError:
        return ""


def proc_cwd(pid):
    return readlink(f"/proc/{pid}/cwd")


def proc_alive(pid):
    return os.path.exists(f"/proc/{pid}")


def classify_text(text, *, browser=False):
    lowered = text.lower()
    if browser and re.search(r"\bagent\b|智能体|代理", lowered):
        return "webagent"
    if browser:
        return ""
    if "claude-code" in lowered or re.search(r"(^|[/\s-])claude($|[\s-])", lowered):
        return "claude"
    if "oh-my-pi" in lowered or re.search(r"(^|[/\s])omp($|[\s])", lowered) or "/omp" in lowered:
        return "omp"
    if "openclaw" in lowered or "opencode" in lowered:
        return "openclaw"
    if "genericagent" in lowered or "ga-tui" in lowered or "genericagent-tui" in lowered:
        return "genericagent"
    if "hermes_cli" in lowered or ".hermes/hermes-agent" in lowered:
        return "hermes"
    if "@openai/codex" in lowered or re.search(r"(^|[/\s])codex($|[\s])", lowered):
        return "codex"
    return ""


def load_processes():
    output = run_text(["ps", "-eww", "-o", "pid=,ppid=,stat=,comm=,args="], timeout=1.5)
    procs = {}
    children = defaultdict(list)
    for line in output.splitlines():
        parts = line.strip().split(None, 4)
        if len(parts) < 4:
            continue
        pid_s, ppid_s, stat, comm = parts[:4]
        args = parts[4] if len(parts) == 5 else comm
        try:
            pid = int(pid_s)
            ppid = int(ppid_s)
        except ValueError:
            continue
        procs[pid] = {"pid": pid, "ppid": ppid, "stat": stat, "comm": comm, "args": args}
        children[ppid].append(pid)
    return procs, children


def descendants(root_pid, children):
    seen = set()
    queue = deque([root_pid])
    while queue:
        pid = queue.popleft()
        if pid in seen:
            continue
        seen.add(pid)
        yield pid
        queue.extend(children.get(pid, []))


def format_age(epoch_seconds):
    if not epoch_seconds:
        return "--"
    try:
        seconds = max(0, int(dt.datetime.now().timestamp()) - int(epoch_seconds))
    except Exception:
        return "--"
    if seconds < 90:
        return "now"
    if seconds < 5400:
        return f"{seconds // 60}m"
    if seconds < 172800:
        return f"{seconds // 3600}h"
    return f"{seconds // 86400}d"


def load_codex_threads():
    by_id = {}
    latest_by_cwd = {}
    if not os.path.exists(CODEX_STATE_DB):
        return by_id, latest_by_cwd
    try:
        conn = sqlite3.connect(f"file:{CODEX_STATE_DB}?mode=ro", uri=True, timeout=0.25)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            """
            SELECT id, cwd, title, preview, updated_at, agent_nickname
            FROM threads
            WHERE archived = 0
            ORDER BY updated_at DESC
            """
        ).fetchall()
        conn.close()
    except sqlite3.Error:
        return by_id, latest_by_cwd
    for row in rows:
        item = dict(row)
        by_id[item["id"]] = item
        cwd = item.get("cwd") or ""
        if cwd and cwd not in latest_by_cwd:
            latest_by_cwd[cwd] = item
    return by_id, latest_by_cwd


def load_codex_goals():
    goals = {}
    if not os.path.exists(CODEX_GOALS_DB):
        return goals
    try:
        conn = sqlite3.connect(f"file:{CODEX_GOALS_DB}?mode=ro", uri=True, timeout=0.25)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            """
            SELECT thread_id, objective, status, updated_at_ms
            FROM thread_goals
            ORDER BY updated_at_ms DESC
            """
        ).fetchall()
        conn.close()
    except sqlite3.Error:
        return goals
    for row in rows:
        goals[row["thread_id"]] = dict(row)
    return goals


def codex_session_id(args):
    match = re.search(r"\bresume\s+([0-9a-fA-F-]{36})\b", args or "")
    return match.group(1) if match else ""


def has_running_spinner(title):
    return bool(re.match(r"^[\u2800-\u28ff]\s+", title or ""))


def summarize_codex(cwd, session_id, title, threads_by_id, threads_by_cwd, goals_by_thread):
    thread = threads_by_id.get(session_id) if session_id else None
    thread = thread or (threads_by_cwd.get(cwd) if cwd else None)
    goal = goals_by_thread.get(thread["id"]) if thread else None
    if goal:
        stored_status = goal["status"] or "open"
        task = goal["objective"] or thread.get("title") or ""
    elif thread:
        stored_status = "open"
        task = thread.get("title") or thread.get("preview") or ""
    else:
        stored_status = "open"
        task = ""
    status = stored_status
    status_note = ""
    if has_running_spinner(title):
        if stored_status in PROBLEM_STATUSES:
            status_note = f"live spinner overrides stored {stored_status}"
        elif stored_status != "active":
            status_note = "live spinner"
        status = "active"
    return {
        "status": status,
        "stored_status": stored_status,
        "status_note": status_note,
        "task": " ".join(task.split())[:96],
        "thread_id": thread["id"] if thread else "",
        "updated_at": thread.get("updated_at") if thread else 0,
    }


def hermes_background_status():
    service = run_text(["systemctl", "--user", "is-active", "hermes-gateway.service"], timeout=0.8).strip() or "inactive"
    if service != "active":
        return f"Hermes gateway: {service}"
    try:
        with open(HERMES_STATE_FILE, "r", encoding="utf-8") as handle:
            state = json.load(handle)
        gateway = state.get("gateway_state") or "unknown"
        active_agents = int(state.get("active_agents") or 0)
        return f"Hermes gateway: {gateway}, active agents {active_agents}"
    except Exception:
        return "Hermes gateway: systemd active, state unreadable"


def compact_title(title):
    title = " ".join((title or "").split())
    if not title:
        return "untitled"
    return title[:64]


def visual_state(agent):
    if agent["type"] == "codex":
        status = agent.get("status") or "open"
        if status in PROBLEM_STATUSES:
            return "problem"
        if status in RUNNING_STATUSES:
            return "running"
        return "idle"
    if proc_alive(int(agent.get("pid") or 0)):
        return "running"
    return "idle"


try:
    clients = run_json(["hyprctl", "clients", "-j"], timeout=1.5)
except Exception as exc:
    emit("AG?", "down", f"Desktop agent scan failed: {exc}")
    raise SystemExit

procs, children = load_processes()
threads_by_id, threads_by_cwd = load_codex_threads()
goals_by_thread = load_codex_goals()

open_agents = []
seen_window_agent = set()

for client in clients:
    pid = int(client.get("pid") or 0)
    title = client.get("title") or ""
    class_name = client.get("class") or ""
    initial_class = client.get("initialClass") or ""
    workspace = client.get("workspace") or {}
    workspace_name = str(workspace.get("name") or workspace.get("id") or "?")
    browser = (class_name or initial_class).lower() in {"chromium", "google-chrome", "brave-browser", "firefox"}
    terminal = (class_name or initial_class).lower() in TERMINAL_CLASSES

    detected = {}
    for child_pid in descendants(pid, children):
        if terminal and child_pid == pid:
            continue
        proc = procs.get(child_pid)
        if not proc:
            continue
        agent_type = classify_text(f"{proc['comm']} {proc['args']}")
        if agent_type and agent_type not in detected:
            detected[agent_type] = {"pid": child_pid, "cwd": proc_cwd(child_pid), "source": "process", "args": proc["args"]}

    direct_agent = classify_text(f"{class_name} {initial_class} {title}", browser=browser)
    if direct_agent and direct_agent not in detected and not detected:
        detected[direct_agent] = {"pid": pid, "cwd": proc_cwd(pid), "source": "window", "args": ""}

    for agent_type, details in detected.items():
        key = (client.get("address"), agent_type)
        if key in seen_window_agent:
            continue
        seen_window_agent.add(key)
        cwd = details.get("cwd") or proc_cwd(pid)
        status = "open"
        stored_status = "open"
        status_note = ""
        task = ""
        updated_at = 0
        if agent_type == "codex":
            summary = summarize_codex(cwd, codex_session_id(details.get("args") or ""), title, threads_by_id, threads_by_cwd, goals_by_thread)
            status = summary["status"]
            stored_status = summary["stored_status"]
            status_note = summary["status_note"]
            task = summary["task"]
            updated_at = summary["updated_at"]
        agent = {
            "type": agent_type,
            "label": AGENT_LABELS.get(agent_type, agent_type),
            "workspace": workspace_name,
            "window": compact_title(title),
            "class": class_name,
            "pid": details.get("pid") or pid,
            "cwd": cwd,
            "status": status,
            "stored_status": stored_status,
            "status_note": status_note,
            "task": task,
            "updated_at": updated_at,
        }
        open_agents.append(agent)

agent_counts = Counter(agent["type"] for agent in open_agents)
codex_status_counts = Counter(agent["status"] for agent in open_agents if agent["type"] == "codex")
visual_counts = Counter(visual_state(agent) for agent in open_agents)

if not open_agents:
    emit("AG0", "idle", "Desktop agents: none open\n" + hermes_background_status())
    raise SystemExit

if visual_counts.get("problem"):
    text = f"AG!x{len(open_agents)}"
    css_class = "down"
elif visual_counts.get("running"):
    text = f"AG>x{len(open_agents)}"
    css_class = "live"
else:
    text = f"AG=x{len(open_agents)}"
    css_class = "idle"

tooltip_lines = [
    f"Desktop agents: {len(open_agents)} open",
    f"Running: {visual_counts.get('running', 0)}, done/idle: {visual_counts.get('idle', 0)}, problem: {visual_counts.get('problem', 0)}",
]
for key in AGENT_ORDER:
    if agent_counts.get(key):
        tooltip_lines.append(f"{AGENT_LABELS[key]}: {agent_counts[key]}")
if codex_status_counts:
    status_text = ", ".join(f"{name} {count}" for name, count in sorted(codex_status_counts.items()))
    tooltip_lines.append(f"Codex tasks: {status_text}")
tooltip_lines.append("")

for agent in sorted(open_agents, key=lambda item: (str(item["workspace"]), AGENT_ORDER.index(item["type"]) if item["type"] in AGENT_ORDER else 99, item["window"])):
    location = agent["cwd"] or agent["class"] or "unknown"
    age = format_age(agent.get("updated_at")) if agent["type"] == "codex" else "--"
    tooltip_lines.append(f"W{agent['workspace']} {agent['label']}: {agent['status']} - {agent['window']}")
    if agent["task"]:
        tooltip_lines.append(f"  task: {agent['task']}")
    if agent.get("status_note"):
        tooltip_lines.append(f"  note: {agent['status_note']}")
    tooltip_lines.append(f"  cwd: {location}")
    if agent["type"] == "codex":
        tooltip_lines.append(f"  updated: {age}")

tooltip_lines.append("")
tooltip_lines.append(hermes_background_status())

emit(text, css_class, "\n".join(tooltip_lines))
PY
