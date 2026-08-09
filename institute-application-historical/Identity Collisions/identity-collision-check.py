#!/usr/bin/env python3
"""Report Institute packages that claim an upstream package's identity.

SwiftPM package identity is global and derived from the last path component of a
dependency URL (or, for a workspace member, from its directory name). It is not
namespaced by organisation. So an Institute package named `swift-numerics` claims
the same identity as `apple/swift-numerics`, and whichever declaration SwiftPM
binds first wins for the entire graph.

Three rules, in descending severity:

  SPLIT-IDENTITY  Two different URLs claim one identity somewhere in the corpus.
                  Build-breaking and NOT workspace-specific: it breaks any
                  consumer of both, with or without an Xcode workspace.

  SQUAT           An inventory package's name equals the identity of a
                  third-party package that some member declares, and the
                  Institute package is not a declared fork of it. Inside a
                  workspace the member directory captures the identity and the
                  consumer is silently handed different code under the same
                  product name. This fails at COMPILE time, on missing symbols,
                  with an error that never names the substitution.

  NAME-MISMATCH   A manifest's declared `name:` differs from its directory /
                  repository name. SwiftPM derives a workspace override's
                  identity from the directory and refuses the override outright.

Scope limit, stated because a check that hides its blind spot is worse than no
check: this reads only DIRECTLY declared dependencies in materialized manifests.
A collision reachable only through a remote package's own transitive
dependencies is invisible here. Findings are a floor, never a ceiling.

Never reports "clean" without having measured something: if no manifests were
read, it reports UNMEASURED and exits non-zero. A pass that cannot distinguish
"no violations" from "nothing scanned" is the defect this exists to prevent.

Usage:
    identity-collision-check.py [--root <institute-root>] [--json]

Exit codes: 0 clean, 1 violations found, 2 unmeasured or bad invocation.
"""

import argparse
import json
import os
import re
import sys

INSTITUTE_ORGS = {
    "swift-primitives", "swift-foundations", "swift-ietf", "swift-standards",
    "swift-institute", "swift-iso", "swift-w3c", "swift-whatwg", "swift-ieee",
    "swift-iec", "swift-microsoft", "swift-intel", "swift-incits", "swift-ecma",
    "swift-arm-ltd", "swift-linux-foundation",
}

PACKAGE_URL = re.compile(r'\.package\s*\(\s*url:\s*"([^"]+)"')
PACKAGE_NAME = re.compile(r'\bPackage\s*\(\s*(?://[^\n]*\n\s*)*name:\s*"([^"]+)"')
FORK_MARKER = re.compile(r"\bfork\b", re.IGNORECASE)


def identity(url):
    """SwiftPM identity: last path component, case-insensitive, minus .git."""
    slug = re.sub(r"\.git$", "", re.sub(r"^.*github\.com[:/]", "", url))
    return slug.rsplit("/", 1)[-1].lower(), slug


def is_declared_fork(pkg_dir, upstream_slug):
    """True when the package documents itself as a fork of that upstream."""
    upstream_repo = upstream_slug.rsplit("/", 1)[-1]
    for candidate in ("NOTICE.txt", "NOTICE", "NOTICE.md"):
        path = os.path.join(pkg_dir, candidate)
        if os.path.isfile(path):
            try:
                if upstream_repo in open(path, encoding="utf-8", errors="replace").read():
                    return True
            except OSError:
                pass
    manifest = os.path.join(pkg_dir, "Package.swift")
    if os.path.isfile(manifest):
        try:
            head = open(manifest, encoding="utf-8", errors="replace").read(4000)
        except OSError:
            return False
        for line in head.splitlines():
            if line.lstrip().startswith("//") and FORK_MARKER.search(line) and upstream_repo in line:
                return True
    return False


