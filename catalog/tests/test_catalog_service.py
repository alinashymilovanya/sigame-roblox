import io
import zipfile
import unittest

from catalog.catalog_service import parse_siq
from catalog.steam_mirror import normalize_workshop_detail, filter_workshop_items, sort_workshop_items


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

    def test_normalizes_steam_workshop_detail_for_catalog_cards(self):
        detail = {
            "publishedfileid": "123",
            "title": "Мемы и Дота",
            "description": "120 вопросов",
            "file_size": "2048",
            "preview_url": "https://example.test/preview.jpg",
            "subscriptions": 42,
            "time_updated": 1776281359,
            "tags": [{"tag": "Memes"}, {"tag": "Games"}],
        }
        card = normalize_workshop_detail(detail)
        self.assertEqual(card["workshopId"], "123")
        self.assertEqual(card["title"], "Мемы и Дота")
        self.assertEqual(card["tags"], ["Memes", "Games"])
        self.assertEqual(card["sizeBytes"], 2048)

    def test_filters_catalog_items_by_query_and_tag(self):
        items = [
            {"title": "Мемы 2026", "description": "Дота", "tags": ["Memes"]},
            {"title": "История", "description": "Европа", "tags": ["History"]},
        ]
        result = filter_workshop_items(items, query="дота", tag="Memes")
        self.assertEqual([item["title"] for item in result], ["Мемы 2026"])

    def test_sorts_catalog_items_by_popularity_newness_or_title(self):
        items = [
            {"title": "Z pack", "subscriptions": 2, "updatedAt": 10},
            {"title": "A pack", "subscriptions": 5, "updatedAt": 20},
        ]
        self.assertEqual(sort_workshop_items(items, "popular")[0]["title"], "A pack")
        self.assertEqual(sort_workshop_items(items, "newest")[0]["title"], "A pack")
        self.assertEqual(sort_workshop_items(items, "title")[0]["title"], "A pack")

    def test_maps_native_v4_theme_price_question_and_answer(self):
        xml = """
        <package version="4" name="Native">
          <round name="Раунд 1"><theme name="Мемы">
            <question price="300">
              <scenario><atom>Кто сказал это?</atom><atom type="image">Images/meme.png</atom></scenario>
              <right><answer>Ведущий</answer></right>
            </question>
          </theme></round>
        </package>
        """
        pack = parse_siq(self.make_pack(xml), "native.siq")
        question = pack["questions"][0]
        self.assertEqual(question["category"], "Мемы")
        self.assertEqual(question["value"], 300)
        self.assertEqual(question["text"], "Кто сказал это?")
        self.assertEqual(question["answer"], "Ведущий")
        self.assertEqual(question["media"][0]["path"], "Images/meme.png")

    def test_maps_native_v5_params_question_and_answer(self):
        xml = """
        <package version="5" name="Modern">
          <round><theme name="Дота"><question price="500"><params>
            <param name="question" type="content"><item type="text">Что делает курьер?</item></param>
            <param name="answer" type="simpleText"><item>Доставляет предметы</item></param>
          </params></question></theme></round>
        </package>
        """
        pack = parse_siq(self.make_pack(xml), "modern.siq")
        question = pack["questions"][0]
        self.assertEqual(question["category"], "Дота")
        self.assertEqual(question["value"], 500)
        self.assertEqual(question["text"], "Что делает курьер?")
        self.assertEqual(question["answer"], "Доставляет предметы")


if __name__ == "__main__":
    unittest.main()

