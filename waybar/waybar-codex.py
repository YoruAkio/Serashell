#!/usr/bin/env python3

import argparse
import datetime as dt
import json
import os
import sys
import time
from pathlib import Path
from urllib.parse import urlencode

import requests


AUTH_URL = "https://auth.openai.com/oauth/token"
USAGE_URL = "https://chatgpt.com/backend-api/wham/usage"
CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann"
CACHE_TTL_SECONDS = 90
REFRESH_AFTER_DAYS = 8
ICON = "󰬫"


def output_waybar_error(message):
    print(json.dumps({"text": f"{ICON} Err", "tooltip": message, "class": "codex-error"}, ensure_ascii=False))


def find_auth_file():
    codex_home = os.environ.get("CODEX_HOME")
    paths = []

    if codex_home:
        paths.append(Path(codex_home).expanduser() / "auth.json")
    else:
        paths.extend([
            Path.home() / ".config" / "codex" / "auth.json",
            Path.home() / ".codex" / "auth.json",
        ])

    for path in paths:
        if path.exists():
            return path

    raise RuntimeError("codex auth file not found; run codex to log in")


def read_json(path):
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    with tmp_path.open("w", encoding="utf-8") as file:
        json.dump(data, file, indent=2)
        file.write("\n")
    tmp_path.replace(path)


def parse_iso_datetime(value):
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def needs_refresh(auth_data):
    last_refresh = parse_iso_datetime(auth_data.get("last_refresh"))
    if last_refresh is None:
        return True
    if last_refresh.tzinfo is None:
        last_refresh = last_refresh.replace(tzinfo=dt.timezone.utc)
    age = dt.datetime.now(dt.timezone.utc) - last_refresh.astimezone(dt.timezone.utc)
    return age > dt.timedelta(days=REFRESH_AFTER_DAYS)


def token_expired_error(response):
    try:
        data = response.json()
    except ValueError:
        data = {}

    text = response.text
    values = []
    if isinstance(data, dict):
        values.extend(str(value) for value in data.values())
    values.append(text)

    expired_markers = ("refresh_token_expired", "refresh_token_reused", "refresh_token_invalidated")
    return any(marker in value for marker in expired_markers for value in values)


def refresh_access_token(auth_path, auth_data):
    tokens = auth_data.get("tokens") or {}
    refresh_token = tokens.get("refresh_token")
    if not refresh_token:
        raise RuntimeError("codex refresh token missing; run codex to log in again")

    body = urlencode({
        "grant_type": "refresh_token",
        "client_id": CLIENT_ID,
        "refresh_token": refresh_token,
    })
    response = requests.post(
        AUTH_URL,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data=body,
        timeout=20,
    )

    if response.status_code == 200:
        payload = response.json()
        access_token = payload.get("access_token")
        if not access_token:
            raise RuntimeError("token refresh succeeded without an access token")
        tokens["access_token"] = access_token
        if payload.get("refresh_token"):
            tokens["refresh_token"] = payload["refresh_token"]
        auth_data["tokens"] = tokens
        auth_data["last_refresh"] = dt.datetime.now(dt.timezone.utc).isoformat()
        write_json(auth_path, auth_data)
        return auth_data

    if response.status_code in (400, 401) and token_expired_error(response):
        raise RuntimeError("codex token expired; run codex to log in again")

    raise RuntimeError(f"token refresh failed: HTTP {response.status_code} {response.text[:300]}")


def load_auth():
    auth_path = find_auth_file()
    auth_data = read_json(auth_path)

    if needs_refresh(auth_data):
        auth_data = refresh_access_token(auth_path, auth_data)

    access_token = (auth_data.get("tokens") or {}).get("access_token")
    if not access_token:
        raise RuntimeError("codex access token missing; run codex to log in again")
    return access_token


def cache_path():
    return Path.home() / ".cache" / "waybar-codex" / "usage.json"


def read_cache():
    path = cache_path()
    if not path.exists():
        return None
    if time.time() - path.stat().st_mtime > CACHE_TTL_SECONDS:
        return None
    return read_json(path)


