# Tutorial: Building an installable FireMonkey component (runtime + design-time packages)

This tutorial walks through everything needed to turn a FireMonkey (FMX) control into a component you can **drag from the Tool Palette onto a form** — including the
parts that are easy to get wrong: the runtime/design-time package split, the version suffix on the BPLs, and the one attribute that makes the component available for **Win64** at design time.

It was written alongside the `THexColorPicker` control in this repository, so the advice here is the same hard-won advice that control's packaging is built on.

> Built and tested with **Delphi 13 (RAD Studio 37.0)**. The version number `37.0`
> and the matching package suffix `370` recur throughout — substitute your own
> Delphi version where appropriate (see *The version suffix* below).

---

## 1. What you'll build

A tiny but complete component, **`TColorClicker`**:

- descends from the FMX base class `TControl`;
- draws a filled rectangle;
- picks a **random color every time it is clicked**;
- exposes a `Color` property and an `OnColorChange` event;
- installs onto the Tool Palette and works at design time on **Win32 and Win64**.

It's deliberately trivial so the *packaging* is the star. The structure mirrors the recommended layout:

```
Source/
  ColorClickerFmx.pas        the control (TColorClicker)
  ColorClickerFmxReg.pas     design-time Register
Package/
  ColorClickerFmxRT.dpk      runtime package
  ColorClickerFmxDT.dpk      design-time package (install this one)
  ColorClickerFmx.groupproj  project group (build RT -> DT)
```

---

## 2. The two-package model (and why)

A Delphi component is shipped as **two** packages:

| Package | Directive | Contains | Requires | Role |
|---|---|---|---|---|
| **Runtime (RT)** | `{$RUNONLY}` | the control unit | `rtl`, `fmx` | What end-user apps link against. **No IDE dependency.** |
| **Design-time (DT)** | `{$DESIGNONLY}` | the `Register` unit | `rtl`, the RT package | What you **Install** into the IDE so the component appears on the palette. |

Why split them?

- **Apps must not drag the IDE in.** If `Register`/palette code lived in the  runtime package, every shipped application would depend on design-time
  machinery. Keeping `RUNONLY` clean is the whole point.
- **Only the DT package is installed.** "Install" means "load this BPL into the  running IDE." You install the DT package; it `requires` the RT package, so the
  IDE loads both.

The golden rule: **the runtime unit knows nothing about registration.** The `Register` procedure lives in a *separate* unit that goes only into the DT package.

---

## 3. The control — `Source/ColorClickerFmx.pas`

```pascal
unit ColorClickerFmx;

// A minimal installable FireMonkey control: a rectangle that picks a random
// color each time it is clicked. Depends only on the RTL and FMX.

interface

uses
  System.Classes, System.UITypes, System.UIConsts,
  FMX.Types, FMX.Controls, FMX.Graphics;

type
 // This attribute is what makes the component available for BOTH platforms on
 // the palette. See "Win64 at design time" below - it is NOT optional.
 [ComponentPlatformsAttribute(pidWin32 or pidWin64)]
 TColorClicker = class(TControl)
 private
  FColor: TAlphaColor;
  FOnColorChange: TNotifyEvent;
  procedure SetColor(const Value: TAlphaColor);
 protected
  procedure Paint; override;
  procedure Click; override;
 public
  constructor Create(AOwner: TComponent); override;
 published
  // Our own members:
  property Color: TAlphaColor read FColor write SetColor default TAlphaColors.Silver;
  property OnColorChange: TNotifyEvent read FOnColorChange write FOnColorChange;

  // Re-publish a few inherited members so they show up in the Object Inspector.
  // TControl declares these as protected; surfacing them here is normal practice.
  property Align;
  property Anchors;
  property Position;
  property Width;
  property Height;
  property Visible;
  property Opacity;
  property HitTest;
  property OnClick;
 end;

implementation

function RandomColor: TAlphaColor;
begin
 // MakeColor (FMX.Graphics) returns an opaque ARGB value.
 Result := MakeColor(Byte(Random(256)), Byte(Random(256)), Byte(Random(256)));
end;

constructor TColorClicker.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 Width := 100;
 Height := 100;
 FColor := TAlphaColors.Silver;
 HitTest := True;   // a TControl must opt in to receive mouse input
end;

procedure TColorClicker.SetColor(const Value: TAlphaColor);
begin
 if FColor <> Value then
 begin
  FColor := Value;
  Repaint;          // never draw from a setter; just request a repaint
  if Assigned(FOnColorChange) then
   FOnColorChange(Self);
 end;
end;

procedure TColorClicker.Paint;
begin
 // All drawing happens here, against the live Canvas, in LOCAL coordinates.
 Canvas.Fill.Kind := TBrushKind.Solid;
 Canvas.Fill.Color := FColor;
 Canvas.FillRect(LocalRect, 0, 0, [], AbsoluteOpacity);

 Canvas.Stroke.Kind := TBrushKind.Solid;
 Canvas.Stroke.Color := TAlphaColors.Black;
 Canvas.Stroke.Thickness := 1;
 Canvas.DrawRect(LocalRect, 0, 0, [], AbsoluteOpacity);
end;

procedure TColorClicker.Click;
begin
 inherited;          // fires the inherited OnClick handler first
 Color := RandomColor;
end;

initialization
 Randomize;          // seed once, so colors differ between runs

end.
```

