---
name: luapourbaix-diagrams
description: Create or revise limiting potential-pH diagrams with luapourbaix, TikZ and PGFPlots in LuaLaTeX, plain LuaTeX or ConTeXt MkIV. Use for chemical diagrams, water overlays, classification pics, reports and boundary queries; This guide covers consumer documents only. Do not use for full speciation or 3D concentration surfaces, which are not implemented.
---

# Draw limiting Pourbaix diagrams with luapourbaix

Use this skill to write consumer documents, not to change the library. Its
examples target luapourbaix 1.1. Check the installed package and its manual
before using features that an older distribution may lack. Keep code, comments
and figure text in English unless the user explicitly requests another language.

## Establish the chemical problem

Obtain the element, declared species, total element concentration in mol/L,
temperature in K, pH range, potential range in volts versus SHE, and an explicit
aqueous boundary convention. Ask for chemically consequential missing inputs;
do not silently choose species or the boundary convention.

- `equal concentrations` compares species molar concentrations.
- `equal element concentrations` weights them by the number of atoms of the
  selected element. These differ for species such as I2 and dichromate.
- The model is limiting and ideal: species outside each boundary pair are
  neglected. An aqueous domain means predominance, a solid domain means
  existence; a missing aqueous domain does not mean zero concentration.
- `constants={}` enables the sourced fallback catalogue at its supported
  temperature. Do not invent a missing constant, extrapolate temperature,
  silently change a solid phase, or suppress a thermodynamic error.
- Gas evolution, kinetics, nonideal activities and full aqueous speciation are
  not calculated. A solid corrosion product is not proof of a protective film.

If exact inputs are supplied, use them. For a strictly controlled dataset use
`thermodynamic database=none`; the documented 298.15 K water default remains
separate from catalogue lookup. Use the manual's source qualifications, notably
the copper-cycle exception, when comparing different species sets.

## Load the correct library and engine

LuaLaTeX: load `pgfplots`, set document-level compatibility if desired, then
`\usepgfplotslibrary{pourbaix}`. Plain LuaTeX: `\input pgfplots.tex`, then the
same library command. ConTeXt MkIV: `\usemodule[pgfplots]`, then
`\usepgfplotslibrary[pourbaix]`. Use LuaTeX, not LuaMetaTeX as an assumed equivalent.
Do not load the unsupported legacy `\usepackage{pourbaix}`.

Compile with no shell escape using the appropriate engine and an installed
package. Check the loaded library path if several installations coexist.
Do not alter an installation just to compile a figure.

## Build first, then draw

The following blocks use generic TeX syntax and run sequentially in one scope
after loading the library. In LaTeX, `\begin{tikzpicture}` / `\end{tikzpicture}`
and `\begin{axis}` / `\end{axis}` may replace their generic forms.

```tex
\pgfpourbaixset{pH min=0,pH max=14,
 build={name=SkillFe,element=Fe,temperature=298.15,concentration=.01,
  species={Fe(s),Fe^2+,Fe^3+,Fe(OH)2(s),Fe(OH)3(s)},
  boundary convention=equal element concentrations,constants={}}}
\tikzpicture
\axis[pourbaix/axis,width=10cm,height=7cm,
 xmin=0,xmax=14,ymin=-1.2,ymax=1.5,grid=major]
 \addpourbaix[domain palette=tab10 light,extra ticks=all]{SkillFe};
 \addpourbaixwater[prepare={diagram=SkillFe},domain labels=false];
\endaxis
\endtikzpicture
```

`build` atomically declares, checks, calculates and finalizes. Set pH bounds
before it; viewport bounds on the axis do not replace calculation bounds.
For staged inspection use `declare={...}`, `check=name`, `calculate=name`,
then `finalize=name`. Never use the removed `select` key. Species classifications
are available after declaration; final plots and maps need finalization.

The `pourbaix` environment can wrap an axis inside a TikZ picture: it accepts
chemical keys and forwards ordinary options such as `grid=major` to PGFPlots.
Generic forms are `\pourbaix[... ] ... \endpourbaix`; ConTeXt also provides
`\startpourbaix ... \stoppourbaix`. For overlays, an ordinary axis is sufficient.

Both add commands require a trailing semicolon. They do not accept appended
TikZ path syntax: use the package's node/style keys for labels. PGFPlots draws
at axis end; never work around this by drawing boundaries eagerly.

## Style domains and water independently

