"""Repeat mixed load after one NVIDIA allocation warning, without engine changes.

New request cache salts avoid prefix hits. Image/encoder caches remain warm;
this is a recurrence check, not a reproduction of cold image initialization.
"""

from pathlib import Path
import shutil
import sys

import mixed

root = Path(__file__).resolve().parent
target = root / "memory-recheck"
target.mkdir(exist_ok=False)
for model in ["4b", "15-4b", "27b"]:
    shutil.copyfile(root / f"cases-{model}.json", target / f"cases-{model}.json")
mixed.ROOT = target
mixed.WAVES = [
    (name + "-repeat", cases)
    for name, cases in mixed.WAVES
    if name.startswith("mixed-")
]
sys.argv = ["mixed.py", "ngram8"]
mixed.main()
