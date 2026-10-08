"""Extract vendor coordinates, decor tags, sets, and recipes from pinned MIT data.

Download HDGR_VendorAugment.lua, HDGR_FacetDB.lua and LICENSE from the source
revision below, then run this script with --source-dir. No downloaded Lua runs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
from lua_data import read_table

ROOT = Path(__file__).resolve().parents[1]
REVISION = "971975de8574f8beab19c96c66f828cafd4f7f65"
SOURCE = f"https://github.com/VamooseAddons/housing-decor-guide/blob/{REVISION}"
FACETS = {"culture": "cul", "material": "mat", "color": "col", "room": "rm"}
PROFESSIONS = {"Alchemy": 171, "Blacksmithing": 164, "Cooking": 185, "Enchanting": 333,
               "Engineering": 202, "Inscription": 773, "Jewelcrafting": 755,
               "Leatherworking": 165, "Tailoring": 197}


def import_projects(directory, output, header, facets):
    """Generate locale-independent memberships and minimal recipe fallback records."""
    recipes = read_table(read_source(directory, "HDGR_DecorDB.lua"), "HDGR_DecorDB")
    definitions = read_table(read_source(directory, "HDGR_CollectionDefinitions.lua"), "HDGR_CollectionDefinitions")
    styles = read_table(read_source(directory, "HDGR_StyleDefinitions.lua"), "HDGR_StyleDefinitions")
    vocab = read_table(facets, "HDGR_FacetVocab")
    data = read_table(facets, "HDGR_FacetDB")
    short = {"culture": "cul", "material": "mat", "color": "col", "room": "rm", "category": "cat",
             "mood": "mod", "condition": "con", "formality": "frm", "motif": "mot", "light": "lit"}
    names = {int(m[1]): m[2].strip() for m in re.finditer(r'^\s*\[(\d+)\]\s*=.*?},\s*--\s*(.+)$', facets, re.M)}
    names.update({r["itemID"]: r["name"] for r in recipes.values()})

    def matches(row, query):
        """Match any value within each facet and every facet in a primary theme query."""
        for facet, values in query.items():
            ids = row.get(short[facet], {})
            ids = ids.values() if isinstance(ids, dict) else [ids]
            if not set(values.values()).intersection(vocab[facet].get(i) for i in ids):
                return False
        return bool(query)

    sets, used_items = [], set()
    for key, definition in sorted({**definitions, **styles}.items()):
        if definition.get("resolver"):
            continue  # Session-dependent groups are not static community collections.
        if definition.get("query"):
            members = [i for i, row in data.items() if matches(row, definition["query"])]
        else:
            patterns = list(definition.get("namePatterns", {}).values())
            exclude = list(definition.get("excludePatterns", {}).values())
            members = [i for i, name in names.items() if any(p in name for p in patterns)
                       and not any(p in name for p in exclude)]
        if not members:
            raise ValueError(f"Empty collection: {key}")
        used_items.update(members)
        fields = [f"key = {lua_string(key)}", f"name = {lua_string(definition['displayName'])}",
                  f"description = {lua_string(definition['description'])}",
                  f"kind = {lua_string('collection' if key in definitions else 'theme')}",
                  "items = {" + ",".join(map(str, sorted(members))) + "}"]
        sets.append("    { " + ", ".join(fields) + " },")
    (output / "Collections.lua").write_text(header + "-- Community suggestions, not official achievements or unlock requirements.\n"
        + "EH.collectionSets = {\n" + "\n".join(sets) + "\n}\nEH.collectionItemNames = {\n"
        + "\n".join(f"    [{i}] = {lua_string(names[i])}," for i in sorted(used_items) if i in names)
        + "\n}\n", encoding="utf-8")
    lines, recipe_ids, item_ids = [], set(), set()
    for recipe in sorted(recipes.values(), key=lambda r: r["spellID"]):
        rid, iid = recipe["spellID"], recipe["itemID"]
        if rid in recipe_ids or iid in item_ids or recipe["profession"] not in PROFESSIONS:
            raise ValueError("Unexpected recipe identity or profession")
        recipe_ids.add(rid); item_ids.add(iid)
        reagents = []
        for reagent_id, reagent in sorted(recipe["reagents"].items()):
            qty = reagent["qty"]
            if not isinstance(reagent_id, int) or reagent_id <= 0 or not isinstance(qty, int) or qty <= 0:
                raise ValueError("Invalid fallback reagent")
            fields = [f"itemID = {reagent_id}", f"quantity = {qty}"]
            if reagent.get("name"):
                fields.append(f"name = {lua_string(reagent['name'])}")
            reagents.append("{ " + ", ".join(fields) + " }")
        lines.append(f"    [{rid}] = {{ itemID = {iid}, name = {lua_string(recipe['name'])}, "
                     f"professionID = {PROFESSIONS[recipe['profession']]}, expansion = {lua_string(recipe['expansion'])}, "
                     "reagents = { " + ", ".join(reagents) + " } },")
    (output / "Recipes.lua").write_text(header + "-- Bundled per-craft estimates; current Blizzard schematics take priority.\n"
        + "EH.housingRecipes = {\n" + "\n".join(lines) + "\n}\n", encoding="utf-8")
    return len(sets), len(lines)


def read_source(directory, name):
    """Read bounded UTF-8 source text without executing or evaluating it."""
    path = directory / name
    if path.stat().st_size > 2_000_000:
        raise ValueError(f"Source is unexpectedly large: {name}")
    return path.read_text(encoding="utf-8-sig")


def string_field(row, field):
    """Decode only quoted string literals in the source's flat vendor records."""
    match = re.search(rf'\b{field}\s*=\s*("(?:[^"\\]|\\.)*")', row)
    return json.loads(match[1]) if match else None


