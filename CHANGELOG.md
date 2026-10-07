# Changelog

## 2.0.3 - 2026-10-07

- Fix vendor waypoints stopping when Blizzard's preferred-map lookup has no result. Query the current and known source maps, validate native vendor coordinates, and retain existing-pin confirmation and combat protection.
- Learn catalog items, nearby locations, and all purchase components from merchants opened by the player. Save these account-wide as fallback vendor routes, respect the selected vendor, and prefer the nearest visited seller on the current map. Explain how to learn a route when native tracking has no destination.
- Add Expansion and Currency type selectors that combine with other catalog filters, reset, and saved presets. Prefer localized native expansion tags before item introduction metadata. Include gold, native currencies, item-token costs, mixed purchases, and explicit unknown choices; keep costs associated with their actual vendor.
- Extend offline checks for the Dethelin/Silvermoon Wooden Chair failure, missing preferred maps, observed alternatives, unsafe acquisition data, item-cache notifications, and the complete expansion/currency/ownership matrix. Preserve ElvUI options validation; in-game routing and rendering require client verification.

## 2.0.2 - 2026-10-05

- Apply profession eligibility consistently across every detected primary and secondary profession, every character skill combination, and characters with no professions. Refresh eligibility when skills change. Clarify that My professions is a general character filter; its header shortcut additionally selects missing decor, and restricting owned decor remains configurable.
- Normalize expansion skill lines, native recipe targets, recipe hyperlinks, and explicit profession selectors to the same base profession IDs. Preserve canonical localized profession names and reject incidental substring matches.
- Fix pending waypoint data bypassing known unrelated profession requirements. Keep unknown requirements or unavailable character skill data subject to the configured unknown-data policy; No profession-only decor excludes known profession routes even without a specific profession ID.
- Add an offline eligibility matrix for all primary profession pairs, all secondary subsets, empty/single/changing skill sets, owned states, alternate routes, localized names, expansion skills, recipe links, newly exposed profession IDs, and unavailable native metadata. Preserve the ElvUI options tree and existing native housing integrations.

## 2.0.1 - 2026-10-04

- Retain every known vendor and zone listed for a decor item. Match zone/vendor filters and field searches against all known alternatives. Resolve shared localized map names using native map IDs or the configurable unknown-location policy, while preserving Blizzard's native waypoint destination.
- Keep profession eligibility visible while source metadata is loading when unknown eligibility is enabled. Retain exclusion of unrelated profession-only missing decor once source data is available.
- Add nMediaTag acquisition icons to source selectors and show the complete known vendor/location list in Details. Keep the native catalog, 3D preview, blueprint library, resizable window, ElvUI settings tree, and WindTools launcher integration.
- Allow explicit browsing by a known zone name when its map is unavailable. Clear stale subcategory selections when changing category, filter child choices by parent, and sort source choices by their visible labels.
- Index zones from the public map root, including off-world regions. Prefer verified native map identities over same-name matches when location data is incomplete.
- Extend offline regression coverage for multiple acquisition locations/vendors, duplicate map names, pending profession metadata, and source-specific icons.

## 2.0.0 - 2026-10-04

- Replace the imported housing suite with a native ElementHousing implementation. Remove its runtime, controllers, themes, artwork, database dependencies, and startup window construction. Keep only standard shared launcher libraries.
- Build one lazy, resizable catalog/blueprint window with saved account-wide dimensions, position, favorites, and filter presets. Follow ElvUI's styling and fonts automatically, with nMediaTag control icons and a fixed native fallback. Retain the Mage-blue-to-Warlock-purple ElvUI plugin/menu branding and standard WindTools-compatible LibDBIcon launcher.
- Add combined ownership, acquisition source, current/specific zone, vendor, profession eligibility, category/subcategory, quality, size, placement, customization, and native tag/style filters. Support literal field searches, quoted phrases, exclusions, saved presets, Missing here, and My professions shortcuts.
- Detect the character's professions and exclude known unrelated profession-only missing decor while retaining owned decor and alternative vendor/drop/quest/achievement routes. Expose configurable unknown-data and subzone policies. Count stored, redeemable, and placed ownership; never treat unknown vendor costs as free.
- Add a native interactive 3D decor preview using Blizzard's model scenes and decor actor, with camera controls, reset, configurable dimensions, and icon fallback.
- Add Blizzard blueprint collection/shared-code browsing, saved-code management, requirements/missing quantities, progress, invalid entries, native budgets, and guarded native preview/import/export flows. Ignore stale content replies and retain native collection entries when forgetting a local code.
- Add validated vendor waypoints, optional supertracking, existing-pin confirmation, pending-data protection, and combat guards. Keep Blizzard housing frames and other installed addons untouched.
- Rebuild configuration as an ElvUI/WindTools-style left-hand tree with feature tabs and a complete editable standalone fallback. Cover window geometry, row display, models, filtering, loading batches, blueprints, launcher, and waypoint behavior; provide no theme selector.
- Add Lua 5.1/TOC checks, actual bundled launcher-library contract coverage, targeted catalog/filter/blueprint/waypoint/window checks, and installed ElvUI AceConfig validation. In-game rendering and server interactions remain pending client verification.

