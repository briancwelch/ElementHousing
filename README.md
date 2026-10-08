# ElementHousing 2.0.8

A native Midnight 12.1.0 housing catalog, collection/crafting planner, blueprint library, and neighborhood/house information window. **ElvUI is required.** nMediaTag (`ElvUI_mMediaTag`), WindTools (`ElvUI_WindTools`), Auctionator, and Kaliel's Tracker are optional. The standard LibStub, CallbackHandler, LibDataBroker, and LibDBIcon launcher libraries are bundled.

This was vibecoded, it's something I wanted for World of Warcraft to suit my wife and I's needs.  I didn't want to learn Lua. I don't care what you think.

## Open and configure

- Left-click the ElementHousing minimap icon, or use `/eh`. The launcher and addon list always use our original updater housing artwork. WindTools can collect the standard LibDBIcon button when installed.
- Right-click the icon, use `/eh config`, or open ElvUI > ElementHousing. The options appear at the bottom of the ElvUI list beside its other plugins, with a left-hand feature tree and tabs inside Window and Catalog. Configuration uses ElvUI natively.
- Appearance follows ElvUI's font, font size, outline, UI scale, status-bar textures, backdrop transparency, borders, and value colors. Existing controls join ElvUI's native update registries, so changes apply to ElementHousing too. Configure these in ElvUI; there are no separate addon font, scale, opacity, or theme overrides. Old saved appearance overrides are retired without deleting favorites, blueprints, filter presets, or saved geometry.
- Control icons use the 16 original bundled glyphs and custom housing artwork. nMediaTag glyphs take precedence in the UI when loaded. Optional WindTools support includes minimap collection and its configured window shadows; disabled WindTools skins are respected.
- Drag the title area to move the window. Drag its bottom-right corner to resize it. Movement/size lock, row spacing, details width, model controls, filter behavior, blueprints, minimap visibility, and waypoints have settings. Dimensions and position are saved account-wide.

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
- The **My professions** header shortcut selects **Missing decor**, **Profession** acquisition, and **My professions** eligibility together. It shows known profession rewards for this character, including items with alternative vendor routes, while excluding ordinary vendor rewards and unrelated professions. Other filters still combine with it. The sidebar eligibility filter permits alternative vendor, drop, quest, and achievement acquisition when browsing all sources. Disable **Apply profession restrictions to missing decor only** to filter owned decor too. **No profession-only decor** excludes known profession routes even when their specific profession is unavailable.
- **Hide PvP Decorations** excludes items with known PvP source labels/tags, PvP achievement categories, or Honor, Conquest, Bloody Token, or Mark of Honor costs. Item names alone never determine PvP status. Decorations with unknown source data remain visible. This toggle combines with every other filter and saves in presets.
- Search plain words, `"quoted phrases"`, and `-excluded` words. Search specific fields with `name:`, `source:`, `zone:`, `vendor:`, `profession:`, or `id:`. For example, `zone:"Elwynn Forest" source:vendor -rug`.
- Reset filters clears the current selections without deleting favorites or presets.

Ownership includes stored, redeemable, and placed copies. Source information comes from Blizzard's catalog text and documented content-tracking metadata; source labels and profession names use localized game data when available. Metadata can be absent or delayed. Unknown profession eligibility stays visible by default; unknown locations are excluded from zone filters by default. Both policies can be configured. A pending waypoint never overrides a known unrelated profession requirement. The addon cannot reliably infer an unreported profession restriction or every alternative acquisition location. Vendor costs remain **Unknown** when Blizzard has not supplied a cost.

3D previews use the native `decor` actor and each item's model scene/camera preset. Rotation, panning, zoom, reset, and preview height are configurable. Items without model assets show an icon instead.

## Blueprints

The Blueprints tab combines Blizzard's blueprint collection with locally saved Blizzard share codes. Paste a code to inspect it, name/save it, or copy it with Ctrl+C. Automatic backups are optional. Right-click library entries to copy codes or rename/forget a locally saved code; forgetting a code never deletes a native blueprint.

The inspector shows availability progress, required/missing quantities for decor, rooms, dyes, fixtures, and other native content groups, invalid entries, and interior/exterior budgets. Click a decor requirement to inspect it in the catalog once catalog data has loaded. Filter requirements to missing/invalid entries.

**Preview / import** opens Blizzard's supported preview and confirmation flow. **Export** opens Blizzard's native export dialog in an available house/editor context. No layout is automatically applied. Native blueprint availability depends on the client, housing feature availability, and current location. A format-valid share code may still be unavailable on the server. This library accepts Blizzard share codes; it does not translate legacy third-party layout formats.

## Collections, recipes, and reagents

The **Collections** tab contains **Sets**, **Recipes**, and **Reagents** views. `/eh collections`, `/eh recipes`, and `/eh reagents` open them directly. Navigation wraps for larger ElvUI fonts, and the complete workspace scrolls on small windows.

