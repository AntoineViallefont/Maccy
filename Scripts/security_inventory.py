#!/usr/bin/env python3
"""Traceability inventory only; this is not a malware scanner or a security verdict."""
import hashlib
import json
import subprocess
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

root = Path(__file__).resolve().parent.parent
baseline = "c700182f638d9d29bfa0aec9dc560422698854c6"
lock = root / "Maccy.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
pins = json.loads(lock.read_text())["pins"]

def git(path, *arguments):
    return subprocess.run(["git", "-C", str(path), *arguments], check=True,
                          capture_output=True, text=True).stdout.strip()

sources = []
for folder in ("Maccy", "MaccyTests", "Packages", "Scripts"):
    for path in (root / folder).rglob("*"):
        if not path.is_file() or ".build" in path.parts:
            continue
        if path.suffix in (".swift", ".py", ".sh", ".plist", ".entitlements"):
            sources.append(path)
sources += [root / "Maccy.xcodeproj/project.pbxproj", lock]

dependencies = []
checkouts = root / ".build/SourcePackages/checkouts"
for pin in pins:
    entry = dict(pin)
    candidates = [path for path in checkouts.iterdir()
                  if path.name.lower() == pin["identity"].lower()] if checkouts.exists() else []
    if candidates:
        path = candidates[0]
        entry["checkout_commit"] = git(path, "rev-parse", "HEAD")
        entry["checkout_tracked_changes"] = git(path, "status", "--porcelain", "--untracked-files=no")
        entry["matches_resolved_revision"] = entry["checkout_commit"] == pin["state"]["revision"]
    dependencies.append(entry)

evidence = {
    "generated_at": datetime.now(ZoneInfo("Europe/Paris")).isoformat(),
    "purpose": "Traceability; not a malware scan, certification, or absence-of-vulnerability claim",
    "upstream_repository": "https://github.com/p0deje/Maccy.git",
    "upstream_baseline_commit": baseline,
    "remote_HEAD_observed_at_initial_review": baseline,
    "initial_worktree_observed_clean": True,
    "fork_repository": "https://github.com/AntoineViallefont/Maccy",
    "security_module_external_dependencies": [],
    "security_module_process_isolation": False,
    "dependencies": dependencies,
    "source_files": [
        {"path": str(path.relative_to(root)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        for path in sorted(set(sources))
    ],
    "validation_report": "docs/validation.json",
    "inventory_does_not_execute_tests": True
}
destination = root / "docs/security-evidence.json"
destination.write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
print(destination)