## 1.1.1 - 2026-10-04

- Fix an ElvUI button-skin startup crash by using Blizzard's dedicated ClearNormalTexture/ClearPushedTexture/ClearDisabledTexture APIs instead of passing nil to texture setters. Keep original icon-button states and text-button hover feedback.
- Hide main and floating windows immediately on creation, before theme/layout construction. An interrupted floating-window build can no longer leave an unregistered visible frame on screen.
- Enforce the native non-nil button asset contract in offline checks and exercise login window construction, saved visibility, and failure cleanup. Keep the independent catalog and existing minimap launcher.

## 1.1.0 - 2026-10-04

- Remove auction-house scans, TSM/Auctionator integration, Broker/Workshop profitability and optimization, crafting queues, profession scans, reagent warehouse, trainers, and profession-alt workspaces. Exclude their runtime modules, UI files, and unused databases from the addon.
- Remove crafting dashboard widgets, queued-craft milestones, recipe-sale lists/presets, project craft-queue buttons, and related settings. Retain 21 housing widgets, 10 collection/favorite/layout milestones, vendor shopping, currencies, 3D decor, blueprints, layouts, and neighborhood planning.
- Replace harvest/session tools with read-only housing resource balances. The Data page shows collection activity, saved-layout totals, and favorites; historical crafted entries do not inflate acquisition statistics.
- Add 31 original housing/control glyphs, distinct catalog shortcuts, a flat house-level badge/XP bar, and a clean trophy strip. Retain native item thumbnails and the supplied ElementHousing brand icon.
- Apply ElvUI colors, fonts, borders, and flat templates throughout suite panels and controls. Disable standalone theme/font choices while following ElvUI; preserve the independent theme fallback. Keep resizing, the class-color branding gradient, Alliance tips, and left-hand settings tree.
- Redirect saved removed workspaces to the house dashboard without clearing favorites, plans, or legacy saved data. Keep source adaptations reproducible and provenance hashes current; extend offline checks for selector dependencies, removed feature boundaries, and actual control styling.

## 1.0.2 - 2026-10-02

- Rename the Mogul workspace to Broker and its Goblin feature to Workshop across navigation, headings, exports, and feature descriptions. Preserve internal module/state keys and actual game item names; add `/eh broker`.
- Add native bottom-right resizing to the main window, with independent saved sizes per workspace. Reflow content columns and scroll areas while retaining navigation/chrome geometry; keep natural minimum sizes, current-screen limits, combat guards, and profile-scale updates. Add an enable switch and workspace-size reset under Housing suite > Appearance.
- Replace rotating Orc/Horde footer sayings with Alliance, Stormwind, Light, and Khaz Modan wording.
- Expand the trophy/profile card into Curator Hall with a mage-blue-to-warlock-purple tint, collected/missing decor and trophy counts, decor capacity, next-rank requirements, clickable milestone totals/progress, and house XP to the next level. Preserve the level ring, rank ladder, daily title, and trophy shelf; provide compact rendering for shorter cards.
- Add settings for header tint/strength and each information section. Raise the default card height to 260 pixels and refresh memoized dashboard data after settings changes.
- Extend offline checks for resize callbacks, per-workspace persistence/composition, screen/scale bounds, feature naming, real item-name preservation, Alliance wording, and header facts. Keep upstream changes reproducible through the importer and updated provenance hashes.

## 1.0.1 - 2026-10-02

- Embed the original decor catalog in the main housing window as a Catalog workspace, with an addon icon in the sidebar and a title-bar shortcut. Route `/eh catalog` and settings launchers to this workspace.
- Reuse catalog filters, favorites, vendor observations, row models, and the independent native searcher. Suspend catalog refreshes and release search focus while its workspace or containing window is hidden.
- Let the main window own embedded geometry, scale, movement, and Escape closing. Disable standalone geometry controls in settings while using the suite launcher; retain the independent catalog and its saved dimensions when using the original launcher.
- Rename the catalog settings groups to match the integrated workspace. Add regression coverage for host visibility, view navigation, resizing, persistence, fallback behavior, and complete layout-schema composition.

## 1.0.0 - 2026-10-01

