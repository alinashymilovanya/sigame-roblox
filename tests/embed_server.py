#!/usr/bin/env python3
"""Regenerates tests/_server_source.luau from the real GameServer source.

Run from the repo root (or anywhere):
    python tests/embed_server.py

The Luau CLI cannot read files at runtime (no io library), so the simulation
embeds the entire server source inside a returned string. This script keeps
that embedded copy in sync with the real server file.
"""
import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "src", "ServerScriptService", "GameServer.server.luau")
OUT = os.path.join(HERE, "_server_source.luau")

with io.open(SRC, "r", encoding="utf-8-sig") as f:
    server = f.read()

if "]]" in server:
    raise SystemExit("Server source contains ']]' which would break embedding")

module = (
    "-- AUTO-GENERATED from src/ServerScriptService/GameServer.server.luau. Do not edit.\n"
    "return [==[\n" + server + "\n]==]\n"
)
with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(module)

print("Embedded {} bytes of server source into tests/_server_source.luau".format(len(server.encode("utf-8"))))
