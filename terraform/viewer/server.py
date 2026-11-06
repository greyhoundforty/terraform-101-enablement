#!/usr/bin/env python3
"""
viewer/server.py - a tiny local web server for the architecture viewer.

What it does
  * Serves index.html (the picture).
  * Answers /api/state by reading a Terraform state file from disk and sending
    the page ONLY a safe summary: resource type, name, and (for servers) the
    profile. The full state file is never sent, because it can contain secrets
    such as the generated private key.

How to run (from the terraform/ folder)
  mise run viewer          # or: python3 viewer/server.py --open

Only the Python standard library is used, so there is nothing to install.
"""

import argparse
import json
import re
import shutil
import subprocess
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

HERE = Path(__file__).resolve().parent  # .../terraform/viewer
ROOT = HERE.parent  # .../terraform  (the folder holding plain/ and modules/)
VERSIONS = ("plain", "modules")  # the two demo folders we know about
SAFE_NAME = re.compile(r"^[A-Za-z0-9_-]+$")  # allowed workspace names; blocks "../" tricks
DEFAULT_SIMPLE = False  # set by --simple: make "/" show the simple fixed view


def state_file(version, workspace):
    """Return the path of the state file for a demo version + workspace.

    Terraform keeps the "default" workspace's state in terraform.tfstate and
    every other workspace in terraform.tfstate.d/<workspace>/terraform.tfstate.
    """
    base = ROOT / version
    if workspace == "default":
        return base / "terraform.tfstate"
    return base / "terraform.tfstate.d" / workspace / "terraform.tfstate"


def list_workspaces(version):
    """'default' plus one entry per folder inside terraform.tfstate.d/."""
    names = ["default"]
    extra = ROOT / version / "terraform.tfstate.d"
    if extra.is_dir():
        names += sorted(p.name for p in extra.iterdir() if p.is_dir())
    return names


def read_instance_count(version, workspace):
    """Find how many servers the code WANTS, by reading instance_count from the
    tfvars files. This lets the page draw outlines for servers that do not
    exist yet (for example right after you raise instance_count to 3).
    """
    files = [ROOT / version / "terraform.tfvars"]
    if workspace != "default":
        files.append(ROOT / version / f"{workspace}.tfvars")  # workspace file wins

    count = 2  # same default as variables.tf
    for path in files:
        if path.is_file():
            # (?m) = multi-line, so ^ matches the start of every line.
            matches = re.findall(r"(?m)^\s*instance_count\s*=\s*(\d+)", path.read_text())
            if matches:
                count = int(matches[-1])  # last assignment wins
    return count


def text(value):
    """Return value only if it is a plain string, otherwise None (a safety guard)."""
    return value if isinstance(value, str) else None


def first(value):
    """Terraform stores nested blocks as lists. Return the first one as a dict ({} if missing)."""
    if isinstance(value, list) and value and isinstance(value[0], dict):
        return value[0]
    return {}


def summarize_state(path):
    """Turn a state file into a short list of safe facts about each resource.

    Every entry has mode/type/name/profile. A few resource types also carry the
    extra fields the dynamic viewer needs to place things:
      ibm_is_subnet       -> id, zone, cidr
      ibm_is_instance     -> subnet (which subnet it sits in), nic (its network interface id)
      ibm_is_floating_ip  -> target (the network interface it is attached to)
    We copy ONLY these fields, never the whole state, because the state can hold secrets.
    """
    state = json.loads(path.read_text())
    summary = []
    # state["resources"] holds one entry per resource block; a block that uses
    # count/for_each has several "instances". A count of 0 has none.
    for resource in state.get("resources", []):
        rtype = resource.get("type")
        for instance in resource.get("instances", []):
            attrs = instance.get("attributes") or {}
            entry = {
                "mode": resource.get("mode"),  # "managed" (we built it) or "data" (we looked it up)
                "type": rtype,
                "name": text(attrs.get("name")),
                "profile": text(attrs.get("profile")) if rtype == "ibm_is_instance" else None,
            }
            if rtype == "ibm_is_subnet":
                entry["id"] = text(attrs.get("id"))
                entry["zone"] = text(attrs.get("zone"))
                entry["cidr"] = text(attrs.get("ipv4_cidr_block"))
            elif rtype == "ibm_is_instance":
                # Newer instances use a virtual network interface (VNI); older ones a plain NIC.
                vni = first(first(attrs.get("primary_network_attachment")).get("virtual_network_interface"))
                nic = first(attrs.get("primary_network_interface"))
                entry["subnet"] = text(vni.get("subnet")) or text(nic.get("subnet"))
                entry["nic"] = text(vni.get("id")) or text(nic.get("id"))
            elif rtype == "ibm_is_floating_ip":
                entry["target"] = text(attrs.get("target"))
            summary.append(entry)
    return summary


