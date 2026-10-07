"""Run native addon contracts in Lua 5.1; no WoW client or server is simulated."""
from pathlib import Path
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
print(f"Standalone client: {fallback.globals().checks} checks passed.")
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
print("Offline validation only. In-game rendering, actual source availability, and blueprint server replies require client verification.")
