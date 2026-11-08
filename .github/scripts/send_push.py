"""Firestore এর notifications থেকে নতুন (pushed == false) নোটিফিকেশন নিয়ে FCM পুশ পাঠায়।"""
import json
import os
import sys

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
if not raw:
    print("FIREBASE_SERVICE_ACCOUNT secret নেই, পুশ বাদ দেওয়া হলো।")
    sys.exit(0)

info = json.loads(raw)
pid = info["project_id"]
creds = service_account.Credentials.from_service_account_info(
    info,
    scopes=[
        "https://www.googleapis.com/auth/datastore",
        "https://www.googleapis.com/auth/firebase.messaging",
    ],
)
creds.refresh(Request())
H = {"Authorization": "Bearer " + creds.token}
DOCS = f"https://firestore.googleapis.com/v1/projects/{pid}/databases/(default)/documents"


def sv(fields, key):
    return fields.get(key, {}).get("stringValue", "")


# ১) অপেক্ষমাণ নোটিফিকেশন
q = {
    "structuredQuery": {
        "from": [{"collectionId": "notifications"}],
        "where": {
            "fieldFilter": {
                "field": {"fieldPath": "pushed"},
                "op": "EQUAL",
                "value": {"booleanValue": False},
            }
        },
        "limit": 30,
    }
}
r = requests.post(DOCS + ":runQuery", headers=H, json=q, timeout=30)
r.raise_for_status()
pending = [x["document"] for x in r.json() if "document" in x]
print("অপেক্ষমাণ নোটিফিকেশন:", len(pending))
if not pending:
    sys.exit(0)

# ২) ইউজার ও তাদের ডিভাইস টোকেন
users = []
page = ""
while True:
    url = DOCS + "/users?pageSize=300" + (("&pageToken=" + page) if page else "")
    r = requests.get(url, headers=H, timeout=30)
    r.raise_for_status()
    j = r.json()
    for d in j.get("documents", []):
        f = d.get("fields", {})
        users.append(
            {
                "uid": d["name"].split("/")[-1],
                "zone": sv(f, "zone"),
                "token": sv(f, "fcmToken"),
            }
        )
    page = j.get("nextPageToken", "")
    if not page:
        break
print("মোট ইউজার:", len(users), "| টোকেন আছে:", sum(1 for u in users if u["token"]))

SEND = f"https://fcm.googleapis.com/v1/projects/{pid}/messages:send"

# ৩) পাঠানো
for d in pending:
    f = d.get("fields", {})
    title, body, target = sv(f, "title"), sv(f, "body"), sv(f, "target")
    if target == "all":
        who = users
    elif target.startswith("uid:"):
        who = [u for u in users if u["uid"] == target[4:]]
    else:
        who = [u for u in users if u["zone"] == target]
    tokens = sorted({u["token"] for u in who if u["token"]})
    ok = 0
    for t in tokens:
        msg = {
            "message": {
                "token": t,
                "notification": {"title": title, "body": body},
                "android": {"priority": "HIGH"},
            }
        }
        resp = requests.post(
            SEND, headers={**H, "Content-Type": "application/json"}, json=msg, timeout=30
        )
        if resp.status_code < 300:
            ok += 1
        else:
            print("ব্যর্থ:", resp.status_code, resp.text[:200])
    print(f"'{title}' → target={target} টোকেন={len(tokens)} সফল={ok}")
    pr = requests.patch(
        f"https://firestore.googleapis.com/v1/{d['name']}"
        "?updateMask.fieldPaths=pushed&updateMask.fieldPaths=pushedCount",
        headers=H,
        json={"fields": {"pushed": {"booleanValue": True}, "pushedCount": {"integerValue": str(ok)}}},
        timeout=30,
    )
    pr.raise_for_status()
