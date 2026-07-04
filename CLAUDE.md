# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`THexColorPicker` (unit `HexColorPickerFmx`), a honeycomb/hexagonal color-picker
control for **FireMonkey (FMX), Delphi 13**. It is an FMX port of the VCL
`THexaColorPicker` from mbColorLib.

The class and unit were deliberately renamed — dropping the "a":
`THexaColorPicker` → **`THexColorPicker`**, `HexaColorPicker` →
**`HexColorPickerFmx`** — so this control can coexist with the original VCL
mbColorLib (installed as `mbColorLibDXE8.bpl`, "mbColor Lib v2.0.2"), which still
ships a `HexaColorPicker` unit and a `THexaColorPicker` class. Two loaded
packages cannot both own a unit of the same name, so the rename is what lets both
be installed at once. (This unit-name collision was the real cause of a long
string of misleading install errors — see Packaging below.)

The control is **self-contained: it depends only on RTL + FMX.** The legacy VCL
helper units that came with the original mbColorLib (HTMLColors, RGBHSLUtils,
RGBHSVUtils, RGBCMYKUtils, RGBCIEUtils, Scanlines) have been removed; the port
reimplements the few helpers it needs locally (`ColorToHex`, `FormatHint`, etc.).

A top-level `README.md` documents the component for end users (features, install,
quick start). There is no automated test suite — verification is manual (drop it
on a form / run a demo).

## Repository layout

The repo is split into three folders by role; paths in the package/group files are
relative across these folders, so don't move files without fixing the references.

- `Source/` — the component source (`HexColorPickerFmx.pas`,
  `HexColorPickerFmxReg.pas`). This is the only hand-written code.
- `Package/` — the runtime + design packages and the project group
  (`HexColorPickerFmxRT.*`, `HexColorPickerFmxDT.*`, `HexColorPickerFmx.groupproj`).
  The `.dpk`s reference the source via `..\Source\…`.
- `Demo/` — demo application(s) (`DemoProject.dpr`/`.dproj`, `DemoMain.pas`/`.fmx`).
- `README.md`, `CLAUDE.md`, `roots.sst` — at the repo root.
- `__history/`, `__recovery/`, `Win64/`, `*.local` — IDE backups / build output;
  not source. The root `__history/` still holds files from the pre-rename
  (`HexaColorPicker*`) and pre-restructure days — ignore it.

## Files & packaging (installable component, runtime + design split)

- `Source/HexColorPickerFmx.pas` — the control (`THexColorPicker`, FMX `TControl`).
- `Package/HexColorPickerFmxRT.dpk` / `.dproj` — **runtime** package (`{$RUNONLY}`),
  requires `rtl`, `fmx`; contains `HexColorPickerFmx` (`in '..\Source\…'`). No IDE
  dependency — this is what apps link.
- `Package/HexColorPickerFmxDT.dpk` / `.dproj` — **design** package
  (`{$DESIGNONLY}`), requires `rtl`, `HexColorPickerFmxRT`; contains
  `HexColorPickerFmxReg` (`in '..\Source\…'`). Install this one.
- `Source/HexColorPickerFmxReg.pas` — holds `Register`
  (`RegisterComponents('mbColor Lib', [THexColorPicker])`). Kept out of the
  runtime unit so RT carries no design-time dependency.
- `Package/HexColorPickerFmx.groupproj` — the project group; builds RT then DT,
  and includes the demo via `..\Demo\DemoProject.dproj`.
- Demo: `Demo/DemoProject.dproj` (form `DemoMain`) is the demo and is the one
  wired into the group. It creates the control in code and links
  `..\Source\HexColorPickerFmx.pas` directly, so it runs without the package being
  installed.

### Packaging gotchas (all learned the hard way — do not "simplify" these away)

- **Unit-name collision is the thing that bites.** If the VCL mbColorLib
  (`mbColorLibDXE8`) is installed, it owns `HexaColorPicker`/`THexaColorPicker`.
  Symptoms were misleading (`[Fatal Error] Can't load package …, the system
  cannot find the file specified`). The `HexColorPickerFmx`/`THexColorPicker`
  rename fixes it permanently. Don't reintroduce the `Hexa`/`THexaColorPicker`
  names.
- **LIB suffix: use the explicit number `370`, NOT `Auto`.** `{$LIBSUFFIX AUTO}`
  was unreliable here — it failed to suffix the runtime BPL while suffixing the
  design BPL, producing a name mismatch. Set LIB suffix = `370` (Project Options ▸
  Description) on both packages → consistent `…370.bpl` for Win32 and Win64. The
  LIB suffix combo in that dialog **must not be left blank** — an empty field
  produces an un-suffixed BPL and the DT package can't find the suffixed RT name.
  Either type `370` or pick `$(Auto)` from the dropdown (prefer the explicit `370`,
  per the unreliability above).
- **Both packages need the same Build Control.** A design package set to
  "Explicit rebuild" (`{$IMPLICITBUILD OFF}`) that requires a runtime package set
  to "Rebuild as needed" (`{$IMPLICITBUILD ON}`) raises `E2466 Never-build package
  … requires always-build package …`. Set **both to "Explicit rebuild."**
