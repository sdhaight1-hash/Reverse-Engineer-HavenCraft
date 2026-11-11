"""Small offline ZIP-fixture checks for the non-extracting save probe."""
import importlib.util
from io import BytesIO
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile, ZIP_DEFLATED

SOURCE = Path(__file__).resolve().parents[1] / "scripts" / "recon" / "inspect_save_archive.py"
spec = importlib.util.spec_from_file_location("inspect_save_archive", SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SaveArchiveTests(unittest.TestCase):
    def test_inventory_is_metadata_only(self):
        with tempfile.TemporaryDirectory() as directory:
            archive_path = Path(directory) / "test-save.zip"
            with ZipFile(archive_path, "w", compression=ZIP_DEFLATED) as archive:
                archive.writestr("private/steve.json", '{"secret":"do-not-export"}')
                archive.writestr("world/binary.dat", b"\x00" * 100)
                archive.writestr("private/", b"")
            result = module.inventory_save(archive_path)
            self.assertEqual(result["file_count"], 2)
            self.assertEqual(result["extensions"], {".dat": 1, ".json": 1})
            self.assertEqual(len(result["members"]), 2)
            self.assertNotIn("steve", str(result).lower())
            self.assertNotIn("do-not-export", str(result))
            self.assertEqual(sum(m["size_bytes"] for m in result["members"]), result["total_uncompressed_bytes"])

    def test_rejects_unrecognized_format(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bad.zip"
            path.write_bytes(b"not-a-zip")
            with self.assertRaises(Exception):
                module.inventory_save(path)

    def test_empty_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "empty.zip"
            with ZipFile(path, "w"):
                pass
            result = module.inventory_save(path)
            self.assertEqual(result["file_count"], 0)
            self.assertEqual(result["total_uncompressed_bytes"], 0)


if __name__ == "__main__":
    unittest.main()