def number_field(row, field):
    """Read an explicit decimal field; missing coordinates remain missing."""
    match = re.search(rf"\b{field}\s*=\s*(\d+(?:\.\d+)?)\b", row)
    return float(match[1]) if match else None


def lua_string(value):
    """Encode ordinary UTF-8 strings using Lua-compatible quoted literals."""
    return json.dumps(value, ensure_ascii=False)


def import_data(directory):
    """Write minimal addon-owned tables and preserve upstream attribution."""
    vendors = read_source(directory, "HDGR_VendorAugment.lua")
    facets = read_source(directory, "HDGR_FacetDB.lua")
    license_text = read_source(directory, "LICENSE")
    if "MIT License" not in license_text or "Copyright (c) 2026 Vamoose" not in license_text:
        raise ValueError("Unexpected source license")
    output = ROOT / "Data"
    output.mkdir(exist_ok=True)
    header = ("local _, EH = ...\n-- Derived from Vamoose's MIT-licensed Housing Decor Guide.\n"
              f"-- Source revision: {REVISION}; imported 2026-10-08.\n"
              "-- See Data/SOURCES.md and Data/LICENSE-HousingDecorGuide.txt.\n")
    rows, seen, skipped = [], set(), 0
    for match in re.finditer(r"^\s*\[(-?\d+)\]\s*=\s*\{(.*)\},?\s*$", vendors, re.M):
        key, row = int(match[1]), match[2]
        name, zone = string_field(row, "name"), string_field(row, "zone")
        map_id, x, y = (number_field(row, field) for field in ("mapID", "x", "y"))
        if not name or not zone or not map_id or not map_id.is_integer() or x is None or y is None:
            skipped += 1
            continue
        if not 0 <= x <= 100 or not 0 <= y <= 100 or (x == 0 and y == 0):
            raise ValueError(f"Invalid vendor coordinate: {key}")
        identity = (name.lower(), int(map_id), x, y)
        if identity in seen:
            continue
        seen.add(identity)
        fields = [f"name = {lua_string(name)}", f"zone = {lua_string(zone)}", f"mapID = {int(map_id)}",
                  f"x = {x / 100:.6f}", f"y = {y / 100:.6f}",
                  f"faction = {lua_string(string_field(row, 'faction') or 'N')}"]
        if key > 0:
            fields.append(f"npcID = {key}")
        note = string_field(row, "note")
        if note:
            fields.append(f"note = {lua_string(note)}")
        rows.append("    { " + ", ".join(fields) + " },")
    if len(rows) < 150:
        raise ValueError("Vendor import is unexpectedly incomplete")
    (output / "Vendors.lua").write_text(header + "EH.vendorLibrary = {\n" + "\n".join(rows) + "\n}\n", encoding="utf-8")
    vocab = {}
    for facet in FACETS:
        match = re.search(rf"^\s*{facet}\s*=\s*\{{(.*?)\}}", facets, re.M)
        if not match:
            raise ValueError(f"Missing facet vocabulary: {facet}")
        vocab[facet] = {int(key): json.loads(value) for key, value in
                        re.findall(r'\[(\d+)\]\s*=\s*("[^"\n]*")', match[1])}
    entries = []
    for match in re.finditer(r"^\s*\[(\d+)\]\s*=\s*\{(.*)\},", facets, re.M):
        fields = []
        for facet, short in FACETS.items():
            values = re.search(rf"\b{short}\s*=\s*\{{([\d, ]*)\}}", match[2])
            ids = sorted(set(map(int, re.findall(r"\d+", values[1])))) if values else []
            if any(value not in vocab[facet] for value in ids):
                raise ValueError(f"Unknown {facet} tag in item {match[1]}")
            if ids:
                fields.append(f"{facet} = {{" + ",".join(map(str, ids)) + "}")
        if fields:
            entries.append(f"    [{match[1]}] = {{ " + ", ".join(fields) + " },")
    if len(entries) < 1000:
        raise ValueError("Facet import is unexpectedly incomplete")
    definitions = []
    for facet, names in vocab.items():
        definitions.append(f"    {facet} = {{ " + ", ".join(f"[{key}] = {lua_string(name.replace('-', ' ').title())}"
                                                               for key, name in names.items()) + " },")
    (output / "DecorTags.lua").write_text(header + "-- Community visual/keyword classifications, not Blizzard acquisition requirements.\n"
        + "EH.decorTagNames = {\n" + "\n".join(definitions) + "\n}\nEH.decorTags = {\n" + "\n".join(entries) + "\n}\n", encoding="utf-8")
    set_count, recipe_count = import_projects(directory, output, header, facets)
    (output / "LICENSE-HousingDecorGuide.txt").write_text(license_text, encoding="utf-8")
    checksums = "\n".join(f"- `{name}`: `{hashlib.sha256((directory / name).read_bytes()).hexdigest()}`"
                           for name in ("HDGR_VendorAugment.lua", "HDGR_FacetDB.lua", "HDGR_CollectionDefinitions.lua",
                                        "HDGR_StyleDefinitions.lua", "HDGR_DecorDB.lua", "LICENSE"))
    (output / "SOURCES.md").write_text(f"""# Bundled housing data

Imported 2026-10-08 from [Vamoose's Housing Decor Guide]({SOURCE}), revision `{REVISION}`, under its MIT license. The complete copyright and permission notice ships in `LICENSE-HousingDecorGuide.txt`.

- [Vendor source]({SOURCE}/data/HDGR_VendorAugment.lua): {len(rows)} distinct coordinate records. Coordinates are converted from percentages to native 0-1 map coordinates. {skipped} records without usable coordinates are omitted. Negative upstream keys are placeholders; they are never presented as NPC IDs. Duplicate positions are combined. Notes retain conditional endeavor/holiday availability.
- [Decor facet source]({SOURCE}/data/HDGR_FacetDB.lua): {len(entries)} items with culture, material, color, or room classifications. These are community visual/keyword classifications, including image-derived tags; they are suggestions, not Blizzard facts or unlock requirements. Unclassified items remain unknown. Item IDs link tags to the native catalog in every locale; display labels are English.
- [Collections]({SOURCE}/data/HDGR_CollectionDefinitions.lua) and [themes]({SOURCE}/data/HDGR_StyleDefinitions.lua): {set_count} suggested checklists. Object collections match original English name patterns offline; themes match the primary query (any tag within a facet, every facet required). Upstream weighted boosts, anti-scores, subcategories, and session-dependent resolver groups are not imported. Membership uses item IDs in every locale; ownership comes only from Blizzard's catalog. Absent catalog entries are unavailable, not assumed missing.
- [Crafting recipes]({SOURCE}/data/HDGR_DecorDB.lua): {recipe_count} housing recipe spell IDs, output item IDs, professions, and per-craft reagent estimates. Recipe spell IDs are imported from `spellID`, not upstream table keys. Native Blizzard recipe information and schematics take priority; bundled requirements remain labeled estimates. Recipe acquisition vendors and costs are not confused with finished decor vendors or Auctionator prices.
- Vendor matching uses exact public vendor names from Blizzard's catalog/merchant metadata and requires map/zone agreement for ambiguous names. No item inventories, prices, currencies, reputation gates, or availability are inferred from a vendor's presence in this table. Native tracking and observed merchant routes retain priority.
- Neighborhood artwork and plot/player coordinates come from current public Blizzard APIs. Static world-space plot coordinates are not substituted for current neighborhood map positions.

To refresh, download the six listed source files from a reviewed revision, update `REVISION` and the import date in `tools/import_housing_data.py`, run it with `--source-dir <directory>`, review the generated diff, and run `tests/run.py`. No web requests occur inside WoW and no downloaded Lua is executed by the importer. `tools/lua_data.py` accepts literal tables only and rejects expressions.

Original source SHA-256:

{checksums}
""", encoding="utf-8")
    print(f"Imported {len(rows)} vendor positions, {len(entries)} tagged items, {set_count} sets, and {recipe_count} recipes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    import_data(parser.parse_args().source_dir)
