"""Summarize game_source/ folder structure: top-level dirs and counts."""
import os
from pathlib import Path
from collections import Counter

ROOT = Path(r"C:\Users\ADMIN\Documents\ChatGPT\Script\game_source")

# Tally: class/parent_path/filename -> count
by_class = Counter()
by_top_path = Counter()  # ReplicatedStorage.src.client.Services.X
sample_paths = set()

for cls_dir in ["LocalScript", "ModuleScript", "Script"]:
    p = ROOT / cls_dir
    if not p.exists():
        continue
    for f in p.rglob("*.lua"):
        by_class[cls_dir] += 1
        rel = f.relative_to(p).as_posix()
        # Strip trailing _<hash>.lua if present, strip random numeric suffixes
        # Take first 3 parts after stripping class
        parts = rel.replace(".lua", "").split("_")
        # Skip "<unnamed>" and trailing numeric hashes for grouping
        head = ".".join(parts[:3])
        by_top_path[head] += 1

print("=== File counts by class ===")
for k, v in by_class.most_common():
    print(f"  {k}: {v}")

print()
print("=== Top groupings (first 3 path parts) ===")
for k, v in by_top_path.most_common(40):
    print(f"  {v:4d}  {k}")
