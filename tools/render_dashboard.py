"""Render actual dashboard control geometry to SVG using sample public data, without a WoW client."""
from pathlib import Path
import argparse
import base64
import html
import math
import struct
import textwrap
import zlib
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def png_icon(path):
    """Read the bundled top-origin BGRA texture and encode the same pixels for an SVG preview."""
    data = path.read_bytes()
    width, height = struct.unpack_from("<HH", data, 12)
    assert data[:3] == bytes((0, 0, 2)) and data[16:18] == bytes((32, 0x28))
    pixels = data[18:]
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            b, g, r, a = pixels[(y * width + x) * 4:(y * width + x + 1) * 4]
            rows.extend((r, g, b, a))
    def chunk(kind, value):
        """Encode one standard PNG chunk without an image manipulation dependency."""
        return struct.pack(">I", len(value)) + kind + value + struct.pack(">I", zlib.crc32(kind + value))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
    return "data:image/png;base64," + base64.b64encode(png).decode()


def render(runtime, view, width, height, font_size):
    """Draw the renderer's real pooled card, label, meter, row, and plot-marker positions."""
    runtime.execute(f'ElvUI[1].db.general.fontSize = {font_size}; ElvUI[1]:UpdateFontTemplates(); EH:SetView("{view}")')
    page = runtime.globals().EH.infoPages[view]
    page.scroll.SetSize(page.scroll, width, height)
    runtime.globals().EH.RenderHousingInfo(runtime.globals().EH)
    widgets = []
    engine = runtime.globals().ElvUI[1]
    def color(value):
        """Convert native RGB colors to a portable SVG fill."""
        return "#" + "".join(f"{round(max(0, min(1, value[i] or 0)) * 255):02x}" for i in range(1, 4))
    def rect(x, y, w, h, fill, alpha=1, border=None):
        """Draw a native rectangle at its recorded geometry."""
        widgets.append(f'<rect x="{x:.2f}" y="{y:.2f}" width="{max(0,w):.2f}" height="{max(0,h):.2f}" fill="{fill}" fill-opacity="{alpha}"'
                       + (f' stroke="{border}"' if border else "") + '/>')
    def position(widget):
        """Resolve the TOPLEFT offsets used by the actual dashboard controls."""
        point = widget.points[1]
        if point is None:
            return 0, 0
        return (point[4] or 0, -(point[5] or 0)) if len(point) >= 5 else (point[2] or 0, -(point[3] or 0))
    def text(label, origin_x, origin_y):
        """Approximate native font wrapping while preserving actual text and control positions."""
        if not label.IsShown(label):
            return
        x, y = position(label)
        value = label.GetText(label)
        fill = color(label.state_SetTextColor) if label.state_SetTextColor else "#ffffff"
        capacity = max(1, math.floor((label.width or 800) / (font_size * .58)))
        lines = []
        for line in value.splitlines() or [""]:
            lines.extend(textwrap.wrap(line, capacity) or [""])
        if label.state_SetJustifyH and label.state_SetJustifyH[1] == "CENTER":
            x, y = (label.parent.width or 0) / 2, 4
            anchor = "middle"
        else:
            anchor = "start"
        for index, line in enumerate(lines):
            widgets.append(f'<text x="{origin_x+x:.2f}" y="{origin_y+y+font_size+index*(font_size+2):.2f}" fill="{fill}" text-anchor="{anchor}">{html.escape(line)}</text>')
    border, accent = color(engine.media.bordercolor), color(engine.media.rgbvaluecolor)
    for _, card in page.cards.items():
        if not card.IsShown(card):
            continue
        x, y = position(card)
        rect(x, y, card.width, card.height, "#1b1b1b", border=border)
        icon_x, icon_y = position(card.icon)
        texture = card.icon.texture or ""
        name = Path(texture.replace("\\", "/")).name
        asset = ROOT / "Media" / ("Icon.tga" if name in ("housing.tga", "Icon.tga") else "Icons/" + name)
        if asset.is_file():
            widgets.append(f'<image x="{x+icon_x}" y="{y+icon_y}" width="{card.icon.width}" height="{card.icon.height}" href="{png_icon(asset)}"/>')
        map_x, map_y = (0, 0)
        if card.map:
            map_x, map_y = position(card.map.view)
            widgets.append(f'<clipPath id="neighborhood-map"><rect x="{x+map_x}" y="{y+map_y}" width="{card.map.view.width}" height="{card.map.view.height}"/></clipPath>')
            rect(x+map_x, y+map_y, card.map.view.width, card.map.view.height, "#202725", border=border)
            for button in (card.map.minus, card.map.plus, card.map.reset, card.map.plots, card.map.vendorToggle):
                bx, by = position(button)
                rect(x+bx, y+by, button.width, button.height, "#292929", button.alpha, border)
                text(button.text, x+bx, y+by)
            widgets.append('<g clip-path="url(#neighborhood-map)">')
        for _, grid in card.grid.items():
            if grid.IsShown(grid):
                gx, gy = position(grid)
                rect(x+map_x+gx, y+map_y+gy, grid.width, grid.height, border, .35)
        if card.map:
            for _, marker in card.markers.items():
                if marker.IsShown(marker):
                    mx, my = position(marker)
                    rect(x+map_x+mx, y+map_y+my, marker.width, marker.height, color(marker.fill.color), marker.fill.alpha or 1, border)
                    widgets.append(f'<text x="{x+map_x+mx+marker.width/2}" y="{y+map_y+my+marker.height/2+font_size*.35}" text-anchor="middle" fill="#ffffff">{html.escape(marker.number.GetText(marker.number))}</text>')
            if card.map.player.IsShown(card.map.player):
                px, py = position(card.map.player)
                widgets.append(f'<circle cx="{x+map_x+px+11}" cy="{y+map_y+py+11}" r="8" fill="#ffffff"/>')
            widgets.append('</g>')
        for _, bar in card.bars.items():
            if bar.IsShown(bar):
                bx, by = position(bar)
                rect(x+bx, y+by, bar.width, bar.height, "#242424", border=border)
                rect(x+bx, y+by, bar.width*bar.fraction, bar.height, accent)
                text(bar.text, x+bx, y+by)
        for _, row in card.rows.items():
            if row.IsShown(row):
                rx, ry = position(row)
                rect(x+rx, y+ry, row.width, row.height, border, row.shade.alpha or .1)
                for _, label in row.cells.items():
                    text(label, x+rx, y+ry)
        for _, label in card.labels.items():
            text(label, x, y)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><rect width="100%" height="100%" fill="#151515"/><g font-family="Consolas, monospace" font-size="{font_size}">' + "".join(widgets) + "</g></svg>"


