"""Small dependency-free catalog service for SIGame .siq packs.

It deliberately keeps the first version boring: stdlib HTTP server, zipfile and
ElementTree. The service is a local vertical slice; production storage/auth can
be added after the import contract is proven with real packs.
"""

from __future__ import annotations

import cgi
import hashlib
import json
import os
import re
import threading
import uuid
import zipfile
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from xml.etree import ElementTree as ET

from catalog.steam_mirror import SteamWorkshopClient, filter_workshop_items, sort_workshop_items


HOST = os.environ.get("SIGAME_CATALOG_HOST", "127.0.0.1")
PORT = int(os.environ.get("SIGAME_CATALOG_PORT", "8787"))
MAX_PACK_BYTES = 100 * 1024 * 1024
STORE = Path(__file__).parent / "storage"
STORE.mkdir(exist_ok=True)

PACKS: dict[str, dict] = {}
WORKSHOP_ITEMS: dict[str, dict] = {}
LOCK = threading.Lock()


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1].lower()


def text_content(node: ET.Element | None) -> str:
    if node is None:
        return ""
    return " ".join(part.strip() for part in node.itertext() if part.strip())


def safe_name(name: str) -> str:
    name = re.sub(r"[^\w. -]+", "_", name, flags=re.UNICODE).strip(" .")
    return name[:120] or "pack.siq"


def find_siq_file(directory: Path) -> Path:
    candidates = sorted(directory.rglob("*.siq"))
    if not candidates:
        raise FileNotFoundError("downloaded Workshop item does not contain a .siq file")
    return candidates[0]


def first_descendant(node: ET.Element, names: set[str]) -> ET.Element | None:
    for child in node.iter():
        if local_name(child.tag) in names:
            return child
    return None


def content_value(node: ET.Element) -> str:
    return text_content(node).strip()


def parse_native_question(node: ET.Element, category: str, fallback_index: int) -> dict:
    question_parts: list[str] = []
    answer_parts: list[str] = []
    question_media: list[dict] = []
    media_types = {"image", "audio", "voice", "video", "html", "sound"}

    scenario = first_descendant(node, {"scenario"})
    if scenario is not None:
        answer_section = False
        for item in scenario.iter():
            if local_name(item.tag) not in {"atom", "item"}:
                continue
            kind = str(item.attrib.get("type", "text")).lower()
            value = content_value(item)
            if kind == "marker":
                answer_section = True
                continue
            if not value or answer_section:
                continue
            if kind in media_types:
                question_media.append({"kind": kind, "path": value})
            else:
                question_parts.append(value)

    params = first_descendant(node, {"params", "parameters"})
    if params is not None:
        for param in params.iter():
            if local_name(param.tag) != "param":
                continue
            name = str(param.attrib.get("name", "")).lower()
            value = content_value(param)
            if not value:
                continue
            if name in {"question", "text"}:
                question_parts.append(value)
            elif name in {"answer", "right"}:
                answer_parts.append(value)

    right = first_descendant(node, {"right", "answers"})
    if right is not None:
        for answer in right.iter():
            if local_name(answer.tag) == "answer" and content_value(answer):
                answer_parts.append(content_value(answer))

    text_value = " ".join(dict.fromkeys(question_parts))[:5000]
    answer_value = " ".join(dict.fromkeys(answer_parts))[:2000]
    if not text_value:
        text_value = content_value(node)[:5000]

    try:
        value = int(node.attrib.get("price", fallback_index * 100) or fallback_index * 100)
    except ValueError:
        value = fallback_index * 100

    return {
        "id": str(uuid.uuid4()),
        "text": text_value,
        "answer": answer_value,
        "value": value,
        "category": category or "Новый пак",
        "media": question_media,
    }


def extract_native_questions(root: ET.Element) -> list[dict]:
    questions: list[dict] = []

    def visit(node: ET.Element, category: str = "") -> None:
        node_name = local_name(node.tag)
        current_category = category
        if node_name in {"theme", "category"}:
            current_category = node.attrib.get("name", "") or category
        if node_name == "question":
            question = parse_native_question(node, current_category, len(questions) + 1)
            if question["text"]:
                questions.append(question)
            return
        for child in list(node):
            visit(child, current_category)

    visit(root)
    return questions