def load_inventory(root):
    path = os.path.join(root, "Workspace", "Workspace.json")
    with open(path, encoding="utf-8") as handle:
        entries = json.load(handle)["repositories"]
    # layer -> directory: authority/vendor/jurisdiction orgs nest under their layer root
    located = {}
    for entry in entries:
        org, name, layer = entry["organization"], entry["name"], entry["layer"]
        roots = {"primitives": "swift-primitives", "foundations": "swift-foundations",
                 "standards": "swift-standards"}
        base = roots.get(layer, org)
        nested = os.path.join(root, base, org, name)
        flat = os.path.join(root, base, name)
        located[name] = nested if os.path.isdir(nested) else flat
    return entries, located


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=None,
                        help="Institute root holding the org directories (default: two levels up)")
    parser.add_argument("--json", action="store_true", help="emit machine-readable output")
    args = parser.parse_args()

    root = args.root or os.path.abspath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

    try:
        entries, located = load_inventory(root)
    except (OSError, ValueError, KeyError) as exc:
        print(f"UNMEASURED: cannot read the inventory: {exc}", file=sys.stderr)
        return 2

    inventory_names = {e["name"].lower(): e for e in entries}

    scanned = 0
    missing = []
    # identity -> {slug -> set(declaring package)}
    claims = {}
    third_party = {}
    name_mismatch = []

    for entry in entries:
        name = entry["name"]
        pkg_dir = located[name]
        manifest = os.path.join(pkg_dir, "Package.swift")
        if not os.path.isfile(manifest):
            missing.append(name)
            continue
        try:
            text = open(manifest, encoding="utf-8", errors="replace").read()
        except OSError:
            missing.append(name)
            continue
        scanned += 1

        declared = PACKAGE_NAME.search(text)
        if declared and declared.group(1) != name:
            name_mismatch.append((name, declared.group(1), entry["organization"]))

        # the package itself claims its own identity, via its inventory URL
        ident, slug = identity(entry["url"])
        claims.setdefault(ident, {}).setdefault(slug, set()).add(name)

        for match in PACKAGE_URL.finditer(text):
            dep_ident, dep_slug = identity(match.group(1))
            claims.setdefault(dep_ident, {}).setdefault(dep_slug, set()).add(name)
            if "/" in dep_slug and dep_slug.split("/")[0] not in INSTITUTE_ORGS:
                third_party.setdefault(dep_slug, set()).add(name)

    if scanned == 0:
        print("UNMEASURED: the inventory listed "
              f"{len(entries)} packages but no Package.swift was readable. "
              "Materialize the checkout before trusting this check.", file=sys.stderr)
        return 2

    split, squats = [], []

    for ident, by_slug in sorted(claims.items()):
        if len(by_slug) > 1:
            split.append((ident, {s: sorted(v) for s, v in sorted(by_slug.items())}))

    for slug, consumers in sorted(third_party.items()):
        ident = slug.rsplit("/", 1)[-1].lower()
        entry = inventory_names.get(ident)
        if not entry:
            continue
        pkg_dir = located[entry["name"]]
        if is_declared_fork(pkg_dir, slug):
            continue
        squats.append({
            "identity": ident,
            "upstream": slug,
            "institute": f'{entry["organization"]}/{entry["name"]}',
            "declared_by": sorted(consumers),
        })

    findings = {
        "scanned": scanned,
        "inventory": len(entries),
        "unmaterialized": sorted(missing),
        "split_identity": [{"identity": i, "claims": c} for i, c in split],
        "squat": squats,
        "name_mismatch": [{"repository": r, "declared": d, "organization": o}
                          for r, d, o in sorted(name_mismatch)],
    }

    if args.json:
        print(json.dumps(findings, indent=2, sort_keys=True))
    else:
        print(f"Scanned {scanned} of {len(entries)} inventory packages "
              f"({len(missing)} not materialized).")
        if missing:
            print(f"  not materialized: {', '.join(missing[:8])}"
                  f"{' ...' if len(missing) > 8 else ''}")
        print()
        if split:
            print(f"SPLIT-IDENTITY ({len(split)}) - build-breaking, not workspace-specific:")
            for ident, by_slug in split:
                print(f"  '{ident}' is claimed by {len(by_slug)} different URLs:")
                for slug, who in by_slug.items():
                    print(f"      {slug}  <- declared by {', '.join(who)}")
            print()
        if squats:
            print(f"SQUAT ({len(squats)}) - silent substitution inside a workspace:")
            for s in squats:
                print(f"  {s['institute']} claims the identity of {s['upstream']}")
                print(f"      {s['upstream']} is declared by: {', '.join(s['declared_by'])}")
            print()
        if name_mismatch:
            print(f"NAME-MISMATCH ({len(name_mismatch)}) - unoverridable in a workspace:")
            for repo, declared, org in sorted(name_mismatch):
                print(f"  {org}/{repo} declares name: \"{declared}\"")
            print()
        total = len(split) + len(squats) + len(name_mismatch)
        print(f"{total} violation(s) over {scanned} scanned packages."
              if total else f"Clean over {scanned} scanned packages.")
        print("Scope: directly declared dependencies only; transitive tails are not "
              "visible here, so findings are a floor, not a ceiling.")

    return 1 if (split or squats or name_mismatch) else 0


if __name__ == "__main__":
    sys.exit(main())
