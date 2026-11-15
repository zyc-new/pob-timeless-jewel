#!/usr/bin/env python3
"""Natural-language friendly CLI for the in-PoB Timeless Jewel Planner.

It talks directly to the PoB AgentBridge (127.0.0.1:49090) so the chat AI can
drive the planner without the MCP stdio layer.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from pob_wake import wake_pob
except Exception:  # pragma: no cover - wake helper is optional
    wake_pob = None

BRIDGE = os.environ.get("POB_BRIDGE_URL", "http://127.0.0.1:49090").rstrip("/")

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass


def post(command: str, params: dict | None = None) -> dict:
    body = {"cmd": command}
    if params:
        body.update(params)
    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        BRIDGE + "/rpc",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", "replace")
        return {"ok": False, "error": f"HTTP {exc.code}: {text}"}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "error": f"{type(exc).__name__}: {exc}"}


def load_params(path: str | None) -> dict:
    if not path:
        return {}
    return json.loads(Path(path).read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser(description="PoB Timeless Jewel Planner CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    scan = sub.add_parser("scan", help="read lit sockets/nodes and current planner options")
    scan.add_argument("--args-file", help="optional JSON params")

    open_panel = sub.add_parser("open", help="open the planner panel")
    open_panel.add_argument("--args-file", help="optional JSON params")

    configure = sub.add_parser("configure", help="apply planner config and refresh panel")
    configure.add_argument("--args-file", required=True, help="JSON file with planner config")

    search = sub.add_parser("search", help="run the hard-constraint search")
    search.add_argument("--args-file", help="optional JSON params")

    preview = sub.add_parser("preview", help="equip a seed and return to the tree")
    preview.add_argument("--seed", type=int, required=True)

    next_seed = sub.add_parser("next", help="preview the next/previous seed")
    next_seed.add_argument("--direction", type=int, default=1, choices=[-1, 1])

    args = parser.parse_args()

    if wake_pob is not None:
        try:
            wake_pob(force=True)
        except Exception:
            pass

    if args.command == "scan":
        result = post("timeless_scan", load_params(args.args_file))
    elif args.command == "open":
        result = post("timeless_open", load_params(args.args_file))
    elif args.command == "configure":
        result = post("timeless_configure", load_params(args.args_file))
    elif args.command == "search":
        result = post("timeless_search", load_params(args.args_file))
    elif args.command == "preview":
        result = post("timeless_preview", {"seed": args.seed})
    elif args.command == "next":
        result = post("timeless_next", {"direction": args.direction})
    else:
        result = {"ok": False, "error": "unknown command"}

    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result.get("ok") else 2)


if __name__ == "__main__":
    main()
