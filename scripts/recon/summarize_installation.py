#!/usr/bin/env python3
"""Summarize a demo installation without exporting binary contents.

This records only sizes, fingerprints of selected executables/assemblies,
candidate runtime layout and REA success/failure. It does not execute the game.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

INTERESTING = {
    "Assembly-CSharp.dll",
    "GameAssembly.dll",
    "UnityPlayer.dll",
    "global-metadata.dat",
    "HavenCraft.exe",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def json_status(path: Path) -> dict:
    if not path.is_file():
        return {"attempted": False}
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
        return {
            "attempted": True,
            "ok": doc.get("ok") if isinstance(doc, dict) else None,
            "error_category": (
                doc.get("error", {}).get("category")
                if isinstance(doc, dict) and isinstance(doc.get("error"), dict)
                else None
            ),
        }
    except (ValueError, OSError):
        return {"attempted": True, "parse_error": True}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("game_root", type=Path)
    parser.add_argument("report_root", type=Path)
    args = parser.parse_args()
    args.report_root.mkdir(parents=True, exist_ok=True)

    status_file = args.report_root / "steam-exit-code.txt"
    steam_exit_code = (
        int(status_file.read_text(encoding="utf-8").strip())
        if status_file.exists()
        else None
    )

    files = sorted(p for p in args.game_root.rglob("*") if p.is_file()) if args.game_root.is_dir() else []
    size_bytes = sum(p.stat().st_size for p in files)
    managed = [p for p in files if p.name == "Assembly-CSharp.dll" and "Managed" in p.parts]
    metadata = [p for p in files if p.name == "global-metadata.dat"]
    game_assembly = [p for p in files if p.name == "GameAssembly.dll"]

    fingerprinted = []
    for path in files:
        if path.name in INTERESTING:
            fingerprinted.append({
                "filename": path.name,
                "sha256": sha256(path),
                "size_bytes": path.stat().st_size,
            })

    failure_file = args.report_root / "steam-failure-class.txt"
    failure_class = failure_file.read_text(encoding="utf-8").strip() if failure_file.is_file() else None

    summary = {
        "target": "HavenCraft official Steam demo",
        "steam_app_id": 5260550,
        "acquisition": {
            "method": "SteamCMD official anonymous (Windows depot requested)",
            "exit_code": steam_exit_code,
            "failure_class": failure_class,
            "completed": steam_exit_code == 0 and len(files) > 0,
            "restriction": "Anonymous access is not guaranteed; no entitlement bypass attempted.",
        },
        "installation": {
            "file_count": len(files),
            "size_bytes": size_bytes,
            "unity_data_directory_count": sum(
                p.is_dir() and p.name.endswith("_Data")
                for p in args.game_root.iterdir()
            ) if args.game_root.is_dir() else 0,
            "mono_candidate": bool(managed),
            "il2cpp_candidate": bool(game_assembly and metadata),
            "mono_and_il2cpp_both_present": bool(managed and game_assembly and metadata),
            "unresolved": not bool(managed or game_assembly and metadata),
        },
        "selected_binary_fingerprints": fingerprinted,
        "rea_desktop": json_status(args.report_root / "rea-desktop-summary.json"),
        "rea_managed_identity": json_status(args.report_root / "rea-managed-identity.json"),
        "limitations": [
            "Path and SDK markers only support candidate runtime classification.",
            "Static analysis does not establish gameplay runtime behavior or exact game logic.",
            "No game binaries, assets, or raw decompiled code are included in this report.",
            "Official SteamDB metadata is external; verify build version against Steam after acquisition.",
        ],
    }
    output = args.report_root / "install-fingerprint.json"
    output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output} (files={len(files)}, steam_exit={steam_exit_code})")


if __name__ == "__main__":
    main()
