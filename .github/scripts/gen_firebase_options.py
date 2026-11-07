import json
import os
import sys

PACKAGE = "com.techcity.tech_city"

raw = os.environ.get("GOOGLE_SERVICES_JSON", "").strip()
if not raw:
    sys.exit("GOOGLE_SERVICES_JSON secret খালি। GitHub Settings > Secrets এ google-services.json এর পুরো লেখা দিন।")

data = json.loads(raw)
clients = data.get("client", [])
pick = None
for c in clients:
    pkg = c.get("client_info", {}).get("android_client_info", {}).get("package_name")
    if pkg == PACKAGE:
        pick = c
        break
if pick is None:
    found = [c.get("client_info", {}).get("android_client_info", {}).get("package_name") for c in clients]
    sys.exit(f"google-services.json এ package {PACKAGE} নেই। পাওয়া গেছে: {found}. Firebase এ Android অ্যাপ এই package name দিয়ে যোগ করুন।")

info = data["project_info"]
api_key = pick["api_key"][0]["current_key"]
app_id = pick["client_info"]["mobilesdk_app_id"]

out = f"""// এই ফাইল CI তে অটো তৈরি হয় (google-services.json থেকে)
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {{
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: '{api_key}',
    appId: '{app_id}',
    messagingSenderId: '{info["project_number"]}',
    projectId: '{info["project_id"]}',
    storageBucket: '{info.get("storage_bucket", "")}',
  );
}}
"""
with open(sys.argv[1], "w", encoding="utf-8") as f:
    f.write(out)
print("firebase_options.dart তৈরি হয়েছে, project:", info["project_id"])
