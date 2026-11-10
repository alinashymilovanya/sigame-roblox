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


HOST = os.environ.get("SIGAME_CATALOG_HOST", "127.0.0.1")
PORT = int(os.environ.get("SIGAME_CATALOG_PORT", "8787"))
MAX_PACK_BYTES = 100 * 1024 * 1024
STORE = Path(__file__).parent / "storage"
STORE.mkdir(exist_ok=True)

PACKS: dict[str, dict] = {}
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

        questions: list[dict] = []
        for node in root.iter():
            if local_name(node.tag) not in {"question", "item", "atom"}:
                continue
            value = text_content(node)
            if not value:
                continue
            questions.append({
                "id": str(uuid.uuid4()),
                "text": value[:5000],
                "answer": "",
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