### What to notice

- **`[ComponentPlatformsAttribute(pidWin32 or pidWin64)]`** sits immediately before
  `TColorClicker = class`. This single attribute, not the package's platform list,
  decides which platforms the component is enabled for on the palette. Skip it and
  the component is greyed out for Win64. (Full story in §8.)
- **All drawing is in `Paint`.** Property setters call `Repaint`, never draw
  directly — FMX has no offscreen-buffer model; you describe the control and the
  framework paints it.
- **`HitTest := True`.** A bare `TControl` does not receive mouse events unless it
  opts in. Forget this and clicks do nothing.
- **Re-publishing inherited properties** (`Align`, `Position`, …) is how they
  appear in the Object Inspector. You only publish what makes sense for your
  control.
- **No IDE units in `uses`.** The runtime unit pulls in only RTL + FMX. This is
  what keeps the runtime package free of any design-time dependency.

---

## 4. The registration unit — `Source/ColorClickerFmxReg.pas`

This is the *only* unit that goes into the design-time package.

```pascal
unit ColorClickerFmxReg;

// Design-time registration. Lives in the DESIGN-TIME package only; the runtime
// package contains ColorClickerFmx and carries no IDE dependency.

interface

procedure Register;

implementation

uses
  System.Classes, ColorClickerFmx;

procedure Register;
begin
 RegisterComponents('Tutorial', [TColorClicker]);
end;

end.
```

- `RegisterComponents('Tutorial', [TColorClicker])` puts `TColorClicker` on a  palette category called **Tutorial**. Pick any category name you like; the IDE
  creates it if it doesn't exist.
- The IDE finds `Register` by **convention** — any unit in an installed design  package that exports a procedure named exactly `Register` is called once at load.
- `RegisterComponents` itself lives in `System.Classes` (part of `rtl`), so this  unit needs **no** `DesignIntf`/`designide`. You only need `designide` if you go
  further — custom property editors, component editors, etc. (see §6).

---

## 5. The runtime package — `Package/ColorClickerFmxRT.dpk`

A `.dpk` is just source describing a package. You normally edit it through *Project Options*, but it's worth seeing the text. The block between
`{$IFDEF IMPLICITBUILDING …}` and `{$ENDIF}` is generated compiler options — leave it as the IDE writes it. The lines that matter to us are after it.

