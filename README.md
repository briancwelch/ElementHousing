# ElementHousing 2.0.3

A native Midnight 12.1.0 housing catalog and blueprint library.The only bundled dependencies are the standard LibStub, CallbackHandler, LibDataBroker, and LibDBIcon launcher libraries.

This was vibecoded, it's something I wanted for World of Warcraft to suit my wife and I's needs.  I didn't want to learn Lua. I don't care what you think.

## Open and configure

- Left-click the ElementHousing minimap icon, or use `/eh`. WindTools can collect this standard LibDBIcon button.
- Right-click the icon, use `/eh config`, or open ElvUI > ElementHousing. Options use a left-hand feature tree, with tabs inside Window and Catalog, like WindTools.
- Style follows ElvUI's font, backdrop, and borders. Control icons use the installed nMediaTag assets. When those addons are absent, a fixed native style and Blizzard icons keep the addon usable. There are no selectable themes.
- Drag the title area to move the window. Drag its bottom-right corner to resize it. Movement/size lock, scale, opacity, row spacing, text size, details width, model controls, filter behavior, blueprints, minimap visibility, and waypoints have settings. Dimensions and position are saved account-wide.

## Catalog and filtering

The catalog uses its own `C_HousingCatalog.CreateCatalogSearcher()` and never alters Blizzard's catalog or editor frames. Loading starts when the window opens, proceeds in bounded batches, and stops when it closes. Only visible rows have buttons, and only the selected decor loads a 3D model.

Combine collection state, acquisition source, zone, vendor, expansion, currency type, profession eligibility, category, subcategory, placement, quality, size, and native style/tag filters. Save reusable filter presets from the sidebar. Shift-click a row to favorite it; right-click a vendor row to request its waypoint.

Known vendors and locations are retained as separate choices, including multiple vendors or zones listed for the same decor. Zone/vendor filters and field searches match any known alternative. Opening a merchant that sells catalog decor adds its verified items, purchase currencies, and your nearby location to account-wide saved data.

**Expansion** uses Blizzard's localized catalog expansion tags when available, then the item's native introduction-expansion metadata. The latter may differ from the expansion associated with its appearance or source. Uncached metadata stays under **Unknown expansion** while the addon requests it.

**Currency type** includes gold, native currencies, and item tokens from documented tracking costs and visited merchants. Mixed purchases match every known component. With a specific vendor selected, currency filtering uses that vendor's known costs. Items without a known vendor purchase currency appear under **Unknown / no vendor cost**, including decor from other acquisition sources. Both selectors work with other filters and saved presets.

Shared zone names are treated as unknown locations unless a native map ID identifies the destination. A matching name alone does not put Outland decor in Draenor's current-zone results.

Zones supplied only as a location name can still be selected explicitly from the Zone menu. Changing the category clears its old subcategory selection, and subcategory choices follow the selected parent category.

Tags match any selected value within the same native group and require a match in every selected group.

- **Missing here** or `/eh zone`: missing decor with a known source in the current zone. Results follow zone changes, and subzones/building maps are included by default.
- **Profession eligibility > My professions**: compare every known profession-only decor item against all primary and secondary professions detected on the current character. Any matching profession route qualifies; unrelated profession-only items are excluded. This works for every profession combination, a single profession, secondary professions, or no learned professions. Skills update when learned or unlearned and are detected separately on each character. Expansion skill lines and native recipe links resolve to their base profession.
- The **My professions** header shortcut also selects missing decor. The sidebar profession filter combines with any collection state, zone, source, or other filter. Disable **Apply profession restrictions to missing decor only** to filter owned decor too. Known alternative vendor, drop, quest, and achievement routes remain eligible. **No profession-only decor** excludes known profession routes even when their specific profession is unavailable.
- Search plain words, `"quoted phrases"`, and `-excluded` words. Search specific fields with `name:`, `source:`, `zone:`, `vendor:`, `profession:`, or `id:`. For example, `zone:"Elwynn Forest" source:vendor -rug`.
- Reset filters clears the current selections without deleting favorites or presets.

Ownership includes stored, redeemable, and placed copies. Source information comes from Blizzard's catalog text and documented content-tracking metadata; source labels and profession names use localized game data when available. Metadata can be absent or delayed. Unknown profession eligibility stays visible by default; unknown locations are excluded from zone filters by default. Both policies can be configured. A pending waypoint never overrides a known unrelated profession requirement. The addon cannot reliably infer an unreported profession restriction or every alternative acquisition location. Vendor costs remain **Unknown** when Blizzard has not supplied a cost.

3D previews use the native `decor` actor and each item's model scene/camera preset. Rotation, panning, zoom, reset, and preview height are configurable. Items without model assets show an icon instead.

## Blueprints

The Blueprints tab combines Blizzard's blueprint collection with locally saved Blizzard share codes. Paste a code to inspect it, name/save it, or copy it with Ctrl+C. Automatic backups are optional. Right-click library entries to copy codes or rename/forget a locally saved code; forgetting a code never deletes a native blueprint.

The inspector shows availability progress, required/missing quantities for decor, rooms, dyes, fixtures, and other native content groups, invalid entries, and interior/exterior budgets. Click a decor requirement to inspect it in the catalog once catalog data has loaded. Filter requirements to missing/invalid entries.

**Preview / import** opens Blizzard's supported preview and confirmation flow. **Export** opens Blizzard's native export dialog in an available house/editor context. No layout is automatically applied. Native blueprint availability depends on the client, housing feature availability, and current location. A format-valid share code may still be unavailable on the server. This library accepts Blizzard share codes; it does not translate legacy third-party layout formats.

## Vendor waypoints

Waypoints use Blizzard's content-tracking coordinates or a verified merchant visit for the selected decor. A missing preferred-map result no longer stops the lookup: the addon also queries the player's map and known source maps. Verified visits on the current map take priority, choosing the nearest visited seller unless a specific vendor is selected. Visit locations are approximate because they record the player's position while the shop is open.

If no destination is supplied, open the selling vendor's shop once after `/reload`, then retry **Vendor waypoint**. This also learns purchase currencies without buying anything. For example, open Dethelin's shop before retrying Silvermoon Wooden Chair if its native destination is unavailable.

Pending, unknown, invalid, or non-vendor destinations leave existing map pins intact. Replacing an existing user waypoint requests confirmation by default. Supertracking and replacement confirmation are configurable. Waypoint changes and blueprint operations are blocked during combat.

## Development and verification

Version: **2.0.3**. Interface target: **120100**. Account-wide saved variable: `ElementHousingDB`. Existing compatible root settings/favorites are preserved; the imported suite is not loaded.

Run `tests/run.py` with Python and `lupa` providing Lua 5.1. The checks compile every Lua file, verify TOC paths, exercise the actual bundled launcher libraries against explicit native frame contracts, test filter/zone/waypoint/blueprint behavior, cover expansion/currency combinations and merchant observations, and validate the options against the installed ElvUI AceConfig registry when available.

These are offline checks. Verify in-game after `/reload`: ElvUI plugin title/icon/tree, WindTools minimap collection, catalog loading, nMediaTag icon rendering, expansion/currency selectors, merchant observations and vendor waypoints, interactive 3D camera controls, resize/scroll behavior at your UI scale, current-zone source completeness, and live blueprint collection/import/export replies.

API references: [Blizzard-generated catalog/searcher definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/HousingCatalogSearcherAPIDocumentation.lua), [content tracking](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContentTrackingDocumentation.lua), [blueprints](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/HousingBlueprintUIDocumentation.lua), and [native model previews](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_HousingModelPreview/Blizzard_HousingModelPreview.lua).
