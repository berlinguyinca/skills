# GW-Skills PowerPoint Design System

Canonical design system for all gw-skills presentations.

## Color Palette

```python
PRIMARY      = RGBColor(0x2C, 0x3E, 0x50)  # dark blue-gray — titles, headers
SECONDARY    = RGBColor(0x34, 0x49, 0x5E)  # medium blue-gray — body text
ACCENT       = RGBColor(0x34, 0x98, 0xDB)  # bright blue — highlights, KPIs
SUCCESS      = RGBColor(0x27, 0xAE, 0x60)  # green — improvements, fixed items
DANGER       = RGBColor(0xE7, 0x4C, 0x3C)  # red — critical issues
WARNING      = RGBColor(0xF3, 0x9C, 0x12)  # amber — warnings
MUTED        = RGBColor(0x95, 0xA5, 0xA6)  # gray — captions, labels
BG_WHITE     = RGBColor(0xFF, 0xFF, 0xFF)
BG_LIGHT     = RGBColor(0xF8, 0xF9, 0xFA)
```

## Layout

- Font: Calibri throughout
- Slide dimensions: 16:9 widescreen (13.333" x 7.5")
- Accent bar: 0.06" wide ACCENT strip at left edge of every slide

## Execution

Generate presentations using `python-pptx`. Execute via:

```bash
uv run --with python-pptx python /tmp/<script-name>.py
```

Fallback if `uv` is not available: `python3 -m pip install python-pptx && python3 /tmp/<script-name>.py`

## Output Location

Save all presentations to `docs/gw/` in the project root. Create the directory if it doesn't exist.