- **Design package installs from Win32** (the IDE is 32-bit); the runtime package
  builds Win32 + Win64.
- BPL/DCP output goes to the defaults `$(BDSCOMMONDIR)\Bpl` / `\Dcp` (on the IDE
  path). Do not redirect package output to a project-local folder.
- **Component greyed out for Win64?** The control carries
  `[ComponentPlatformsAttribute(pidWin32 or pidWin64)]` (in `Source\HexColorPickerFmx.pas`,
  just before `THexColorPicker = class`) — that attribute, not the package's
  platform list, controls per-platform palette availability. The IDE reads it from
  the **Win32** runtime BPL it loads at design time, so after changing it you must
  rebuild the **Win32** runtime (rebuilding Win64 does nothing for the palette). If
  rebuilds seem ignored, the installed design package is holding the runtime BPL:
  uninstall DT, delete the stale BPLs in `$(BDSCOMMONDIR)\Bpl`, rebuild Win32 RT,
  reinstall DT, restart the IDE.

## Build / develop

- Compile in RAD Studio (Delphi 13 = product `37.0`; note the IDE install dir is
  also `37.0` — an unrelated `Studio\14.0` may exist on the machine, don't use its
  `rsvars.bat`). There is no compiler in this working environment — `.pas` changes
  can't be built here; the user builds in the IDE.
- Build order: `RT` before `DT` (the group enforces it). Then Install `DT`.
- **Win64 caveat:** never put `High(dynarray)` in a set constructor, e.g.
  `I in [0, High(FBWCombs)]` — it compiles on dcc32 but fails on dcc64 with
  `E2010 Incompatible types: 'Integer' and 'Int64'` (`High` of a dynamic array is
  `NativeInt` = `Int64` on Win64). Use `(I = 0) or (I = High(FBWCombs))`.

## Architecture

`Source/HexColorPickerFmx.pas` is the only component unit and is standalone.

- **`THexColorPicker` (FMX `TControl`).** Renders a hex grid of color "combs"
  (`TCombEntry`/`TCombArray`), a black-and-white comb strip, an intensity slider,
  and an opacity bar. The clever part — the comb-layout math in
  `CalculateCombLayout` (six interpolated sextants + the B&W ramp) — is pure
  arithmetic, unchanged from the VCL original. Hit-testing per region is split
  across `HandleColorComb`/`HandleBWArea`/`HandleSlider`/`HandleOpacity` (called
  via `HandleCustomColors`) and `PtInComb`. Selection state is keyed by
  `FSelectedIndex`/`FCustomIndex` with sentinels `CustomCell = -2` / `NoCell = -1`.
  All rendering happens inside `Paint` → `RenderCombs`; property setters call
  `Repaint`, never draw directly (FMX has no offscreen-then-blit model — there is
  no `TBitmap` buffer).

  Features added beyond the VCL original:
  - **Opacity (alpha) bar** below the combs (`RenderOpacityBar`/`HandleOpacity`,
    `smAlpha` selection mode, `SelectedAlpha`/`OpacityVisible` properties,
    `OnAlphaChange`). Alpha is kept separate from comb selection: combs are stored
    opaque, selection matching compares RGB only (`SameRGB`), and the chosen RGB
    is combined with `FAlpha` into `FCurrentColor` by `CommitColor` so picking a
    comb never resets opacity. `SelectedColor` is therefore a full ARGB value.
  - **Right-click "Copy" menu** with three live-value formats (`HexRGB`/`HexRGBA`/
    `HexARGB`, copied via `IFMXClipboardService`). Shown manually, not via the
    published `PopupMenu` (which stays the user's).
  - The intensity slider and opacity gradient use **FMX gradient brushes**
    (`TBrushKind.Gradient`), not per-row line drawing — smooth, no banding.

  FMX porting notes for future edits:
  - Colors are `TAlphaColor`. Local helpers `ColorToHex`, `FormatHint`, and
    `RGBFromFloat` replace the old VCL/`PalUtils` ones; `MakeColor` (FMX.Graphics)
    replaces Win32 `RGB`.
  - Internal layout still uses **integer** `TRect`/`TPoint`/`PtInComb` math;
    coordinates are converted to `TPointF`/`TPolygon` only at draw time.
  - The VCL XOR selection highlight has no FMX equivalent — the selected comb gets
    a **two-tone outline** (black halo + white core) in `OutlineComb`.
  - Per-pixel hover hints (the old `CM_HINTSHOW`) are approximated by setting the
    `Hint` property in `MouseMove` (`UpdateHint`).
  - `FInitialized` guards `Resize` so layout isn't computed before the constructor
    finishes wiring up `FCombCorners`/`FLevels`.

## Conventions

- Source uses a 1-space indentation style; match the surrounding style.
- Not a git repo; no compiler in this environment.
- `roots.sst` is a tooling/index artifact, not project source — do not edit it.
