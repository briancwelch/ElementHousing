# Bundled housing data

Imported 2026-10-08 from [Vamoose's Housing Decor Guide](https://github.com/VamooseAddons/housing-decor-guide/blob/971975de8574f8beab19c96c66f828cafd4f7f65), revision `971975de8574f8beab19c96c66f828cafd4f7f65`, under its MIT license. The complete copyright and permission notice ships in `LICENSE-HousingDecorGuide.txt`.

- [Vendor source](https://github.com/VamooseAddons/housing-decor-guide/blob/971975de8574f8beab19c96c66f828cafd4f7f65/data/HDGR_VendorAugment.lua): 243 distinct coordinate records. Coordinates are converted from percentages to native 0-1 map coordinates. 15 records without usable coordinates are omitted. Negative upstream keys are placeholders; they are never presented as NPC IDs. Duplicate positions are combined. Notes retain conditional endeavor/holiday availability.
- [Decor facet source](https://github.com/VamooseAddons/housing-decor-guide/blob/971975de8574f8beab19c96c66f828cafd4f7f65/data/HDGR_FacetDB.lua): 1657 items with culture, material, color, or room classifications. These are community visual/keyword classifications, including image-derived tags; they are suggestions, not Blizzard facts or unlock requirements. Unclassified items remain unknown. Item IDs link tags to the native catalog in every locale; display labels are English.
- Vendor matching uses exact public vendor names from Blizzard's catalog/merchant metadata and requires map/zone agreement for ambiguous names. No item inventories, prices, currencies, reputation gates, or availability are inferred from a vendor's presence in this table. Native tracking and observed merchant routes retain priority.
- Neighborhood artwork and plot/player coordinates come from current public Blizzard APIs. Static world-space plot coordinates are not substituted for current neighborhood map positions.

To refresh, download the three source files from a reviewed revision, update `REVISION` and the import date in `tools/import_housing_data.py`, run it with `--source-dir <directory>`, review the generated diff, and run `tests/run.py`. No web requests occur inside WoW and no downloaded Lua is executed by the importer.

Original source SHA-256:

- `HDGR_VendorAugment.lua`: `e40acc9cc46c0eb054b2a1ec49b31101e5fb3acd38e651007c23bbb20fa6448a`
- `HDGR_FacetDB.lua`: `0c563f9711fb6df30bd86d7ba3f656544ab5004caef6564fdada94a017ac2e27`
- `LICENSE`: `82525e52ca7130c148e304e06e4a9e1416603c0d10f3d7b7ae2fab804dd2ba2e`