```pascal
package ColorClickerFmxRT;

{$R *.res}
{$IFDEF IMPLICITBUILDING This IFDEF should not be used by users}
{$ALIGN 8}
{$ASSERTIONS ON}
{$BOOLEVAL OFF}
{$DEBUGINFO OFF}
{$EXTENDEDSYNTAX ON}
{$IMPORTEDDATA ON}
{$IOCHECKS ON}
{$LOCALSYMBOLS OFF}
{$LONGSTRINGS ON}
{$OPENSTRINGS ON}
{$OPTIMIZATION ON}
{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
{$REFERENCEINFO OFF}
{$SAFEDIVIDE OFF}
{$STACKFRAMES OFF}
{$TYPEDADDRESS OFF}
{$VARSTRINGCHECKS ON}
{$WRITEABLECONST OFF}
{$MINENUMSIZE 1}
{$IMAGEBASE $400000}
{$DEFINE RELEASE}
{$ENDIF IMPLICITBUILDING}
{$LIBSUFFIX '370'}
{$RUNONLY}
{$IMPLICITBUILD OFF}

requires
  rtl,
  fmx;

contains
  ColorClickerFmx in '..\Source\ColorClickerFmx.pas';

end.
```

Key lines:

- **`{$RUNONLY}`** — marks this as a runtime-only package (it can't be installed  into the IDE, and that's correct).
- **`{$LIBSUFFIX '370'}`** — appends `370` to the BPL name → `ColorClickerFmxRT370.bpl`.
  See §7.
- **`{$IMPLICITBUILD OFF}`** — "Explicit rebuild." Both packages must agree on this  (see §9, *Gotchas*).
- **`requires rtl, fmx;`** — the runtime dependencies, nothing more.
- **`contains … in '..\Source\…'`** — the package physically *contains* the control  unit. The relative path reaches across to the `Source/` folder.

---

## 6. The design-time package — `Package/ColorClickerFmxDT.dpk`

```pascal
package ColorClickerFmxDT;

{$R *.res}
{$IFDEF IMPLICITBUILDING This IFDEF should not be used by users}
{$ALIGN 8}
{ … same generated option block as above … }
{$ENDIF IMPLICITBUILDING}
{$LIBSUFFIX '370'}
{$DESIGNONLY}
{$IMPLICITBUILD OFF}

requires
  rtl,
  ColorClickerFmxRT;

contains
  ColorClickerFmxReg in '..\Source\ColorClickerFmxReg.pas';

end.
```

Key differences from the runtime package:

- **`{$DESIGNONLY}`** instead of `{$RUNONLY}` — this is the package you Install.
- **`requires rtl, ColorClickerFmxRT;`** — it requires the *runtime* package  (so the IDE loads the control's code) but **does not** re-require `fmx` (that
  comes transitively through the RT package).
- **`contains` only the `Reg` unit** — never the control itself. The control lives  in exactly one package (the RT one); a unit may be contained by only one loaded
  package at a time.

### When you *do* need `designide`

The example above gets away with `requires rtl, ColorClickerFmxRT;` because theonly design-time API it calls is `RegisterComponents` (which is in `rtl`). The
moment you register a **property editor**, a **component editor**, or anything from`DesignIntf`/`DesignEditors`, add `designide` to the DT package's `requires`:

```pascal
requires
  rtl,
  designide,
  ColorClickerFmxRT;
```

`designide` is itself a design-only package, so adding it never affects the runtime
package or shipped apps.

---

## 7. The version suffix (`{$LIBSUFFIX}`)

A compiled package is a `.bpl` whose name, by default, is just the package name:` ColorClickerFmxRT.bpl`. The problem: a BPL built with Delphi 13 cannot be loaded
by Delphi 12, yet they'd have the same filename. The **library suffix** solves this by baking the Delphi version into the filename:

```pascal
{$LIBSUFFIX '370'}     // -> ColorClickerFmxRT370.bpl
```

`370` is the RAD Studio **37.0** (Delphi 13) product version. Each Delphi release has its own number; for older releases you'd use a different value (e.g. Delphi 11
Alexandria was `28.0` → suffix `280`). Apply the **same** suffix to **both** the RT and DT packages so their names stay in lockstep.

Set it in **Project Options ▸ Description ▸ LIB suffix** (per package), or just type the directive into the `.dpk` as shown.

> **The LIB suffix field must actually be set — blank does not work.** In *Project
> Options ▸ Description* the **LIB suffix** control is an editable combo. Leaving it
> empty produces an un-suffixed BPL (`ColorClickerFmxRT.bpl`) and the DT package
> then can't find the suffixed name it expects. You must give it a value: either
> **type the number `370` by hand**, or pick **`$(Auto)`** from the dropdown. Do
> this for **both** packages. (Typing the explicit `370` is the reliable choice —
> see the `AUTO` caveat below.)

