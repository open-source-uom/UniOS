#!/usr/bin/env python3
"""
foreman/setup_foreman_medium.py
Register or update the Kubuntu Custom Installation Medium in Foreman.
Used by 05_deploy_to_foreman.sh and can be called standalone.

Usage:
    python3 setup_foreman_medium.py \
        --foreman https://foreman.example.com \
        --user admin \
        --password <pass> \
        --url http://your-server/pub/kubuntu-custom/
"""

import argparse
import json
import sys
import urllib.request
import urllib.error
import base64

def make_request(url, user, password, method="GET", data=None):
    creds = base64.b64encode(f"{user}:{password}".encode()).decode()
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Basic {creds}",
    }
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode()}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Register Kubuntu custom ISO in Foreman")
    parser.add_argument("--foreman", required=True, help="Foreman base URL")
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--url", required=True, help="HTTP URL where ISO tree is served")
    parser.add_argument("--name", default="Kubuntu-Custom-KDE")
    args = parser.parse_args()

    base = args.foreman.rstrip("/")
    media_url = f"{base}/api/media"

    # Check if medium already exists
    print(f"Fetching existing media from {media_url} ...")
    result = make_request(media_url, args.user, args.password)
    existing = {m["name"]: m["id"] for m in result.get("results", [])}

    payload = {
        "medium": {
            "name": args.name,
            "path": args.url,
            "os_family": "Debian",
        }
    }

    if args.name in existing:
        mid = existing[args.name]
        print(f"Medium '{args.name}' exists (id={mid}). Updating path to: {args.url}")
        make_request(f"{media_url}/{mid}", args.user, args.password, method="PUT", data=payload)
        print("✓ Updated.")
    else:
        print(f"Medium '{args.name}' not found. Creating...")
        make_request(media_url, args.user, args.password, method="POST", data=payload)
        print("✓ Created.")

    print(f"\nIn Foreman: Hosts > Installation Media > '{args.name}'")

if __name__ == "__main__":
    main()