**Sets** provides 42 community collection/theme checklists, including Cozy Cottage, Rustic Tavern, Arcane Study, furniture categories, and faction themes. Choose a set, search its items, and switch to missing items only. Checkmarks and progress follow native ownership, including placed decor; item types absent from the current Blizzard catalog are **Unavailable** and excluded from known-item progress. Click an available item for catalog details. **Actions > Plan missing craftable decor** adds one craft per known missing craftable type while preserving larger quantities already planned. Sets are decorating suggestions, not official achievements, complete acquisition lists, or unlock requirements; memberships can overlap.

**Recipes** includes 325 bundled housing recipes across nine crafting professions. Search by decor, profession, or expansion; choose **My professions** or a specific profession; show planned recipes only. Click a recipe to set its number of crafts, inspect per-craft requirements in its tooltip, open the native profession recipe, track/untrack it, or select a permitted native reagent/quality alternative. Learned status belongs to the current character and remains pending when Blizzard has not supplied it. Open the relevant profession and refresh to load native recipe data. The catalog's bottom action opens crafting recipes for known craftable decor without a vendor route.

The crafting plan is account-wide. Quantities mean **crafts**, with a 0-999 limit per recipe; zero removes it. Native required reagent slots take priority over bundled per-craft estimates. Optional materials are omitted. Variable quantities or restricted/incomplete native data stay incomplete and block shopping exports rather than reverting to old estimates. Native output yields are displayed when available; output quantity never changes the requested number of crafts. Selected alternatives are tracked separately by item ID.

**Reagents** combines all planned requirements before subtracting inventory, so shared materials are counted once. The default scope is this character's bags; click the scope control to include personal/reagent banks and the warband bank as reported by Blizzard. Unknown counts stay unknown. Reagent choices come from each recipe's menu. Currency requirements remain visible alongside item reagents.

**Auctionator** is optional. Cached unit prices estimate the cost of missing materials; unpriced requirements are shown separately. **Actions > Export missing reagents to Auctionator** creates/replaces only the dedicated **ElementHousing Reagents** list, using localized exact names, missing quantities, and known reagent quality through Auctionator's public v1 API. It waits for item metadata and inventory counts. Auctionator may start its list search if the auction house is open; purchases remain manual. Refresh after an Auctionator scan to see updated cached estimates.

**Kaliel's Tracker** is optional. Recipe **Track / untrack** uses Blizzard's native tracked-recipe API. Kaliel displays those recipes when its profession tracking module is enabled; otherwise they use Blizzard's tracker. Tracking never clears another recipe. The native tracker shows its own per-recipe reagent requirements and does not mirror account-plan craft quantities or custom themed checklists. Recipe opening, tracking, and shopping exports require a click and defer during combat.

All controls inherit ElvUI fonts, colors, UI scale, and status bar textures. Both integrations are optional TOC dependencies; ElvUI remains the sole requirement. The [bundled source/license notes](Data/SOURCES.md) document pinned memberships, recipe estimates, and refresh instructions.

## Neighborhood and House

Both tabs use responsive dashboards with a branded location header, summary tiles, native progress graphs, and grouped detail cards. Cards sit side by side on wide windows and stack on smaller windows; text reflows with ElvUI's configured font size. The full page scrolls, and **Identifiers > Show** reveals technical IDs when needed.

The **Neighborhood** tab (or `/eh neighborhood`) shows your current neighborhood's name, location, type, owner, your owner/manager role, faction compatibility, available plots, occupancy, plot owners, known prices, and map coordinates. Its occupancy meter and plot-position chart use Blizzard's reported data; hover a marker for its plot, owner, and price. Full plot, resident, and endeavor task directories remain available below the overview, with wrapping rows and hover details. Endeavor and milestone meters show available progress alongside contribution and rewards. Resident details appear after Blizzard supplies the roster while you visit the neighborhood bulletin board. Traveling changes the displayed neighborhood; unavailable details remain unknown.

The **House** tab (or `/eh house`) lists your account's owned houses and lets you choose one without changing Blizzard's tracked house. It defaults to the owned home you are visiting, or the first reported home. Summary tiles show level, XP still needed, decor, and rooms. The XP graph measures progress within the current level, and the details retain identity, owner, neighborhood, plot, known cost/reservation information, and received unlock rewards. While at that selected house or plot, separate interior, exterior, and room budget meters show actual usage/capacity. The page also shows current-area decor counts, rooms/floors, exterior style/size, refund amount, and visitor/blueprint permissions.

Both pages use read-only housing getters and documented asynchronous data requests. Information follows housing notifications and the Refresh button; requests defer during combat. Visiting another player's house never treats it as yours. Housing snapshots are session-only, and these pages follow the same native ElvUI appearance settings as the catalog.

## Vendor waypoints

Waypoints use Blizzard's content-tracking coordinates or a verified merchant visit for the selected decor, then fall back to **243 bundled known vendor positions**. Known vendors such as Dethelin work before a shop visit when Blizzard supplies the vendor identity but no destination. A missing preferred-map result also queries the player's map and known source maps. Verified visits on the current map take priority, choosing the nearest visited seller unless a specific vendor is selected. Visit locations are approximate because they record the player's position while the shop is open.

