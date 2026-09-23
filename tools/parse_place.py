"""
Streaming parser for Roblox .rbxlx place file.
Writes scripts into game_source/ preserving directory structure.
Also prints all RemoteEvent/RemoteFunction/ModuleScript/LocalScript/Script paths.
"""

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PLACE_PATH = r"C:\Users\ADMIN\AppData\Local\Potassium\workspace\Place_94823097601547.rbxlx"
OUT_DIR = Path(r"C:\Users\ADMIN\Documents\ChatGPT\Script\game_source")
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
ALL_SCRIPT_CLASSES = SCRIPT_CLASSES | {"CoreScript"}

# Counters
total_items = 0
script_items = 0
remotes_list = []

def safe_name(name: str) -> str:
    bad = '<>:"/\\|?*'
    out = []
    for ch in name:
        if ch in bad or ord(ch) < 32:
            out.append("_")
        else:
            out.append(ch)
    s = "".join(out).strip()
    if not s:
        s = "_unnamed"
    return s

def main():
    global total_items, script_items, remotes_list
    if not os.path.exists(PLACE_PATH):
        print(f"PLACE NOT FOUND: {PLACE_PATH}")
        sys.exit(1)

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Track path of every open item via stack
    path_stack = []  # list of (className, name)

    # Source accumulator for the currently-open script
    current_source_lines = []
    current_path = None
    current_class = None

    # We use iterparse to handle huge files. We register a start listener that
    # maintains path_stack as we descend, and an end listener that writes
    # scripts when their closing tag arrives.
    context = ET.iterparse(PLACE_PATH, events=("start", "end"))
    in_items_root = False

    for event, elem in context:
        if event == "start":
            tag = elem.tag
            # Roblox format: <Item class="ClassName" referent="..."><Properties>
            # <Name>...</Name></Properties>...</Item>
            if tag == "Item":
                cls = elem.attrib.get("class", "")
                # Find name child if any
                name = None
                for child in elem:
                    if child.tag == "Properties":
                        for prop in child:
                            if prop.tag == "string" and prop.attrib.get("name") == "Name":
                                name = (prop.text or "").strip()
                                break
                        break
                if not name:
                    # Try first immediate string child as fallback
                    for child in elem.iter():
                        if child.tag == "string" and child.attrib.get("name") == "Name":
                            name = (child.text or "").strip()
                            break
                if not name:
                    name = "<unnamed>"

                path_stack.append((cls, name))

                if cls == "RemoteEvent" or cls == "RemoteFunction":
                    remotes_list.append((cls, ".".join(n for _, n in path_stack)))

                if cls in SCRIPT_CLASSES:
                    script_items += 1
                    # We'll extract Source when we see end of this Item
                    current_class = cls
                    current_path = ".".join(n for _, n in path_stack)
                    # Find ProtectedStringVisitor / ProtectedString child
                    src = None
                    for prop in elem.iter():
                        if prop.tag == "ProtectedString" and prop.attrib.get("name") == "Source":
                            # Source text is concatenation of child text segments
                            src = "".join(prop.itertext())
                            break
                    if src is None:
                        # Some files use <string name="Source"> for non-protected
                        for prop in elem.iter():
                            if prop.tag == "string" and prop.attrib.get("name") == "Source":
                                src = (prop.text or "")
                                break
                    if src is None:
                        src = ""

                    # Build output filename: replace dots with folders
                    parts = [safe_name(p[1]) for p in path_stack]
                    # parts[0] is the immediate parent name (e.g. "ReplicatedStorage")
                    # We want a flat layout: ReplicatedStorage/ModuleName.lua
                    # But to avoid collisions, include full path
                    out_rel = "/".join(parts)
                    out_path = OUT_DIR / f"{safe_name(parts[-1])}.lua"  # flat
                    # Better: nest under class folder
                    class_dir = OUT_DIR / safe_name(cls)
                    class_dir.mkdir(exist_ok=True)
                    # Use full dotted path as filename
                    flat_name = safe_name("_".join(parts)) + ".lua"
                    out_path = class_dir / flat_name

                    out_path.write_text(src, encoding="utf-8", errors="replace")
                    print(f"[{cls}] {current_path} -> {out_path.relative_to(OUT_DIR)}")

                total_items += 1
                if total_items % 500 == 0:
                    print(f"  ... scanned {total_items} items so far", file=sys.stderr)

        elif event == "end":
            if elem.tag == "Item":
                if path_stack:
                    path_stack.pop()
            # Free memory: clear elem's children now that we've processed it
            elem.clear()

    print(f"\n=== SUMMARY ===")
    print(f"Total Items scanned: {total_items}")
    print(f"Scripts written:     {script_items}")
    print(f"Remotes found:       {len(remotes_list)}")
    print()
    print("=== REMOTES (class | path) ===")
    for cls, p in remotes_list:
        print(f"{cls}\t{p}")
    print()
    print(f"Output directory: {OUT_DIR}")

if __name__ == "__main__":
    main()
