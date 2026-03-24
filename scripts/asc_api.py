#!/usr/bin/env python3
"""App Store Connect API helper for QuickMemo."""

import jwt
import time
import requests
import json
import sys

KEY_ID = "M55FJD32VU"
ISSUER_ID = "e854c3cc-9a51-43d8-8b84-a4a8f6fb5d6f"
KEY_FILE = "/Users/iwakisyogo/AuthKey_M55FJD32VU.p8"
BUNDLE_ID = "com.iwakisyogo.QuickMemo"
BASE_URL = "https://api.appstoreconnect.apple.com/v1"


def get_token():
    with open(KEY_FILE, "r") as f:
        private_key = f.read()
    now = int(time.time())
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": KEY_ID})


def headers():
    return {"Authorization": f"Bearer {get_token()}", "Content-Type": "application/json"}


def get(endpoint, params=None):
    resp = requests.get(f"{BASE_URL}{endpoint}", headers=headers(), params=params)
    return resp.status_code, resp.json()


def post(endpoint, data):
    resp = requests.post(f"{BASE_URL}{endpoint}", headers=headers(), json=data)
    return resp.status_code, resp.json()


def patch(endpoint, data):
    resp = requests.patch(f"{BASE_URL}{endpoint}", headers=headers(), json=data)
    return resp.status_code, resp.json()


def get_app_id():
    status, data = get("/apps", {"filter[bundleId]": BUNDLE_ID})
    if status == 200 and data.get("data"):
        return data["data"][0]["id"]
    return None


def get_builds(app_id=None):
    params = {"sort": "-uploadedDate", "limit": 5}
    if app_id:
        params["filter[app]"] = app_id
    status, data = get("/builds", params)
    if status == 200:
        return data.get("data", [])
    return []


def check_build_status():
    app_id = get_app_id()
    if not app_id:
        print("App not found on ASC")
        return
    print(f"App ID: {app_id}")
    builds = get_builds(app_id)
    if not builds:
        # Try without app filter
        builds = get_builds()
    for b in builds:
        attrs = b["attributes"]
        print(f"  Build {attrs.get('version', '?')} ({attrs.get('buildNumber', '?')}): "
              f"{attrs.get('processingState', 'UNKNOWN')} - valid={attrs.get('valid', '?')}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        check_build_status()
    elif cmd == "app":
        app_id = get_app_id()
        print(f"App ID: {app_id}" if app_id else "App not found")
    elif cmd == "builds":
        builds = get_builds()
        for b in builds:
            print(json.dumps(b["attributes"], indent=2))