The library uses exact catalog vendor names and native map/zone evidence for names shared by different zones. Automatic library destinations respect known faction restrictions. Static coordinates do not establish current inventory, price, reputation, phasing, or endeavor/event availability; unseen prices remain **Unknown**. If a vendor is unlisted or cannot be identified, opening its shop still learns the route and purchase currencies without buying anything. English vendor names are covered by the bundled data; native tracking and merchant observations continue to support localized vendor names.

Pending, unknown, invalid, or non-vendor destinations leave existing map pins intact. Replacing an existing user waypoint requests confirmation by default. Supertracking and replacement confirmation are configurable. Waypoint changes and blueprint operations are blocked during combat.

## Decor browsing and neighborhood maps

The catalog's **Culture**, **Material**, **Color**, and **Room type** selectors combine with collection, source, zone, and other filters. They support saved presets and `culture:`, `material:`, `color:`, and `room:` searches. **Unclassified** finds records without a label for that facet. The bundled classifications cover **1,657 items** and are community visual/keyword suggestions, including image-derived tags; they are separate from Blizzard's requirements and do not classify an item's acquisition or unlocks. Details label them as community tags. [Source revision, license, and refresh instructions](Data/SOURCES.md) accompany the data.

The Neighborhood dashboard draws Blizzard's current map artwork and numbered plot markers. Wheel or use **+ / -** to zoom, drag to pan, and use **Reset** for the full map. Switch between all, unowned, occupied, owned, or unknown plots. An asterisk marks a plot from your known house list, faded markers show unowned plots, and the arrow follows your current native map position. Hover for full details; click a plot to set a supported native waypoint.

Toggle **Vendors** for bundled neighborhood vendor positions. Vendors sharing a location appear together in the hover description; static pins may require the matching endeavor or event to be present. Plot and vendor clicks respect existing-waypoint confirmation and recheck combat and current neighborhood when accepted. Missing map artwork retains a coordinate grid; missing plot/player coordinates are not fabricated. All map controls follow ElvUI appearance settings.

## Development and verification

Version: **2.0.8**. Interface target: **120100**. Account-wide saved variable: `ElementHousingDB`. Existing compatible root settings/favorites are preserved; the imported suite is not loaded.

Run `tests/run.py` with Python and `lupa` providing Lua 5.1. The checks compile every Lua file, verify TOC paths, exercise the actual bundled launcher libraries against explicit native frame contracts, test filter/zone/waypoint/blueprint behavior, cover the profession shortcut across character skill combinations, PvP evidence/presets, expansion/currency combinations, merchant observations, and asynchronous housing data/context changes. They validate the options against the installed ElvUI AceConfig registry when available. The integration matrix covers ElvUI alone, each optional plugin, and both plugins together using installed ElvUI font/status helpers, its actual sidebar builder/core-page snapshot, and AceConfig sorting. It verifies native appearance changes on existing controls, legacy override retirement, dependency metadata, and all 17 packaged textures.

These are offline checks. Verify in-game after `/reload`: ElvUI-only startup and bundled icons, plugin position/title/tree, font/outline/scale/texture/color changes through ElvUI, optional WindTools minimap collection and shadows, catalog loading, optional nMediaTag icon rendering, the My professions shortcut, PvP filtering, Neighborhood/House replies while traveling or choosing houses, bulletin-board residents, expansion/currency selectors, merchant observations and vendor waypoints, interactive 3D camera controls, resize/scroll behavior at your UI scale, current-zone source completeness, and live blueprint collection/import/export replies.

Dashboard checks additionally cover graph values, pooled controls, expandable IDs, marker tooltips, unknown/over-budget states, and layouts at three widths and three ElvUI font sizes. `tools/render_dashboard.py --output-dir <directory>` exports SVG layout previews from the actual controls using illustrative data and approximate font metrics; these previews are separate from in-game screenshots.

Bundled-data checks cover every coordinate and tag, ambiguity/faction handling, fresh-account routing and native priority, unknown prices, combined selectors/searches/presets, and font-aware sidebar reachability. Native map contracts cover complete/partial tile geometry, aspect ratio, zoom limits, pan bounds, pooled pins, plot filters, live player movement, missing/restricted data, vendor grouping, and acceptance after combat/travel. Verify actual map textures, zoom/pan, pin legibility, both neighborhood layouts, vendor availability, and decor classifications in-game after `/reload`.

Map API reference: [Blizzard-generated map artwork and waypoint definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua).

Appearance references: [ElvUI templates and font registration](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/General/Toolkit.lua), [native media update registries](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/General/Core.lua), and [UI scaling](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/Game/Shared/General/PixelPerfect.lua).

Housing information references: [native house API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/HousingUIDocumentation.lua), [neighborhood API definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/HousingNeighborhoodUIDocumentation.lua), [endeavors](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/NeighborhoodInitiativeDocumentation.lua), and [Blizzard's visitor permissions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_HousingHouseSettings/Blizzard_HousingHouseSettings.lua).

API references: [Blizzard-generated catalog/searcher definitions](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/HousingCatalogSearcherAPIDocumentation.lua), [content tracking](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContentTrackingDocumentation.lua), [blueprints](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/HousingBlueprintUIDocumentation.lua), and [native model previews](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_HousingModelPreview/Blizzard_HousingModelPreview.lua).
