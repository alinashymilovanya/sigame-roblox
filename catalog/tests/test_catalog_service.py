import io
import zipfile
import unittest

from catalog.catalog_service import parse_siq


class CatalogImportTests(unittest.TestCase):
    def make_pack(self, xml: str) -> bytes:
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as archive:
            archive.writestr("content.xml", xml)
            archive.writestr("Images/example.png", b"not-a-real-image")
        return output.getvalue()

    def test_imports_zip_content_and_media_manifest(self):
        raw = self.make_pack('<package version="5" name="Demo"><item>Вопрос</item></package>')
        pack = parse_siq(raw, "demo.siq")
        self.assertEqual(pack["formatVersion"], "5")
        self.assertEqual(pack["title"], "Demo")
        self.assertEqual(len(pack["questions"]), 1)
        self.assertIn("Images/example.png", pack["media"])

    def test_rejects_non_zip(self):
        with self.assertRaises(ValueError):
            parse_siq(b"not a zip", "bad.siq")


if __name__ == "__main__":
    unittest.main()

