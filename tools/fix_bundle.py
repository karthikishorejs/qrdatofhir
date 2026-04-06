#!/usr/bin/env python3
"""
Analyze and (optionally) fix a FHIR Bundle that fails HAPI transaction upload due to
duplicate resourceType/id entries (e.g. HAPI-0535).

Default behavior: report duplicates and where they occur.

Optional fix modes:
  --dedupe-identical     Remove later duplicates only if the resources are JSON-identical.
  --dedupe-keep-first    Always drop later duplicates with the same resourceType/id.
                         (Safe only if you know duplicates are redundant.)
  --out PATH             Write the resulting bundle to PATH (required for fix modes).

Examples:
  python3 tools/fix_bundle.py CMS104FHIRSTKDCAntithrombotic-bundle.json

  python3 tools/fix_bundle.py CMS104FHIRSTKDCAntithrombotic-bundle.json --dedupe-identical --out CMS104.bundle.fixed.json

  python3 tools/fix_bundle.py CMS104FHIRSTKDCAntithrombotic-bundle.json --dedupe-keep-first --out CMS104.bundle.fixed.json
"""
from __future__ import annotations

import argparse
import collections
import json
import sys
from typing import Any, Dict, List, Tuple


def canonical(obj: Any) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def get_resource_key(entry: Dict[str, Any]) -> str | None:
    r = entry.get("resource") or {}
    rt = r.get("resourceType")
    rid = r.get("id")
    if rt and rid:
        return f"{rt}/{rid}"
    return None


def analyze(bundle: Dict[str, Any]) -> Tuple[dict[str, list[int]], dict[str, list[int]]]:
    entries = bundle.get("entry") or []
    by_id: dict[str, list[int]] = collections.defaultdict(list)
    by_fullurl: dict[str, list[int]] = collections.defaultdict(list)

    for idx, e in enumerate(entries):
        k = get_resource_key(e)
        if k:
            by_id[k].append(idx)
        fu = e.get("fullUrl")
        if fu:
            by_fullurl[fu].append(idx)

    dups_id = {k: v for k, v in by_id.items() if len(v) > 1}
    dups_fu = {k: v for k, v in by_fullurl.items() if len(v) > 1}
    return dups_id, dups_fu


def dedupe(bundle: Dict[str, Any], mode: str) -> Tuple[Dict[str, Any], int, List[str]]:
    """
    Returns: (new_bundle, removed_count, notes)
    """
    entries: List[Dict[str, Any]] = list(bundle.get("entry") or [])
    seen: dict[str, str] = {}  # key -> canonical(resource)
    keep: List[Dict[str, Any]] = []
    removed = 0
    notes: List[str] = []

    for idx, e in enumerate(entries):
        key = get_resource_key(e)
        if not key:
            keep.append(e)
            continue

        res = e.get("resource")
        res_c = canonical(res)

        if key not in seen:
            seen[key] = res_c
            keep.append(e)
            continue

        # duplicate key
        if mode == "dedupe-identical":
            if res_c == seen[key]:
                removed += 1
                notes.append(f"Removed duplicate (identical) {key} at entry index {idx}")
                continue
            else:
                # keep conflicting duplicates; report
                keep.append(e)
                notes.append(
                    f"NOT removed (conflict): {key} at entry index {idx} differs from earlier occurrence"
                )
                continue

        if mode == "dedupe-keep-first":
            removed += 1
            notes.append(f"Removed duplicate (keep-first) {key} at entry index {idx}")
            continue

        raise ValueError(f"Unknown dedupe mode: {mode}")

    new_bundle = dict(bundle)
    new_bundle["entry"] = keep
    return new_bundle, removed, notes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("bundle_path", help="Path to the Bundle JSON")
    ap.add_argument(
        "--dedupe-identical",
        action="store_true",
        help="Remove later duplicates only if the resource JSON is identical",
    )
    ap.add_argument(
        "--dedupe-keep-first",
        action="store_true",
        help="Remove later duplicates with same resourceType/id (even if different)",
    )
    ap.add_argument("--out", help="Write output bundle to this file path")
    args = ap.parse_args()

    if args.dedupe_identical and args.dedupe_keep_first:
        print("Choose only one dedupe mode.", file=sys.stderr)
        return 2

    with open(args.bundle_path, "r", encoding="utf-8") as f:
        bundle = json.load(f)

    dups_id, dups_fu = analyze(bundle)

    print(f"Bundle.type: {bundle.get('type')}")
    print(f"entries: {len(bundle.get('entry') or [])}")
    print(f"duplicate resourceType/id count: {len(dups_id)}")
    for k, idxs in sorted(dups_id.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:100]:
        print(f"  {k}: {idxs}")

    print(f"duplicate fullUrl count: {len(dups_fu)}")
    for k, idxs in sorted(dups_fu.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:100]:
        print(f"  {k}: {idxs}")

    mode = None
    if args.dedupe_identical:
        mode = "dedupe-identical"
    elif args.dedupe_keep_first:
        mode = "dedupe-keep-first"

    if mode:
        if not args.out:
            print("--out is required when using a dedupe mode.", file=sys.stderr)
            return 2

        new_bundle, removed, notes = dedupe(bundle, mode)
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(new_bundle, f, indent=2, ensure_ascii=False)
            f.write("\n")

        print(f"\nWrote: {args.out}")
        print(f"Removed entries: {removed}")
        # Print up to 50 notes
        if notes:
            print("Notes (first 50):")
            for n in notes[:50]:
                print(" -", n)

        # Re-analyze output
        dups_id2, _ = analyze(new_bundle)
        print(f"\nAfter fix: duplicate resourceType/id count: {len(dups_id2)}")
        if len(dups_id2) > 0:
            print("Remaining duplicates (first 20):")
            for k, idxs in sorted(dups_id2.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:20]:
                print(f"  {k}: {idxs}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
