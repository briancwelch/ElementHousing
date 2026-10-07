"""Run native addon contracts in Lua 5.1; no WoW client or server is simulated."""
from pathlib import Path
import re
import struct
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval("function(code, name) local f, e = loadstring(code, name); return f, e end")
for path in ROOT.rglob("*.lua"):
    chunk, error = compile_lua(path.read_text(encoding="utf-8-sig"), str(path))
    assert chunk is not None, error

def load_addon(runtime):
    """Load the real TOC into an isolated contract environment."""
    runtime.execute((ROOT / "tests" / "native_contract.lua").read_text(encoding="utf-8"))
    namespace = runtime.table()
    loader = runtime.eval("function(code, name) local f, e = loadstring(code, name); return f, e end")
    for line in (ROOT / "ElementHousing.toc").read_text(encoding="utf-8").splitlines():
        if line.endswith(".lua"):
            path = ROOT / line.replace("\\", "/")
            assert path.is_file(), f"Missing TOC file: {path}"
            chunk, error = loader(path.read_text(encoding="utf-8-sig"), str(path))
            assert chunk is not None, error
            chunk("ElementHousing", namespace)
    runtime.globals().EH = namespace
    return namespace

addon = load_addon(lua)
lua.globals().EH = addon
lua.execute((ROOT / "tests" / "behavior.lua").read_text(encoding="utf-8"))

# Validate the options using the installed ElvUI AceConfig schema validator.
validator = ROOT.parent / "ElvUI_Libraries/Game/Shared/Ace3/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua"
if validator.is_file():
    chunk, error = compile_lua(validator.read_text(encoding="utf-8-sig"), str(validator))
    assert chunk is not None, error
    chunk()
    lua.execute('LibStub("AceConfigRegistry-3.0-ElvUI"):ValidateOptionsTable(EH.options, "ElementHousing")')
    print("Installed ElvUI AceConfig validation: PASS")
print(f"Lua 5.1 syntax and TOC: PASS; {lua.globals().checks} behavioral checks passed.")
fallback = LuaRuntime(unpack_returned_tuples=True)
load_addon(fallback)
fallback.execute((ROOT / "tests" / "fallback.lua").read_text(encoding="utf-8"))
print(f"Required ElvUI dependency: {fallback.globals().checks} checks passed.")
failure = LuaRuntime(unpack_returned_tuples=True)
load_addon(failure)
failure.execute('''
EH:Initialize()
-- Inject a failed control factory to verify the parent remains hidden after construction fails.
EH.CreateDetails = function() error("forced construction failure") end
Check(EH:Show() == false and not EH.frame:IsShown(), "Interrupted construction leaves no visible window")
Check(EH:Show() == false and not EH.frame:IsShown(), "Launcher cannot expose a partially built window")
Check(messages[1]:find("forced construction failure", 1, true), "Construction failure remains reviewable")
''')
print(f"Interrupted construction: {failure.globals().checks} checks passed.")
professions = LuaRuntime(unpack_returned_tuples=True)
load_addon(professions)
professions.execute((ROOT / "tests" / "professions.lua").read_text(encoding="utf-8"))
print(f"All-profession eligibility matrix: {professions.globals().checks} checks passed.")
acquisition = LuaRuntime(unpack_returned_tuples=True)
load_addon(acquisition)
acquisition.execute((ROOT / "tests" / "acquisition.lua").read_text(encoding="utf-8"))
print(f"Vendor routes and acquisition filters: {acquisition.globals().checks} checks passed.")


