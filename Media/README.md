# ElementHousing artwork

`Icon.tga` is the original custom housing artwork from the ElementHousing updater, resized to 256 x 256 without changing its design. It always identifies the minimap launcher and addon list.

The 16 control glyphs in `Icons` are original ElementHousing artwork. The UI uses nMediaTag glyphs when that optional addon is loaded; otherwise it uses these bundled glyphs. Native decor thumbnails remain supplied by Blizzard.

All runtime assets are uncompressed 32-bit TGA files with alpha and power-of-two dimensions. Source artwork is preserved in `Source`. Rebuild with `node tools/build_media.mjs` and the development package `sharp`; neither Node nor sharp is required in WoW.
