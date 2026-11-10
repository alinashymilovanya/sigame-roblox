"""Steam Workshop metadata and download bridge.

Roblox never talks to Steam directly. This module is the server-side bridge:
it discovers public Workshop IDs, reads official metadata, and optionally uses
SteamCMD/Steamworks infrastructure to download an item into a local cache.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable


SIGAME_APP_ID = 3553500
STEAM_DETAILS_URL = "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/"
STEAM_QUERY_URL = "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/"
STEAM_BROWSE_URL = "https://steamcommunity.com/workshop/browse/?appid=3553500&section=readytouseitems&days=90"
ID_RE = re.compile(r"(?:publishedfileid|sharedfiles/filedetails/\?id=)[^0-9]{0,30}([0-9]{6,20})")


def normalize_workshop_detail(detail: dict) -> dict:
    tags = [str(item.get("tag", "")).strip() for item in detail.get("tags", [])]
    tags = [tag for tag in tags if tag]
    workshop_id = str(detail.get("publishedfileid", ""))
    return {
        "workshopId": workshop_id,
        "title": str(detail.get("title", "Untitled pack"))[:200],
        "description": str(detail.get("description", ""))[:2000],
        "sizeBytes": int(detail.get("file_size", 0) or 0),
        "previewUrl": str(detail.get("preview_url", "")),
        "subscriptions": int(detail.get("subscriptions", 0) or 0),
        "updatedAt": int(detail.get("time_updated", 0) or 0),
        "tags": tags,
        "steamUrl": f"https://steamcommunity.com/sharedfiles/filedetails/?id={workshop_id}",
        "status": "available" if detail.get("banned", 0) == 0 else "blocked",
    }


def filter_workshop_items(items: list[dict], query: str = "", tag: str = "") -> list[dict]:
    query = query.strip().lower()
    tag = tag.strip().lower()
    result = []
    for item in items:
        haystack = f"{item.get('title', '')} {item.get('description', '')}".lower()
        tags = [str(value).lower() for value in item.get("tags", [])]
        if query and query not in haystack:
            continue
        if tag and tag not in tags:
            continue
        result.append(item)
    return result


def sort_workshop_items(items: list[dict], sort: str = "popular") -> list[dict]:
    if sort == "newest":
        return sorted(items, key=lambda item: int(item.get("updatedAt", 0) or 0), reverse=True)
    if sort == "title":
        return sorted(items, key=lambda item: str(item.get("title", "")).lower())
    return sorted(items, key=lambda item: int(item.get("subscriptions", 0) or 0), reverse=True)


def discover_ids_from_html(html: str) -> list[str]:
    return sorted({match.group(1) for match in ID_RE.finditer(html)}, reverse=True)


class SteamWorkshopClient:
    def __init__(
        self,
        api_key: str | None = None,
        opener: Callable = urllib.request.urlopen,
        app_id: int = SIGAME_APP_ID,
        steamcmd_path: str | None = None,
        workdir: str | Path | None = None,
    ) -> None:
        self.api_key = api_key or os.environ.get("STEAM_WEB_API_KEY", "")
        self.opener = opener
        self.app_id = app_id
        self.steamcmd_path = steamcmd_path or os.environ.get("STEAMCMD_PATH", "")
        self.workdir = Path(workdir or os.environ.get("STEAMCMD_WORKDIR", "catalog/storage/steamcmd"))

    def _post_json(self, url: str, values: dict[str, str]) -> dict:
        body = urllib.parse.urlencode(values).encode("utf-8")
        request = urllib.request.Request(
            url,
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded", "User-Agent": "SIGameLounge/0.1"},
            method="POST",
        )
        with self.opener(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))

    def get_details(self, workshop_ids: list[str]) -> list[dict]:
        valid_ids = [value for value in workshop_ids if value.isdigit()]
        if not valid_ids:
            return []
        values = {"itemcount": str(len(valid_ids))}
        values.update({f"publishedfileids[{index}]": item_id for index, item_id in enumerate(valid_ids)})
        payload = self._post_json(STEAM_DETAILS_URL, values)
        details = payload.get("response", {}).get("publishedfiledetails", [])
        return [normalize_workshop_detail(item) for item in details if item.get("result") == 1]

    def search(self, query: str = "", tag: str = "", sort: str = "popular") -> list[dict]:
        if self.api_key:
            values = {
                "key": self.api_key,
                "query_type": "1",
                "page": "1",
                "numperpage": "50",
                "creator_appid": str(self.app_id),
                "appid": str(self.app_id),
                "search_text": query,
                "requiredtags": tag,
                "return_tags": "true",
                "return_previews": "true",
                "return_vote_data": "true",
            }
            payload = self._post_json(STEAM_QUERY_URL, values)
            files = payload.get("response", {}).get("publishedfiledetails", [])
            return sort_workshop_items([normalize_workshop_detail(item) for item in files], sort)

        request = urllib.request.Request(STEAM_BROWSE_URL, headers={"User-Agent": "SIGameLounge/0.1"})
        with self.opener(request, timeout=20) as response:
            ids = discover_ids_from_html(response.read().decode("utf-8", errors="ignore"))
        return sort_workshop_items(filter_workshop_items(self.get_details(ids[:50]), query, tag), sort)

    def download_item(self, workshop_id: str) -> Path:
        if not workshop_id.isdigit():
            raise ValueError("workshopId must contain digits only")
        if not self.steamcmd_path:
            raise RuntimeError("STEAMCMD_PATH is not configured")
        self.workdir.mkdir(parents=True, exist_ok=True)
        command = [
            self.steamcmd_path,
            "+force_install_dir", str(self.workdir),
            "+login", "anonymous",
            "+workshop_download_item", str(self.app_id), workshop_id,
            "+quit",
        ]
        subprocess.run(command, check=True, capture_output=True, text=True, timeout=300)
        item_path = self.workdir / "steamapps" / "workshop" / "content" / str(self.app_id) / workshop_id
        if not item_path.is_dir():
            raise FileNotFoundError(f"Steam did not install Workshop item {workshop_id}")
        return item_path