> **Avoid `{$LIBSUFFIX AUTO}`.** `AUTO` is supposed to fill in the version number
> for you, but in this repository it proved unreliable — it suffixed the *design*
> BPL while leaving the *runtime* BPL un-suffixed, producing a name mismatch where
> the DT package couldn't find the RT package it required. Use the **explicit
> number** (`'370'`) on both packages and the problem disappears.

(The `THexColorPicker` packages in this repo already carry `{$LIBSUFFIX '370'}` for exactly this reason, so they need no change — they're the working reference.)

---

## 8. Win64 at design time — the part everyone trips on

The RAD Studio IDE is a **32-bit (Win32) process.** When it shows your component on the palette and lets you drop it on a form, it is running your *design-time* code
inside that 32-bit IDE, which in turn loads the **Win32** build of your runtime BPL. Two consequences:

1. **You must build the runtime package for Win32**, and install the design package    from Win32 — even if your real application targets Win64. The IDE can't load a
   Win64 BPL into itself.

2. **Per-platform palette availability is controlled by an attribute on the class,    not by the package's platform list.** That attribute is:

   ```pascal
   [ComponentPlatformsAttribute(pidWin32 or pidWin64)]
   TColorClicker = class(TControl)
   ```

   The IDE reads this attribute out of the **Win32 runtime BPL** it has loaded, and    uses it to decide which target platforms the component is enabled for. So:

   - **No attribute** (or `pidWin32` only) → the component is **greyed out** when
     your active project targets Win64.
   - **`pidWin32 or pidWin64`** → enabled for both.

   Because the IDE reads it from the **Win32** BPL, after you change the attribute    you must **rebuild the Win32 runtime package** for it to take effect. Rebuilding
   only the Win64 runtime does nothing for the palette.

To actually *run* a 64-bit application that uses the component, also build the runtime package for **Win64** so the linker has the Win64 `.dcp`/`.bpl` (or `.dcu`s
for static linking) available. So the full matrix is:

| Build | Platform | Why |
|---|---|---|
| Runtime (RT) | **Win32** | Loaded by the 32-bit IDE; drives the palette. **Required to install.** |
| Runtime (RT) | **Win64** | So 64-bit apps can link the control. |
| Design (DT) | **Win32** | The IDE is Win32; you install this build. |

There is no Win64 build of the *design* package — the IDE would never load it.

---

## 9. Build, install, and the order that matters

1. Open `Package/ColorClickerFmx.groupproj` (the project group — see §10).
2. Select platform **Win32**. **Build `ColorClickerFmxRT`** (the runtime package).
3. Switch to **Win64** and **Build `ColorClickerFmxRT`** again (for 64-bit apps).
4. Back on **Win32**, **Build `ColorClickerFmxDT`** (the design package).
5. Right-click **`ColorClickerFmxDT` ▸ Install.**

`TColorClicker` now appears on the Tool Palette under **Tutorial**. Drop it on an
FMX form; click it at design time and at run time and watch the color change.

### Gotchas (each one cost real time on the sister project)

- **Build RT before DT.** DT `requires` RT; if RT hasn't been built, DT can't
  compile. The project group enforces the order — use it rather than building
  packages individually.
- **Both packages need the same Build Control.** If the DT package is "Explicit
  rebuild" (`{$IMPLICITBUILD OFF}`) but the RT package is "Rebuild as needed"
  (`{$IMPLICITBUILD ON}`), you get
  `E2466 Never-build package … requires always-build package …`. Set **both** to
  **Explicit rebuild** (`{$IMPLICITBUILD OFF}`, as shown in the listings).
- **Unit-name collisions are fatal and the error is misleading.** Two loaded
  packages cannot both contain a unit of the same name. If some *other* installed
  package already ships a unit called `ColorClickerFmx`, installing yours fails
  with errors like `[Fatal Error] Can't load package …, the system cannot find the
  file specified` — which says nothing about the real cause. Keep your unit names
  unique. (On the sister project this is exactly why `THexaColorPicker` was renamed
  to `THexColorPicker` / `HexaColorPicker` → `HexColorPickerFmx`: to coexist with
  the original VCL library that still owns the old names.)
- **A unit lives in exactly one package.** The control unit goes in RT and *only*
  RT; the `Reg` unit goes in DT and *only* DT. Don't list the control in both.
- **Let BPL/DCP output go to the IDE defaults** (`$(BDSCOMMONDIR)\Bpl` and `\Dcp`),
  which are on the IDE search path. Redirecting package output to a project-local
  folder means the IDE can't find the BPL to load at design time.
- **Stale BPL holding the runtime?** If rebuilds of the runtime seem ignored
  (e.g. an attribute change doesn't "take"), the installed DT package may be
  holding the old RT BPL open. Uninstall DT, delete the stale BPLs in
  `$(BDSCOMMONDIR)\Bpl`, rebuild **Win32** RT, reinstall DT, and restart the IDE.
- **`High(dynarray)` in a set constructor breaks Win64.** Unrelated to packaging
  but a classic 32-vs-64 trap: `I in [0, High(SomeDynArray)]` compiles on dcc32 but
  fails on dcc64 with `E2010 Incompatible types: 'Integer' and 'Int64'` (on Win64,
  `High` of a dynamic array is `NativeInt` = `Int64`). Write
  `(I = 0) or (I = High(SomeDynArray))` instead.

---

## 10. The project group — `Package/ColorClickerFmx.groupproj`

A `.groupproj` ties the packages together and fixes the build order. You normally
create it via **File ▸ New ▸ Project Group**, then **add** the two `.dproj`s. The
generated XML looks like this (trimmed):

```xml
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <ItemGroup>
        <Projects Include="ColorClickerFmxRT.dproj"><Dependencies/></Projects>
        <Projects Include="ColorClickerFmxDT.dproj"><Dependencies/></Projects>
    </ItemGroup>
    <Target Name="Build">
        <CallTarget Targets="ColorClickerFmxRT;ColorClickerFmxDT"/>
    </Target>
</Project>
```

Listing `…RT` before `…DT` in the `Build` target is what guarantees the runtime
package is built first.

> Note: each package's real settings (platforms, output paths, `LIBSUFFIX`, build
> control) live in its **`.dproj`** (the MSBuild project), with the `.dpk` carrying
> the source-level directives shown above. When you change options in the IDE,
> both files are updated for you; the listings here show the parts you'd hand-edit
> or want to verify.

---

## 11. Using the installed component

Once installed, dropping `TColorClicker` on a form and wiring an event is all it
takes:

```pascal
procedure TForm1.ColorClicker1ColorChange(Sender: TObject);
begin
 Caption := Format('New color: $%.8x', [TColorClicker(Sender).Color]);
end;
```

Or create it in code with no install required — because the runtime unit is self-contained, any project can just add it to `uses`:

```pascal
uses ColorClickerFmx;

var
 Clicker: TColorClicker;
begin
 Clicker := TColorClicker.Create(Self);
 Clicker.Parent := Self;                 // required, or it won't show
 Clicker.Position.Point := PointF(16, 16);
end;
```

---

## 12. Checklist

- [ ] Control unit descends from an FMX class, draws in `Paint`, sets `HitTest`.
- [ ] `[ComponentPlatformsAttribute(pidWin32 or pidWin64)]` on the class.
- [ ] Separate `Register` unit calling `RegisterComponents`.
- [ ] RT package: `{$RUNONLY}`, `requires rtl, fmx;`, contains the control.
- [ ] DT package: `{$DESIGNONLY}`, `requires rtl, <RT>;` (+ `designide` only if
      you use design APIs), contains only the `Reg` unit.
- [ ] `{$LIBSUFFIX '370'}` (explicit number, not `AUTO`) on **both** packages.
- [ ] `{$IMPLICITBUILD OFF}` on **both** packages.
- [ ] Unit names are globally unique.
- [ ] Build RT (Win32 **and** Win64) → build DT (Win32) → Install DT (Win32).
- [ ] Component appears on the palette and is enabled for Win64.
