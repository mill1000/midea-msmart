"""Lightweight config-file support for the msmart-ng CLI.

Lets you keep credentials and common defaults out of the command line. Config
keys match the CLI flag names, so a file entry mirrors the flag it replaces.

Resolution order (first wins):
    1. explicit command-line flags
    2. a config file (KEY=VALUE lines)

Config file search order (first found is loaded):
    * path in $MSMART_CONFIG
    * ./.msmart-ng.env
    * $XDG_CONFIG_HOME/msmart-ng/config   (or ~/.config/msmart-ng/config)

Recognized keys (same names as the CLI flags):

    account     account / email
    password    password
    region      built-in credential region (US/DE/KR)
    host        default host: IP for LAN, appliance id for --cloud
    cloud       "1"/"true" to default to cloud transport
    app_id      override cloud app id   (advanced)
    app_key     override cloud app key  (advanced)

Example .msmart-ng.env:

    account = you@example.com
    password = hunter2
    host = 151732606158606
    cloud = true
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Optional

# Keys the config file may define (matching CLI flag names).
KEYS = ("account", "password", "region", "host", "cloud", "app_id", "app_key")

_values: dict[str, str] = {}


def _candidate_paths() -> list[Path]:
    paths = []
    if os.environ.get("MSMART_CONFIG"):
        paths.append(Path(os.environ["MSMART_CONFIG"]).expanduser())
    paths.append(Path(".msmart-ng.env"))
    xdg = os.environ.get("XDG_CONFIG_HOME")
    base = Path(xdg).expanduser() if xdg else Path.home() / ".config"
    paths.append(base / "msmart-ng" / "config")
    return paths


def load_config_file() -> None:
    """Load the first config file found. Call once before building the parser."""
    _values.clear()
    for path in _candidate_paths():
        try:
            if not path.is_file():
                continue
            for raw in path.read_text().splitlines():
                line = raw.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip().lower()
                value = value.strip().strip('"').strip("'")
                if key in KEYS:
                    _values[key] = value
            return
        except OSError:
            continue


def get(key: str, default: Optional[str] = None) -> Optional[str]:
    """Return a config value (config file only), or `default`."""
    return _values.get(key, default)


def as_bool(value: Optional[str]) -> bool:
    return str(value).lower() in ("1", "true", "yes", "on") if value is not None else False