- Expand ElementHousing into a housing suite using namespaced, MIT-licensed Housing Decor Guide 3.34.1 code. Retain license, source revision, attribution, a reproducible import tool, and file hashes; exclude upstream artwork, developer commands, private diagnostic probes, and Blizzard-frame overlays.
- Add a configurable 23-widget housing dashboard: decorator titles and progress, source/expansion donut charts, currencies, lumber, house levels and rewards, capacity, collection velocity, favorites, activity, acquisition suggestions, and neighborhood initiative information.
- Add 12 persistent ElementHousing milestones with progress bars and optional chat announcements. Keep these separate from Blizzard achievements; retain earned timestamps and lifetime queued-craft totals.
- Add the full decor browser with interactive 3D models, dyes, preview backgrounds, and placeable pets; preserve the original catalog through `/eh catalog`.
- Add acquisition/vendor browsing, shopping lists and shared list codes, zone alerts, crafting queues, professions, reagents, lumber sessions, trainer directories, price integrations, and crafting/collection optimization.
- Add styles, saved snapshots, smart sets, furnishing sets, multi-floor architect planning, saved layouts, and interoperable layout codes.
- Add Blizzard 12.1 blueprint browsing, requirement inspection, saved/share-code management, and import through Blizzard's preview/confirmation dialog.
- Add Alliance/Horde neighborhood plot maps, facing diagrams, and a plot-to-plot move orientation planner.
- Reorganize ElvUI settings into a left-hand feature tree with tabs within sections. Preserve the bundled icon, mage-blue-to-warlock-purple branding, and plugin/version header registration.
- Expose suite themes, scale, language, fonts, model backgrounds, dashboard geometry, milestones, alerts, price/waypoint integrations, and separate suite profiles. Give native menus dynamic profile choices, validated text entry, and exact numeric values.
- Keep the placement companion in its own window, with placement clicks gated by an active Blizzard house editor and combat state. Do not replace native catalog/editor controls or call restricted placed-decor enumeration APIs.
- Add bounded shared-code parsing and offline checks for the full TOC, module startup, action metadata, profile persistence, milestones, charts, currencies, sharing codecs, blueprint routing, and installed ElvUI options validation. In-game rendering and server interactions remain pending verification.

## 0.2.3 - 2026-10-01

- Add ElementHousing's icon, mage-blue-to-warlock-purple name gradient, and version to the ElvUI configuration header alongside other plugins.
- Use the same icon and gradient in the ElvUI sidebar menu item. Preserve other plugins' labels and avoid duplicate header entries when the options callback runs again.
- Share the bundled icon path with the minimap launcher; retain the plain standalone configuration label.

## 0.2.2 - 2026-09-22

- Hide the catalog Settings button when ElvUI is loaded; configuration remains available under ElvUI. Keep the button visible for standalone use, including when ElvUI is disabled.

## 0.2.1 - 2026-09-22

- Add a subtle static teal-to-slate background gradient, enabled by default at 30% strength.
- Add live Appearance controls for enabling the gradient, both colors, strength, four directions, and a gradient-only reset. Color pickers also work in the standalone settings menu.
- Preserve separate background/window opacity controls and keep the gradient behind content without changing ElvUI/WindTools registration.
- Add a darker inset behind Details with independent opacity control.
- Add a bottom-right resize grip, saved window dimensions, responsive list/details layout, position-and-size lock, and a size reset. Preserve the backdrop template's resize handler.
- Replace the ambiguous Unowned toggle with Show unowned: Off hides zero-owned items; On includes them. Default to owned decor and migrate the old Off state once. Unowned-only browsing remains in the Ownership filter.

## 0.2.0 - 2026-09-22

- Add an ElementHousing configuration page through the same LibElvUIPlugin registration API used by WindTools, with startup registration deferred until PLAYER_LOGIN and an isolated options-builder callback.
- Add appearance, behavior, mouse-action, minimap, quality/source/tag filtering, and confirmed saved-data reset controls. Settings remain account-wide.
- Add a catalog Settings button, `/eh config`, and standalone native configuration menus when ElvUI is disabled.

## 0.1.2 - 2026-09-22

- Bundle the supplied ElementHousing artwork as a WoW-compatible TGA texture and use it for the minimap launcher and addon-compartment icon, replacing the blank placeholder.

## 0.1.1 - 2026-09-22

- Replace the stretched horizontal options-slider artwork with a solid vertical item scrollbar and proportional thumb.
- Middle-click now toggles a decor favorite; right-click sets and super-tracks a vendor waypoint from Blizzard's decor-source tracking data.
- Keep existing waypoints unchanged when vendor data is missing/loading, the source is not a vendor, or the destination does not support user pins. Update row tooltips and click guidance.

## 0.1.0 - 2026-09-22

- Initial standalone Midnight 12.1.0 decor catalog, independent of Blizzard's housing catalog and editor frames.
- Category/subcategory navigation, literal search, native expansion/source tag filters, quality, size, ownership, indoor/outdoor, customization, house-XP and favorites filters.
- Multiple sorting modes, compact rows, pooled icon/model thumbnails, source details, and saved preferences.
- Merchant-observed gold/currency/item costs with explicit unknown-price handling.
- Optional ElvUI styling and a LibDBIcon minimap launcher compatible with standard button collectors, including WindTools. Clicking toggles the catalog open/closed.
- Slash commands, addon-compartment access, key binding, combat refresh deferral, and isolated Lua tests.