_plan_cache = {}  # plan path -> (file modified time, pending list), so we only run terraform when the plan changes


def read_pending(version, workspace):
    """List the changes in the saved plan (<workspace>.tfplan), if there is one.

    A resource that updates "in place" keeps its OLD values in the state file until
    the apply finishes, so the state alone cannot show that an update is under way.
    The saved plan says what is about to change, so the page can compare the two.

    Returns [{type, name, actions, profile}, ...]. Only those fields are kept; the
    plan JSON can contain secrets and is never sent to the page. Returns [] when
    there is no plan or terraform is not on PATH (run the viewer through mise).
    """
    folder = ROOT / version
    plan = folder / f"{workspace}.tfplan"
    if not plan.is_file():
        return []
    mtime = plan.stat().st_mtime
    cached = _plan_cache.get(plan)
    if cached and cached[0] == mtime:
        return cached[1]

    pending = []
    terraform = shutil.which("terraform")
    if terraform:
        try:
            # "terraform show -json <planfile>" prints the plan as JSON.
            out = subprocess.run(
                [terraform, "show", "-json", plan.name],
                cwd=folder, capture_output=True, text=True, timeout=30, check=True,
            ).stdout
            for change in json.loads(out).get("resource_changes", []):
                actions = change.get("change", {}).get("actions", [])
                if actions == ["no-op"] or actions == ["read"]:
                    continue
                after = change.get("change", {}).get("after") or {}
                pending.append(
                    {
                        "type": change.get("type"),
                        "name": text(after.get("name")),
                        "actions": actions,  # e.g. ["update"], ["create"], ["delete", "create"]
                        "profile": text(after.get("profile")),
                    }
                )
        except (subprocess.SubprocessError, OSError, json.JSONDecodeError):
            pending = []  # a plan we cannot read just means no "updating" badge
    _plan_cache[plan] = (mtime, pending)
    return pending


class Handler(BaseHTTPRequestHandler):
    """Handles each browser request: GET / and GET /api/state."""

    def _send(self, status, body, content_type):
        data = body if isinstance(body, bytes) else body.encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")  # always fresh
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)

        # Two pages: the dynamic one (a box per subnet) and the simple fixed one.
        # "/" shows whichever was chosen with --simple (dynamic by default).
        pages = {"/dynamic": "index.html", "/index.html": "index.html", "/simple": "index-simple.html"}
        if url.path == "/":
            page = "index-simple.html" if DEFAULT_SIMPLE else "index.html"
        else:
            page = pages.get(url.path)
        if page:
            self._send(200, (HERE / page).read_bytes(), "text/html; charset=utf-8")
            return

        if url.path == "/api/state":
            query = parse_qs(url.query)
            version = query.get("version", ["plain"])[0]
            workspace = query.get("workspace", ["default"])[0]
            if version not in VERSIONS or not SAFE_NAME.match(workspace):
                self._send(400, json.dumps({"error": "bad version or workspace"}), "application/json")
                return

            path = state_file(version, workspace)
            reply = {
                "found": path.is_file(),
                "resources": [],
                "instance_count": read_instance_count(version, workspace),
                "workspaces": list_workspaces(version),
                "pending": read_pending(version, workspace),
            }
            if reply["found"]:
                try:
                    reply["resources"] = summarize_state(path)
                except (json.JSONDecodeError, OSError):
                    # Terraform may be halfway through writing the file. Tell
                    # the page to keep what it is showing and try again.
                    reply["error"] = "state file is being written"
            self._send(200, json.dumps(reply), "application/json")
            return

        self._send(404, "not found", "text/plain")

    def log_message(self, fmt, *args):
        pass  # keep the terminal quiet during a live demo


def main():
    parser = argparse.ArgumentParser(description="Live Terraform architecture viewer")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--open", action="store_true", help="open the page in your browser")
    parser.add_argument("--simple", action="store_true", help="start on the simple fixed view instead of the dynamic one")
    args = parser.parse_args()

    global DEFAULT_SIMPLE
    DEFAULT_SIMPLE = args.simple

    # 127.0.0.1 = this computer only. Nobody else on the network can reach it.
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = f"http://127.0.0.1:{args.port}/"
    print(f"Viewer running at {url}  (Ctrl+C to stop)")
    if args.open:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
