"""Render actual collection/crafting control positions with sample data and approximate fonts."""
import argparse
import html
import math
from pathlib import Path
import textwrap
from lupa.lua51 import LuaRuntime
from render_dashboard import png_icon, ROOT


def preview(runtime, mode, width, height, font):
    """Export a full scrolling content preview from the addon's real layout and row pool."""
    runtime.execute(f'ElvUI[1].db.general.fontSize = {font}; ElvUI[1]:UpdateFontTemplates(); EH.frame:SetSize({width}, {height}); EH:SetProjectMode("{mode}")')
    eh, widgets = runtime.globals().EH, []
    page = eh.projects
    page.root.SetSize(page.root, width - 24, height - 126)
    eh.RenderProjects(eh)
    content_width, content_height = page.panel.width, page.panel.height

    def position(widget):
        """Read actual TOPLEFT offsets without pretending to render Blizzard frame anchors."""
        point = widget.points[1]
        return (point[4] or 0, -(point[5] or 0)) if point and len(point) >= 5 else (0, 0)

    def rect(widget, fill='#242424'):
        """Draw a native control background at its actual recorded size and position."""
        x, y = position(widget)
        widgets.append(f'<rect x="{x}" y="{y}" width="{widget.width}" height="{widget.height}" fill="{fill}" stroke="#414141"/>')

    def label(widget, x=0, y=0, width=None, center=False, accent=False):
        """Approximate native wrapping and clipping while retaining every displayed string."""
        value = eh.Plain(eh, widget.GetText(widget))
        if isinstance(value, tuple):
            value = value[0]
        capacity = max(1, math.floor((width or widget.width or content_width) / (font * .58)))
        wrapped = widget.state_SetWordWrap is None or widget.state_SetWordWrap[1]
        lines = []
        for line in value.splitlines():
            lines.extend(textwrap.wrap(line, capacity) if wrapped else [line[:capacity]])
        color = '#4cccdf' if accent else '#eeeeee'
        for index, line in enumerate(lines):
            widgets.append(f'<text x="{x}" y="{y+font+index*(font+2)}" fill="{color}" text-anchor="{"middle" if center else "start"}">{html.escape(line)}</text>')

    for button in [page.tabs.sets, page.tabs.recipes, page.tabs.reagents, page.select, page.action, page.toggle]:
        rect(button); x, y = position(button)
        label(button.text, x + button.width / 2, y + 5, button.width - 36, True)
    rect(page.search); x, y = position(page.search)
    label(page.search, x + 7, y + 5, page.search.width - 14)
    for name in ('searchLabel', 'title', 'description', 'summary'):
        widget = page[name]; x, y = position(widget)
        label(widget, x, y, accent=name == 'title')
    if page.progress.IsShown(page.progress):
        rect(page.progress); x, y = position(page.progress)
        widgets.append(f'<rect x="{x}" y="{y}" width="{page.progress.width*page.progress.value}" height="{page.progress.height}" fill="#267b86"/>')
        label(page.progress.text, x+page.progress.width/2, y+5, page.progress.width-10, True)
    bx, by = position(page.body)
    for _, row in page.rows.items():
        if not row.IsShown(row):
            continue
        x, y = position(row); x += bx; y += by
        widgets.append(f'<rect x="{x}" y="{y}" width="{row.width}" height="{row.height}" fill="#1d1d1d" stroke="#414141"/>')
        asset = ROOT / 'Media/Icons' / ('shop.tga' if mode == 'reagents' else 'collection.tga')
        widgets.append(f'<image x="{x+8}" y="{y+12}" width="28" height="28" href="{png_icon(asset)}"/>')
        label(row.name, x+58, y+6, row.name.width)
        label(row.meta, x+58, y+row.height-font-11, row.meta.width)
        label(row.value, x+row.width-row.value.width-8, y+row.height-font-11, row.value.width, accent=True)
        if row.check.IsShown(row.check):
            widgets.append(f'<path d="M {x+31} {y+27} l 5 5 l 10 -13" fill="none" stroke="#4cccdf" stroke-width="3"/>')
    label(page.hint, 12, content_height-page.hint.GetStringHeight(page.hint)-9, page.hint.width)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{content_width}" height="{content_height}"><rect width="100%" height="100%" fill="#171717"/><g font-family="Consolas,monospace" font-size="{font}">' + ''.join(widgets) + '</g></svg>'


def main():
    """Load the real addon and create illustrative ownership and crafting snapshots."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args()
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute((ROOT / 'tests/native_contract.lua').read_text(encoding='utf-8'))
    namespace = runtime.table()
    loader = runtime.eval('function(code) return assert(loadstring(code)) end')
    for line in (ROOT / 'ElementHousing.toc').read_text().splitlines():
        if line.endswith('.lua'):
            loader((ROOT / line.replace('\\', '/')).read_text(encoding='utf-8-sig'))('ElementHousing', namespace)
    runtime.globals().EH = namespace
    runtime.execute('''
EH:Initialize()
local set = EH:CollectionSet("cozy-cottage")
C_Item.GetItemNameByID = function(id) return EH.collectionItemNames[id] end
C_Item.GetItemCount = function() return 0 end
for index, id in ipairs(set.items) do
    catalog[#catalog + 1] = { recordID = index, entryType = 1, itemID = id, name = EH.collectionItemNames[id] or "Sample decor",
        sourceText = "", totalNumStored = index % 3 == 0 and 1 or 0, totalNumPlaced = 0, remainingRedeemable = 0 }
end
EH:Show("collections"); Drain()
EH.db.craftPlan = { [1229000] = 2, [1229001] = 1, [1233132] = 1 }
''')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for width, height, font in ((1140, 720, 13), (760, 480, 28)):
        for mode in ('sets', 'recipes', 'reagents'):
            path = args.output_dir / f'{mode}-{width}-{font}.svg'
            path.write_text(preview(runtime, mode, width, height, font), encoding='utf-8')
            print(path)
    print('Offline sample preview. Fonts and icons are approximate; this is not an in-game screenshot.')


if __name__ == '__main__':
    main()