def write_cache(data):
    write_json(cache_path(), data)


def fetch_usage(access_token):
    cached = read_cache()
    if cached is not None:
        return cached

    response = requests.get(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Accept": "application/json",
            "User-Agent": "waybar-codex",
        },
        timeout=20,
    )

    if response.status_code in (401, 403):
        raise RuntimeError("codex token expired; re-authenticate by running codex")
    if response.status_code != 200:
        raise RuntimeError(f"usage fetch failed: HTTP {response.status_code} {response.text[:300]}")

    data = response.json()
    write_cache(data)
    return data


def get_window(data, key):
    window = ((data.get("rate_limit") or {}).get(key) or {})
    return {
        "used_percent": float(window.get("used_percent") or 0),
        "reset_after_seconds": int(window.get("reset_after_seconds") or 0),
        "limit_window_seconds": int(window.get("limit_window_seconds") or 0),
    }


def format_duration(seconds):
    seconds = max(0, int(seconds))
    if seconds == 0:
        return "now"

    days, remainder = divmod(seconds, 86400)
    hours, remainder = divmod(remainder, 3600)
    minutes = remainder // 60

    if days:
        return f"{days}d {hours}h" if hours else f"{days}d"
    if hours:
        return f"{hours}h {minutes}m" if minutes else f"{hours}h"
    return f"{max(1, minutes)}m"


def usage_summary(data):
    primary = get_window(data, "primary_window")
    secondary = get_window(data, "secondary_window")
    return primary, secondary


def class_for_percent(percent):
    if percent > 50:
        return "codex-low"
    if percent > 20:
        return "codex-mid"
    return "codex-high"


def format_percent(percent):
    return int(round(percent))


def window_line(label, window):
    remaining_percent = max(0, 100 - window["used_percent"])
    return f"{label}: {format_percent(remaining_percent)}% remaining, resets in {format_duration(window['reset_after_seconds'])}"


def waybar_payload(data):
    primary, secondary = usage_summary(data)
    displayed = primary
    displayed_percent = format_percent(max(0, 100 - displayed["used_percent"]))

    if secondary["used_percent"] >= 100:
        text = f"{ICON} Paused"
    elif displayed["used_percent"] == 0 and displayed["reset_after_seconds"] == 0:
        text = f"{ICON} Ready"
    else:
        text = f"{ICON} {displayed_percent}% ⏱ {format_duration(displayed['reset_after_seconds'])}"

    tooltip_lines = [window_line("5h", primary), window_line("7d", secondary)]
    if data.get("plan_type"):
        tooltip_lines.append(f"Plan: {data['plan_type']}")
    credits = data.get("credits") or {}
    if credits.get("balance") is not None:
        tooltip_lines.append(f"Credits: {credits['balance']}")

    return {
        "text": text,
        "tooltip": "\n".join(tooltip_lines),
        "class": class_for_percent(displayed_percent),
        "percentage": displayed_percent,
    }


def print_cli(data):
    primary, secondary = usage_summary(data)
    print("Codex usage")
    print(window_line("5h", primary))
    print(window_line("7d", secondary))
    if data.get("plan_type"):
        print(f"Plan: {data['plan_type']}")
    credits = data.get("credits") or {}
    if credits.get("balance") is not None:
        print(f"Credits: {credits['balance']}")
    print("\nRaw usage:")
    print(json.dumps(data, indent=2, sort_keys=True))


def parse_args(argv):
    parser = argparse.ArgumentParser(description="show OpenAI Codex usage")
    parser.add_argument("--cli", action="store_true", help="print plain text instead of Waybar JSON")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv or sys.argv[1:])

    try:
        access_token = load_auth()
        data = fetch_usage(access_token)
        if args.cli:
            print_cli(data)
        else:
            print(json.dumps(waybar_payload(data), ensure_ascii=False))
    except Exception as error:
        if args.cli:
            print(f"Error: {error}")
        else:
            output_waybar_error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
