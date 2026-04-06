#!/usr/bin/env python3
"""
Build a server-aware FHIR transaction Bundle from an input "collection" Bundle of ValueSets.

Problem this solves (HAPI-0902):
- HAPI enforces uniqueness on ValueSet.url + ValueSet.version
- If you PUT a ValueSet with a new resource id but same url/version as an existing one, HAPI rejects it.
So we:
1) For each incoming ValueSet with url+version, search the server:
     GET /ValueSet?url=<url>&version=<version>
2) If exactly one match is found, we use that existing resource id as the PUT target (update).
3) Otherwise, we create a new id deterministically:
     <incoming-id>-<version>   (falls back to incoming-id if version missing)
4) Non-ValueSet resources (if any) are PUT to <resourceType>/<id>.

Usage:
  python3 tools/server_aware_valueset_transaction.py \
    --base http://127.0.0.1:8080/fhir \
    --in dqm_vs_20251117.json \
    --out dqm_vs_20251117.transaction.serveraware.json

Then POST:
  curl --http1.1 -4 -X POST "http://127.0.0.1:8080/fhir" \
    -H "Content-Type: application/fhir+json" -H "Expect:" \
    --data-binary @dqm_vs_20251117.transaction.serveraware.json
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from typing import Optional


def http_get_json(url: str, timeout: int = 30) -> dict:
    req = urllib.request.Request(url, headers={"Accept": "application/fhir+json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
    return json.loads(raw.decode("utf-8"))


def find_existing_valueset_id(base: str, vs_url: str, version: str) -> Optional[str]:
    qs = urllib.parse.urlencode([("url", vs_url), ("version", version)])
    data = http_get_json(f"{base}/ValueSet?{qs}")
    entries = data.get("entry") or []
    if len(entries) != 1:
        return None
    rid = (entries[0].get("resource") or {}).get("id")
    return rid or None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="FHIR base URL, e.g. http://127.0.0.1:8080/fhir")
    ap.add_argument("--in", dest="inp", required=True, help="Input bundle JSON")
    ap.add_argument("--out", dest="out", required=True, help="Output transaction bundle JSON")
    ap.add_argument("--sleep-ms", type=int, default=0, help="Optional delay between server searches")
    args = ap.parse_args()

    with open(args.inp, "r", encoding="utf-8") as f:
        bundle = json.load(f)

    if bundle.get("resourceType") != "Bundle":
        print(f"Expected resourceType=Bundle, got {bundle.get('resourceType')}", file=sys.stderr)
        return 2

    bundle["type"] = "transaction"

    updated = 0
    created = 0
    skipped_search = 0

    for idx, entry in enumerate(bundle.get("entry", []), start=1):
        res = entry.get("resource") or {}
        rt = res.get("resourceType")
        rid = res.get("id")
        if not rt or not rid:
            raise SystemExit(f"Entry #{idx} missing resourceType/id")

        if rt == "ValueSet":
            vs_url = res.get("url")
            ver = res.get("version")

            existing_id = None
            if vs_url and ver:
                if args.sleep_ms:
                    time.sleep(args.sleep_ms / 1000.0)
                try:
                    existing_id = find_existing_valueset_id(args.base, vs_url, ver)
                except Exception as e:
                    # If the server query fails, we still produce output deterministically.
                    print(f"Warning: search failed for ValueSet url={vs_url} version={ver}: {e}", file=sys.stderr)
                    existing_id = None
            else:
                skipped_search += 1

            if existing_id:
                # Update existing server resource id
                res["id"] = existing_id
                entry["resource"] = res
                entry["request"] = {"method": "PUT", "url": f"ValueSet/{existing_id}"}
                updated += 1
            else:
                # Create new deterministic id (oid-version)
                new_id = f"{rid}-{ver}" if ver else rid
                res["id"] = new_id
                entry["resource"] = res
                entry["request"] = {"method": "PUT", "url": f"ValueSet/{new_id}"}
                created += 1
        else:
            entry["request"] = {"method": "PUT", "url": f"{rt}/{rid}"}

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(bundle, f, ensure_ascii=False)

    print(
        f"Wrote {args.out} entries={len(bundle.get('entry', []))} updated={updated} created={created} skipped_search={skipped_search}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
