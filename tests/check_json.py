#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).parents[1]
paths = sorted(ROOT.rglob("*.json"))
paths.append(ROOT / "Chrome" / "CrxMouseConfig")

for path in paths:
    with path.open(encoding="utf-8") as source:
        json.load(source)

print(f"validated {len(paths)} JSON files")