```tex
\tikzpicture
\axis[pourbaix/axis,width=10cm,height=7cm,
 xmin=0,xmax=14,ymin=-1.2,ymax=1.5]
 \addpourbaix[domain palette=behavior,domain label mode=letters,
  domain/Fe(s)={label=$M$,label at={4,-.95},
    label style={draw,fill=white,name=metal}},
  final domain label style={fill=white,inner sep=1pt}]{SkillFe};
 \addpourbaixwater[prepare={diagram=SkillFe},
  domain fills=true,domain labels=false,
  domain/H2={style={fill=none}},domain/O2={style={fill=none}},
  domain/H2O={style={fill=none,pattern=north east lines,
    pattern color=black,opacity=.35}}];
\endaxis
\endtikzpicture
```

Use `domain palette=monochrome` for black patterns or `behavior monochrome` for
corrosion categories with patterns. Automatic palettes distinguish adjacent
retained species. Explicit styles can defeat that distinction: inspect the
result. Scope options per plotting call when overlaying several diagrams.
Labels are TikZ nodes; positions are axis coordinates, and styles can set fonts,
anchors and node names. Never reuse a node name accidentally across overlays.

`extra ticks=all` adds eligible characteristic ticks. Subsets use final boundary
IDs, documented in the manual; y intercepts require retained support at pH=0.
`show removed=true` adds diagnostic overlays, while `show provisional boundaries`
can expose all candidates. An eliminated species' incompatible band is not a
stable domain. For final-only plots use the `final diagram` plot style.

The water overlay assumes independent H2 and O2 partial pressures of 1 bar,
unit water activity and SHE potentials. Change `hydrogen pressure` and `oxygen
pressure` in `prepare={...}` when needed. With `diagram=...`, it inherits that
diagram's temperature and Nernst factor. `nernst factor=.06` is an explicit
classroom approximation in volts, not an automatic 25-degree conversion.

## Query results, classifications and reports

```tex
\pgfplotsgetpourbaix{SkillFe}\SkillHandle
\pgfpourbaixset{data/\SkillHandle/final/1/b/.get=\SkillIntercept}
\tikzpicture
\node {Boundary 1: $b=\pgfmathprintnumber{\SkillIntercept}$ V};
\endtikzpicture
\tikzpicture[pourbaix/oxidation number format=roman]
\pic {pourbaix map=SkillFe};
\endtikzpicture
\pgfplotspourbaixreport[
 sections={header,inputs,constants},text width=10cm]{SkillFe}
```

Retrieve the handle after the relevant stage; later stages create new snapshots.
Aliases and queried macros follow TeX grouping. Boundary IDs depend on species
and conventions: the example's `1` belongs to this iron system, not every system.
Read `final/<id>/a`, `b`, `expression` for redox lines or `pH` for verticals;
provisional paths use their `-temp` names directly under `data/<handle>/`.
Use report sections `boundaries` and `events` to inspect the actual identifiers.
Classification pics `pourbaix oxidation`, `pourbaix acidity` and `pourbaix map`
work outside axes. Acidity direction defaults to decreasing; use
`pourbaix/acidity direction=increasing` when explicitly requested.
Reports belong outside both axis and tikzpicture, so cards can break across pages.

## Custom thermodynamic data and failure handling

Use species-addressed records and a literal `|` between pair identifiers, never
`/`. Examples of constant records are
`standard potential/Fe^3+|Fe^2+={value=.771}` and
`solubility product/Fe(OH)2(s)={log value=-15}`. Values here illustrate syntax;
choose phase- and source-consistent data for the actual problem.
For polyatomic ions, prefer an explicit balanced reaction, for example
`solubility product/UO2(OH)2(s)={log value=-24,
reaction={UO2(OH)2(s) = UO2^2+ + 2 OH^-}}`.
The reaction orientation and coefficient scale define the constant. Do not
change either without changing K. `HO^-` is supported as an alias of `OH^-`.
Use `=` for chemical equilibria in documentation, not paired harpoons.

On an error, examine the named species/pair and supplied reactions. Correct
missing data, references, charge/atom balance or phase choices explicitly;
do not lower consistency tolerances to conceal contradictory thermodynamics.
Do not average standard potentials: combine electron-weighted free energies.

Before delivering a figure, compile it, inspect clipping, labels and legends,
and state significant model/data limitations. Consult the installed manual
(`luapourbaix-manual.pdf`, obtainable through kpsewhich when installed) for
full key paths, defaults and data tables; do not infer undocumented keys.