def load_native_elvui_helpers(runtime):
    """Exercise installed ElvUI font/status registries and AceConfig sorting, not copied approximations."""
    general = ROOT.parent / "ElvUI/Game/Shared/General"
    toolkit = (general / "Toolkit.lua").read_text(encoding="utf-8-sig")
    fonts = toolkit.split("local function FontTemplate(", 1)[1].split("\nlocal function StyleButton", 1)[0]
    runtime.execute("""
local E = ElvUI[1]
local P = { general = { fontSize = 13, fontStyle = "OUTLINE" } }
local LSM = { Fetch = function(_, _, name) return name end }
local strsub = string.sub
NativeFontTemplate = function(""" + fonts)
    core = (general / "Core.lua").read_text(encoding="utf-8-sig")
    for method in ("UpdateFontTemplate", "UpdateFontTemplates", "RegisterStatusBar", "UpdateStatusBars"):
        body = re.search(r"function E:" + method + r"\([^\n]*\).*?\nend", core, re.S)
        assert body, f"Missing installed ElvUI helper: {method}"
        runtime.execute("local E, next = ElvUI[1], next\n" + body.group())
    dialog = ROOT.parent / "ElvUI_Libraries/Game/Shared/Ace3/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua"
    sorter = dialog.read_text(encoding="utf-8-sig").split("local function compareOptions", 1)[1].split("\n--builds", 1)[0]
    runtime.execute("local tempOrders, tempNames\nlocal function compareOptions" + sorter + """
-- Feed real option data to the installed AceConfig comparator.
function SortNativeOptions(options)
    local keys = {}
    tempOrders, tempNames = {}, {}
    for key, option in pairs(options) do
        keys[#keys + 1] = key
        tempOrders[key], tempNames[key] = option.order, option.name
    end
    table.sort(keys, compareOptions)
    return keys
end
""")


native_helper_paths = (
    ROOT.parent / "ElvUI/Game/Shared/General/Toolkit.lua",
    ROOT.parent / "ElvUI/Game/Shared/General/Core.lua",
    ROOT.parent / "ElvUI_Libraries/Game/Shared/Ace3/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua",
)
if all(path.is_file() for path in native_helper_paths):
    for nmedia in (False, True):
        for windtools in (False, True):
            integration = LuaRuntime(unpack_returned_tuples=True)
            load_addon(integration)
            load_native_elvui_helpers(integration)
            integration.globals().nmediaLoaded = nmedia
            integration.globals().windtoolsLoaded = windtools
            integration.execute((ROOT / "tests/integrations.lua").read_text(encoding="utf-8"))
            print(f"Native ElvUI integration (nMediaTag={nmedia}, WindTools={windtools}): {integration.globals().checks} checks passed.")
else:
    print("Native ElvUI integration matrix skipped: install ElvUI and its libraries beside the addon.")

# Validate dependency metadata and the actual packaged TGA assets without another runtime dependency.
toc = (ROOT / "ElementHousing.toc").read_text(encoding="utf-8")
assert "## Dependencies: ElvUI\n" in toc
assert "## OptionalDeps: ElvUI_WindTools, ElvUI_mMediaTag\n" in toc
assert "## IconTexture: Interface\\AddOns\\ElementHousing\\Media\\Icon.tga" in toc
media = (ROOT / "Media.lua").read_text(encoding="utf-8")
names = re.findall(r"\b(\w+) = true", media.split("EH.brandIcon", 1)[0])
assets = [ROOT / "Media/Icon.tga"] + [ROOT / "Media/Icons" / f"{name}.tga" for name in names]
for asset in assets:
    data = asset.read_bytes()
    width, height = struct.unpack_from("<HH", data, 12)
    size = 256 if asset.name == "Icon.tga" else 64
    assert data[:3] == bytes((0, 0, 2)), f"Expected uncompressed true-color TGA: {asset}"
    assert (width, height, data[16], data[17]) == (size, size, 32, 0x28), asset
    assert len(data) == 18 + size * size * 4, asset
    assert min(data[21::4]) == 0 and max(data[21::4]) == 255, f"Texture must contain transparent and visible pixels: {asset}"
assert len(set(asset.read_bytes() for asset in assets)) == len(assets), "Each glyph must be distinct"
nmedia_assets = ROOT.parent / "ElvUI_mMediaTag/media/options"
if nmedia_assets.is_dir():
    for name in ["housing"] + names:
        assert (nmedia_assets / f"{name}.tga").is_file(), f"Installed optional glyph is missing: {name}"
print(f"Required/optional dependency metadata and {len(assets)} packaged textures: PASS")

print("Offline validation only. In-game rendering, actual source availability, and blueprint server replies require client verification.")
