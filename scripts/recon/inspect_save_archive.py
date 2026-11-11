#!/usr/bin/env python3
"""Inspect only the ZIP central directory of an authorized HavenCraft save.

No ZIP member is opened, extracted, decoded, or copied. This is metadata
reconnaissance, not proof of the internal save serialization format.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

MAX_ENTRIES = 10000


def inventory_save(path: Path) -> dict:
    with zipfile.ZipFile(path, "r") as archive:
        entries = archive.infolist()
        if len(entries) > MAX_ENTRIES:
            raise ValueError(f"Archive lists more than {MAX_ENTRIES} entries")
        files = [info for info in entries if not info.is_dir()]
        file_rows = []
        types = {}
        for member in files:
            # Hashing names avoids accidentally publishing local user-chosen save names.
            ext = Path(member.filename).suffix.lower() or "(no extension)"
            types[ext] = types.get(ext, 0) + 1
            file_rows.append(
                {
                    "name_sha256": hashlib.sha256(member.filename.encode("utf-8")).hexdigest(),
                    "extension": ext,
                    "size_bytes": member.file_size,
                    "compressed_bytes": member.compress_size,
                    "crc32": f"{member.CRC:08x}",
                    "compression": member.compress_type,
                    "encrypted": bool(member.flag_bits & 1),
                }
            )
        return {
            "format": "zip-central-directory",
            "file_count": len(files),
            "extensions": dict(sorted(types.items())),
            "total_uncompressed_bytes": sum(m.file_size for m in files),
            "total_compressed_bytes": sum(m.compress_size for m in files),
            "members": file_rows,
            "caveat": "No member bytes read; content structure and semantics remain unknown.",
        }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("save", type=Path, help="An authorized local HavenCraft .zip save")
    parser.add_argument("--output", type=Path, help="Optional local JSON summary path")
    args = parser.parse_args()
    try:
        result = inventory_save(args.save)
    except (OSError, zipfile.BadZipFile, ValueError) as exc:
        parser.error(str(exc))
    report = json.dumps(result, indent=2) + "\n"
    if args.output:
        if args.output.resolve() == args.save.resolve():
            parser.error("Output path must not overwrite the source save")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report, end="")


if __name__ == "__main__":
    main()