def parse_siq(raw: bytes, filename: str) -> dict:
    if len(raw) > MAX_PACK_BYTES:
        raise ValueError("pack is larger than 100 MiB")
    if not raw[:2] == b"PK":
        raise ValueError(".siq must be a ZIP archive")

    with zipfile.ZipFile(BytesIO(raw)) as archive:
        names = archive.namelist()
        content_name = next((n for n in names if n.lower().endswith("content.xml")), None)
        if not content_name:
            raise ValueError("content.xml is missing")
        xml = archive.read(content_name)
        try:
            root = ET.fromstring(xml)
        except ET.ParseError as exc:
            raise ValueError(f"content.xml is invalid XML: {exc}") from exc

        version = root.attrib.get("version", "unknown")
        title = root.attrib.get("name") or root.attrib.get("title") or Path(filename).stem
        media = [n for n in names if n.lower().startswith(("images/", "audio/", "video/", "html/"))]

        questions = extract_native_questions(root)
        if not questions:
            for node in root.iter():
                if local_name(node.tag) not in {"item", "atom"}:
                    continue
                value = text_content(node)
                if not value:
                    continue
                questions.append({
                    "id": str(uuid.uuid4()),
                    "text": value[:5000],
                    "answer": "",
                    "value": len(questions) * 100 + 100,
                    "category": "Новый пак",
                    "media": [],
                })

        pack_id = hashlib.sha256(raw).hexdigest()[:16]
        return {
            "id": pack_id,
            "title": title[:200],
            "filename": safe_name(filename),
            "formatVersion": version,
            "questions": questions,
            "media": media[:5000],
            "mediaReady": False,
            "warnings": ["Answers and media mapping will be refined against real v4/v5 fixtures."] if not questions else [],
        }


class Handler(BaseHTTPRequestHandler):
    server_version = "SIGameCatalog/0.1"

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self.send_json(HTTPStatus.OK, {"ok": True, "service": "sigame-catalog"})
            return
        if parsed.path == "/packs/search":
            query = parse_qs(parsed.query).get("q", [""])[0].lower()
            with LOCK:
                items = [p for p in PACKS.values() if query in p["title"].lower()]
            self.send_json(HTTPStatus.OK, {"items": items})
            return
        if parsed.path == "/workshop/search":
            params = parse_qs(parsed.query)
            query = params.get("q", [""])[0]
            tag = params.get("tag", [""])[0]
            sort = params.get("sort", ["popular"])[0]
            try:
                with LOCK:
                    cached = list(WORKSHOP_ITEMS.values())
                if not cached:
                    cached = SteamWorkshopClient().search(sort=sort)
                    with LOCK:
                        WORKSHOP_ITEMS.update({item["workshopId"]: item for item in cached})
                items = sort_workshop_items(filter_workshop_items(cached, query, tag), sort)
                self.send_json(HTTPStatus.OK, {"items": items, "source": "steam-workshop"})
            except Exception as exc:
                self.send_json(HTTPStatus.BAD_GATEWAY, {"error": f"Steam Workshop unavailable: {exc}"})
            return
        if parsed.path.startswith("/packs/"):
            pack_id = parsed.path.rsplit("/", 1)[-1]
            with LOCK:
                pack = PACKS.get(pack_id)
            if pack:
                self.send_json(HTTPStatus.OK, pack)
            else:
                self.send_json(HTTPStatus.NOT_FOUND, {"error": "pack not found"})
            return
        self.send_json(HTTPStatus.NOT_FOUND, {"error": "route not found"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/workshop/install":
            length = int(self.headers.get("Content-Length", "0"))
            try:
                body = json.loads(self.rfile.read(length).decode("utf-8"))
                workshop_id = str(body.get("workshopId", ""))
                item_path = SteamWorkshopClient().download_item(workshop_id)
                pack_path = find_siq_file(item_path)
                raw = pack_path.read_bytes()
                pack = parse_siq(raw, pack_path.name)
                pack["workshopId"] = workshop_id
                pack["source"] = "steam-workshop"
                (STORE / f"{pack['id']}.siq").write_bytes(raw)
                with LOCK:
                    PACKS[pack["id"]] = pack
                self.send_json(HTTPStatus.CREATED, {"status": "ready", "pack": pack})
            except Exception as exc:
                self.send_json(HTTPStatus.BAD_GATEWAY, {"status": "failed", "error": str(exc)})
            return
        if parsed.path != "/packs/import":
            self.send_json(HTTPStatus.NOT_FOUND, {"error": "route not found"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_PACK_BYTES + 1024 * 1024:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "invalid request size"})
            return
        data = self.rfile.read(length)
        content_type = self.headers.get("Content-Type", "")
        if "multipart/form-data" not in content_type:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "use multipart/form-data with field pack"})
            return
        environ = {"REQUEST_METHOD": "POST", "CONTENT_TYPE": content_type, "CONTENT_LENGTH": str(length)}
        form = cgi.FieldStorage(fp=BytesIO(data), headers=self.headers, environ=environ)
        field = form["pack"] if "pack" in form else None
        if not field or not getattr(field, "file", None):
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "field pack is missing"})
            return
        raw = field.file.read(MAX_PACK_BYTES + 1)
        try:
            pack = parse_siq(raw, field.filename or "pack.siq")
        except (ValueError, zipfile.BadZipFile) as exc:
            self.send_json(HTTPStatus.UNPROCESSABLE_ENTITY, {"error": str(exc)})
            return
        pack_path = STORE / f"{pack['id']}.siq"
        pack_path.write_bytes(raw)
        with LOCK:
            PACKS[pack["id"]] = pack
        self.send_json(HTTPStatus.CREATED, pack)


if __name__ == "__main__":
    print(f"SIGame catalog listening on http://{HOST}:{PORT}")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()

