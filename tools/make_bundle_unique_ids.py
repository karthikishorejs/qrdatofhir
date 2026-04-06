#!/usr/bin/env python3
"""
Make resource ids in a FHIR transaction bundle unique (within the bundle).

This is useful for fixing HAPI-0535:
  "Transaction bundle contains multiple resources with ID: <ResourceType>/<id>"

What it does:
- Scans Bundle.entry[].resource.resourceType + resource.id
- When it sees duplicates, it rewrites resource.id by appending a deterministic
  hash suffix (based on canonical JSON of that resource).
- If entry.fullUrl is exactly "<resourceType>/<oldId>", it updates fullUrl too.

It does NOT attempt to rewrite all internal references to the old ids because in
this specific bundle problem the duplicates are the same id repeated for the
same resource type (e.g., many Claim resources each referenced independently).
If you have references between duplicated resources, you may need a more
comprehensive reference-rewrite step.

Usage:
  python3 tools/make_bundle_unique_ids.py \
    --in CMS104FHIRSTKDCAntithrombotic-bundle.json \
    --out CMS104FHIRSTKDCAntithrombotic-bundle.nodupids.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
from typing import Any, Dict, List, Tuple


def canonical(obj: Any) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="in_path", required=True)
    ap.add_argument("--out", dest="out_path", required=True)
    args = ap.parse_args()

    with open(args.in_path, "r", encoding="utf-8") as f:
        bundle = json.load(f)

    entries: List[Dict[str, Any]] = list(bundle.get("entry") or [])
    seen: set[str] = set()
    changed = 0
    changed_keys: List[Tuple[str, str]] = []

    for e in entries:
        r = e.get("resource") or {}
        rt = r.get("resourceType")
        rid = r.get("id")
        if not (rt and rid):
            continue

        key = f"{rt}/{rid}"
        if key not in seen:
            seen.add(key)
            continue

        # duplicate: create deterministic new id
        h = hashlib.sha1(canonical(r).encode("utf-8")).hexdigest()[:12]
        new_id = f"{rid}-{h}"
        new_key = f"{rt}/{new_id}"

        # extremely unlikely but make sure we don't collide
        counter = 1
        while new_key in seen:
            new_id = f"{rid}-{h}-{counter}"
            new_key = f"{rt}/{new_id}"
            counter += 1

        r["id"] = new_id

        # update fullUrl only if it was exactly "ResourceType/oldId"
        if e.get("fullUrl") == key:
            e["fullUrl"] = new_key

        seen.add(new_key)
        changed += 1
        changed_keys.append((key, new_key))

    bundle["entry"] = entries

    with open(args.out_path, "w", encoding="utf-8") as f:
        json.dump(bundle, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print("Wrote:", args.out_path)
    print("Changed duplicate ids:", changed)
    if changed_keys:
        print("First 20 id changes:")
        for old, new in changed_keys[:20]:
            print(" ", old, "->", new)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