def main():
    """Load the real addon and layout fixture, then export both visible dashboard viewports."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--width", type=int, default=1240)
    parser.add_argument("--height", type=int, default=1000)
    parser.add_argument("--font-size", type=int, default=16)
    args = parser.parse_args()
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute((ROOT / "tests/native_contract.lua").read_text(encoding="utf-8"))
    namespace = runtime.table()
    loader = runtime.eval("function(code) return assert(loadstring(code)) end")
    for line in (ROOT / "ElementHousing.toc").read_text(encoding="utf-8").splitlines():
        if line.endswith(".lua"):
            loader((ROOT / line.replace("\\", "/")).read_text(encoding="utf-8-sig"))("ElementHousing", namespace)
    runtime.globals().EH = namespace
    runtime.execute((ROOT / "tests/dashboard.lua").read_text(encoding="utf-8"))
    runtime.execute("SetupDashboardFixture()")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for view in ("neighborhood", "house"):
        output = args.output_dir / f"{view}-{args.width}-{args.font_size}.svg"
        output.write_text(render(runtime, view, args.width, args.height, args.font_size), encoding="utf-8")
        print(output)
    print("Offline layout preview with sample data. Font metrics are approximate; this is not an in-game screenshot.")


if __name__ == "__main__":
    main()
