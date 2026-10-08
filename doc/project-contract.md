# Persistent project contract

This is the detailed record of the author's instructions for luapourbaix.
Read it together with [AGENTS.md](../AGENTS.md) when starting or resuming work,
including after context compaction. It is a project specification, not a record
of every tool call. Later explicit author instructions take precedence; reconcile
this document when they arrive rather than preserving contradictory rules.

## 1. Purpose and engineering requirements

The project is a jointly developed **generic PGFPlots library for potential-pH
(Pourbaix) diagrams**. It must work with plain TeX, LaTeX and ConTeXt MkIV using
LuaTeX, or another compatible engine capable of running the required Lua code.
Other engines must be tested before compatibility is claimed.

Use the most rigorous programming practices for generic TeX, Lua, LuaTeX,
TeX/Lua interaction, TikZ/PGF and PGFPlots. The public interface must follow the
TikZ/PGFPlots approach to configuration and composition. Preserve generic-format
compatibility and the host packages' scoping, style and plotting semantics.

**All development is in English:** code, identifiers, code comments, diagnostics,
manual and repository documentation. This supersedes the initial French manual
and documentation choice. User-facing conversation has continued in French.

Scientific reasoning and documentation must be suitable for undergraduate
solution-chemistry teaching, without sacrificing chemical correctness.

## 2. Documentation requirements

- Produce the most comprehensive manual possible, in the style of the TikZ/PGF
  and PGFPlots manuals, covering usage, reference material, scientific meaning,
  limitations and examples as functionality is developed.
- The TikZ manual sources provided by the author are in `../pgf/`. Consult them
  as an editorial reference. PGFPlots sources are also available locally.
- **No documentation example is to be externalized.** Keep example source in
  the manual and compose graphical examples during manual compilation; do not
  substitute externally generated or precompiled example figures.
- Keep the manual consistent with implemented capabilities. Do not present planned
  capabilities as already available.
- Organize the manual by reader needs and reference topics, not development
  chronology: getting started, user reference, scientific model, worked examples,
  thermodynamic provenance and technical reference. All examples remain inline.

### Publication preparation (author instruction, October 2026)

Prepare the repository for GitHub and CTAN locally, cleaning obsolete intermediate
outputs while preserving useful source, tests and persistent instructions.
The destination is `git@github.com:cjorssen/luapourbaix.git`.
The author and current maintainer is **Christophe Jorssen**,
`christophe.jorssen@gmail.com`. The author chose LPPL; the implementation uses
LPPL 1.3c or any later version, maintenance status `maintained`, the unmodified
license text, file notices and a distribution manifest.
Clearly disclose that the package was **"vibe coded" with ChatGPT 6 Astra** in
the README, manual and author notice. This is a development-method disclosure,
not scientific validation; the deferred source audit remains pending.
Luapourbaix publication remains unauthorized: do not push its sources, create
remote releases or upload to CTAN. The later legacy-repository notice request
below supersedes the announcement ban only for that explicit notice. Local archives and draft submission
metadata are authorized. The documentation cleanup uses version 0.12.0 without a development suffix,
with release metadata explicitly marked unreleased. Preparing archives is not
a claim of acceptance or publication. This supersedes retaining the -dev suffix.

## 3. Information supplied by the user

The declaration interface must accept the following categories. The name in
item 6 is optional; temperature was added in the subsequent preparation request.

1. **A chemical element**, for example iron, `Fe`.
2. **The selected chemical species.** Author examples:
   `Fe(s), Fe^2+, Fe^3+`, or that set extended with `Fe(OH)2(s), Fe(OH)3(s)`.
3. **Thermodynamic constants for the selected system.** Author examples:
   standard potentials for `Fe^3+/Fe^2+` and `Fe^2+/Fe(s)`, optionally supplemented
   by the solubility products of `Fe(OH)2(s)` and `Fe(OH)3(s)`.
4. **Total element concentration**, called the diagram or plotting concentration,
   for example `c_t = 1e-2 mol/L`.
5. **An explicit aqueous boundary convention**, chosen by the user from the two
   definitions below. Do not silently pick one because they coincide for iron.
6. **An optional diagram name**, for example `Fe` or `Fe1E-2`. Names are intended
   to support later boundary queries, reuse and overlay of multiple diagrams in
   one coordinate system.
7. **Working temperature associated with the diagram.** The current interface
   requires an explicit positive absolute temperature in kelvins; the choice of
   unit and absence of a default are implementation decisions.

Except for the uranium tutorial dataset recorded below, numerical test and
example inputs are implementation or sourced teaching data, not thermodynamic
reference values supplied by the author.

## 4. Total concentration and limiting construction

For species `i`, let `nu_i` be its atom count of the selected element. Use the
ordinary concentration for an aqueous species and the generalized concentration
`n_i/V` for a solid. The total element concentration is

```text
c_t = sum_i(nu_i * c_i)
```

For the author's five-species iron example, all `nu_i` equal 1:

```text
c_t = [Fe^2+] + [Fe^3+]
    + n_Fe(s)/V + n_Fe(OH)2(s)/V + n_Fe(OH)3(s)/V
```

Construct a **limiting Pourbaix diagram**. On a boundary between two domains,
ordinary or generalized concentrations of all species outside that pair are
negligible or zero. This is not a full speciation calculation. Aqueous domains
are predominance domains; solid domains are existence domains.

The author's unambiguous examples are:

- At `Fe^2+/Fe(s)`, `[Fe^3+]` is negligible compared with `[Fe^2+]`, and neither
  hydroxide solid exists.
- At `Fe^3+/Fe^2+`, `Fe(s)` and both hydroxide solids are absent.

## 5. Boundary rules

### Two aqueous species

Let A and B contain `a` and `b` atoms of the selected element. The user explicitly
chooses one of:

- **Equal species concentrations:** `c_A = c_B`.
- **Equal element concentrations:** `a*c_A = b*c_B`.

Combining these instructions with the limiting balance gives, respectively:

```text
c_A = c_B = c_t/(a+b)

c_A = c_t/(2a),  c_B = c_t/(2b)
```

The formulas are derived consequences of the author's rules. The conventions
coincide when the two atom counts are equal and can differ otherwise.

### One aqueous species and one solid

The solid is at its existence limit. Its incipient amount has a generalized
concentration negligible compared with that of the aqueous species. Contributions
from other species are neglected under the limiting construction. Use c_aq = c_t / selected-element atom count for this pair. An amount or generalized concentration is not an activity.

### Two solids — clarified by the author

Both solids are at their existence limit, and **both activities equal 1**.
This is the only information the algorithm needs for these two solids. Do not
calculate concentrations of other species, infer solid amounts or solve an amount
balance for this boundary. The activity rule does not depend on `c_t`, atom counts
or the aqueous boundary convention.

This clarification resolves the earlier question about solid-solid boundaries;
do not continue treating that rule as unspecified.

### Remaining wording ambiguity in an example

The initial description of the `Fe^3+/Fe(OH)3(s)` boundary excludes `Fe(OH)3(s)`
in its list of absent solids, although that solid is part of the boundary pair.
The assistant proposed that the excluded hydroxide should instead be `Fe(OH)2(s)`.
The author did not explicitly approve that correction: the subsequent
clarification addressed the **two-solid** rule only.

Do not present the proposed correction as an author-confirmed instruction.
The general aqueous-solid rule above was stated explicitly and remains valid.
Resolve the wording before using the conflicting example as an authoritative
test or worked example; unrelated declaration work need not wait for it.

## 6. Deferred PGFPlots processing

The author explicitly emphasized that PGFPlots stores plotting requests and
generates drawing commands at the end, after user and library requests have
been accumulated. Respect its survey/visualization pipeline. Future diagram
plots must cooperate with ordinary plots, overlays, bounds and transformations.
Do not implement eager drawing that bypasses this behavior.

### Preparatory classifications and provisional boundary inventory

Before boundary calculation or plotting, the library must:

1. Determine the oxidation number of the selected element automatically, with
   an explicit per-species override for delicate cases, and order species by
   increasing oxidation number. Make a TikZ classification diagram available
   outside a PGFPlots axis, using a TikZ-style interface.
2. Within each oxidation group, order species by decreasing acidity and expose
   a second independent TikZ classification diagram.
3. Identify provisional species-pair boundaries. Different oxidation numbers
   give horizontal/oblique Nernst candidates; equal oxidation numbers give
   vertical equilibrium-quotient candidates (acid/base, precipitation or
   complexation). Give these configurable names: by default, lowercase letters
   followed by `-temp` for vertical candidates and integers followed by `-temp`
   for the others. Do not calculate boundaries during preparation; the later calculation stage
   below supersedes the former project-wide prohibition.

The author explicitly approved both clarifications:

- Use the stoichiometric H+/H2O order (e.g. Fe^2+ before Fe(OH)2(s)), without
  constants. Require an explicit user order when ligands prevent comparison.
- Include **all unordered pairs**, including pairs that may not share any
  boundary in the final stability diagram, rather than only neighbours.

The formula `(H - 2 O)/selected-element atom count`, the restricted automatic
oxidation rules, ties and complete per-group ranks are implementation details
documented in the manual. Do not mistake formal acidity order for pKa ordering
or provisional pair enumeration for thermodynamic feasibility. Classification
pics are schematics; the no-eager-drawing rule still applies to future E-pH plots.

### Thermodynamic sufficiency after preparation

The author requires the library to verify that the supplied numerical E and K
data suffice for **every** provisional boundary. Missing data must be derived
from supplied information when possible and exposed through a key=value system.
If derivation is impossible, identify the missing information with a clear error.
This check alone computes neither boundary equations nor stable domains.

The author explicitly chose an **explicit step after declaration**, so incomplete
declarations can still support classification inspection. This check is mandatory
before any boundary calculation or rendering. The public implementation
uses `pourbaix/check=<name>` or `pourbaix/check handle=<handle>`.

The author also chose a **default water ion product at 298.15 K**. This supersedes
the blanket ban on implicit constants for that datum only. The implementation
uses the approximate teaching value 1e-14, with supplied or independently derived
values taking priority. No default is supplied at another temperature, and no
temperature extrapolation is performed. The precise numerical approximation and
priority policy are implementation decisions, not additional quoted instructions.

Closure uses balanced reactions and additive log equilibrium constants/free
energies; electron counts weight standard potentials. All input potentials must
share the same reference and compatible standard states. Checking sufficiency
does not establish a concentration-to-activity model or prove stable domains.

### Offline thermodynamic library for aqueous systems

The author requests a thermodynamic library to consult for missing constants
**before issuing an insufficiency error**, in addition to derivation from supplied
data. It must cover standard potentials, acidity constants, solubility products,
and formation of complexes with hydroxide ions (other ligands are outside the
requested initial scope). The solvent is water. Solid domains remain part of
aqueous Pourbaix diagrams; this does not authorize nonaqueous solvents.

The proposed starting source for potentials is
https://en.wikipedia.org/wiki/Standard_electrode_potential_(data_page).
The implementation uses a curated, versioned selection rather than scraping at
runtime. USGS PHREEQC provides the initial equilibrium data. Preserve exact source
reactions and record any reversals, subtraction of protonation constants, or
conversion from hydrolysis/acid dissolution using the source water constant.
Never conflate aqueous neutral hydroxides with solid hydroxides, or pKa with
log K, or cumulative beta with stepwise formation constants.

The author explicitly chose **documented default phases** for solids with multiple
forms, rather than requiring a phase choice. Permit a species-level override.
Current defaults include gibbsite for Al(OH)3(s), amorphous Fe(OH)3(s), and epsilon
Zn(OH)2(s). These particular selections are implementation choices. If a source
does not identify a phase, label it `unspecified`; do not invent a crystal form.

The current default selector is `thermodynamic database=aqueous-298`; `none`
disables numerical fallback. Matching is restricted to 298.15 K, the selected
element and compatible phases. No interpolation is implied. Only missing
independent reaction information is imported; user constants and their derived
consequences always have priority. Source conventions are retained, not silently
converted between molarity and molality. The collection is a sourced starting
dataset, not a certified globally consistent reference database.

### Deferred scientific source audit

The author agreed to record a future scientific audit, not to migrate data now.
The original 24 standard potentials still come from Wikipedia; GitHub hosts the pinned
USGS PHREEQC source used for the other 50 entries. Hosting is not scientific
validation. Later work should trace potentials to evaluated compilations or
original publications, retain PHREEQC provenance, and audit reaction cycles,
temperatures, reference electrodes, solid phases and standard states. Wikipedia
remains a starting point and cross-check. No fully harmonized dataset is claimed.

### Automatically composed diagram reports

The author requests a reusable report for a declared and processed diagram:
oxidation and acidity classification pics, the final plot with inactive supports
and eliminated-species diagnostic bands, used/derived thermodynamic constants,
and boundary equations. Use a configurable TikZ/PGFPlots presentation, preferably
with foreach composition, and include inline manual examples starting with iron,
copper, zinc and chromium. The existing incompatible-domain interpretation applies.

Implementation choice: reports require a selected snapshot and never run hidden
declaration/check/calculation/selection operations. The generic report macro
composes independently breakable TikZ blocks using foreach; users choose sections,
axis/plot options and styles. Numerical inputs include balanced reaction log K
and origins; all provisional pairs show equations, final labels when retained,
selection status and linear-combination provenance. The earlier chromium report is a
documented reduced species set (metal, Cr(II), Cr(III), dichromate), not a complete
hydroxide/chromate diagram; the subsequent nine-diagram gallery now supplies the requested hydroxide/chromate set.

## 7. Current implementation choices, not additional author requirements

The following are repository design decisions made to implement the requirements.
They may evolve with review; do not misattribute their exact syntax or restrictions
to the author:

- `pourbaix/declare={...}` and the nested PGF key families; the English choice
  values `equal concentrations` and `equal element concentrations`.
- Plain chemical formula syntax, its current parser restrictions and units for
  numeric API values; explicit empty constant lists are allowed at declaration
  time without certifying computational sufficiency.
- TeX-scoped name aliases, stable handles and independent Lua snapshots for
  eventual deferred use; anonymous access through `\pgfplotslastpourbaix`.
- A pure Lua core separated from the engine bridge, transactional validation,
  and the TDS source layout.
- Python/Make build orchestration, the test layout and the current experimental
  schema. See README, source and tests for their current state.

The declaration layer, boundary input helpers, oxidation/acidity preparation,
named all-pair inventory, TikZ classification pics and explicit thermodynamic
closure with library fallback are implemented. The initial aqueous-298 edition
contains 74 sourced records (24 potentials, 11 acidity constants, 32 cumulative
hydroxide formation constants and 7 hydroxide solubility products). Both source
revisions are pinned in luapourbaix-database.lua; every USGS value was checked
against its cited source lines. Working temperature is mandatory. The check creates an
immutable checked snapshot and exports scalar PGF data under its handle. Failed
checks leave aliases and the last handle unchanged. Results include reaction
coefficients, log constants, standard potentials, recoverable hydroxide products,
and linear-combination provenance. Inconsistent cycles are errors.

The current automatic reaction model balances pairs with H+, H2O and electrons,
provided other elemental compositions match per selected-element atom. The
solubility-product shorthand infers only hydroxide dissolution; its free ion and
OH- may be auxiliary reaction participants without becoming selected species.
General automatic dissolution inference, differing-ligand boundary models and
H/O target boundary models are not implemented: report missing reaction information rather than
certifying these diagrams. Explicit acidity ranks do not supply a reaction.
This is an implementation limitation, not a restriction requested by the author.

### Provisional boundary equations (subsequent author request)

The author now requests equations E = a*pH + b or pH = constant for all
provisional boundaries, and access to equations and associated constants through
a TikZ/PGFPlots-style interface. This supersedes the earlier restriction against
computing equations, but not the separation of preparation and explicit checking.
The author explicitly approved the ideal dilute model: aqueous activities [i]/c0
with c0=1 mol/L, pure solid and water activities 1, pH=-log10(a(H+)). This is the
documented default; source molality/molarity differences remain an approximation.

Implementation: pourbaix/calculate=<name> and calculate handle=<handle> require
an already checked snapshot and commit an independent calculated snapshot.
They export equation type, equation text, PGF expression, a and b (volts), or pH,
plus log Q offset and proton coefficient under the existing boundary data paths.
All thermodynamic keys remain available on the calculated handle. A calculation
by handle does not update a name alias; repeated calculation is idempotent.
A pH-independent nonredox reaction yields identity or empty, judged using the
existing log-K tolerance; it has no expression or finite pH coefficient. These
are implementation decisions and are documented, not additional author choices.
The following selection stage now reconstructs limiting-domain boundaries.
The rendering stage below now submits ordinary addplot commands automatically.
Reference electrodes and new standard states must not be silently invented.

### pH sweep, disproportionation and reconstructed boundaries

The author requires locating incompatible domains on both sides of provisional
boundaries at each pH, inventorying boundaries that disappear, computing and
exposing their replacements, then reconstructing identical pieces across the
small pH intervals. Solid domains are existence domains; aqueous domains are
predominance domains. The author clarified that the criterion is an **empty
common potential interval** for an intermediate oxidation state (lower bound
above upper bound), which undergoes disproportionation. They approved **explicit
pH min and pH max**, **default pH step 0.1**, and **additional known intersections**
so that changes between grid points are retained. These are now settled choices.

Implementation choices: an explicit `pourbaix/finalize` (or `finalize handle`) after
`calculate` creates an immutable selected snapshot. Scoped PGF keys `pourbaix/pH
min`, `pH max`, `pH step` configure this operation, not an axis or a declaration.
The mesh contains uniform nodes plus vertical loci and affine-line intersections.
Each open cell is classified at its midpoint. Within an oxidation group, retain
the unique species favored by its pairwise equilibrium comparisons. Persistent
ties or cycles cause a clear error rather than an arbitrary species choice.
Traverse oxidation states in increasing order and repeatedly remove an
intermediate with incompatible adjacent potential bounds; recompute adjacency
using the direct product-pair equation. Equal bounds within floating-point
resolution produce a separately labeled zero-width event, not a claim of a
strictly favorable disproportionation. Cascades and transient replacements are
recorded. This is the requested sequential limiting construction, not a global
Gibbs-energy/speciation solver; pairwise concentration assumptions can differ.

All replacement pairs already exist in the all-pair inventory. Preserve their
source names, checked equations and constants. Combine half-reactions to provide
a balanced electron-free disproportionation reaction and log K for each event.
Merge contiguous intervals by source pair; never merge across a gap or identify
numerically coincident lines of different species. Vertical boundaries have their
pH and the common potential extent of the surviving domains on each side, using
one-sided neighborhoods even at a requested pH endpoint. Infinite potential
bounds are explicit; no potential range or water-stability clipping is assumed.

Selection results expose merged segments, elimination events and the complement
of retained candidate support within the requested pH window. Inactive candidates
are not all attributed to disproportionation: some are nonadjacent, acid/base
excluded, degenerate, or outside the range. Endpoints close within numerical
resolution may be grouped; no physically meaningful precision below that is
claimed. Cell samples, nodes and species chains are available in the Lua result.
The provisional calculated snapshot and its keys remain intact; all operations
are atomic and locally scoped. The manual documents exact keys and safeguards.

### Final labels, diagram rendering and a standalone species map

The author requests numerical identifiers for definitive redox boundaries and
lowercase letters for definitive vertical boundaries; plotting of the definitive
boundaries and existence/predominance domains; configurable overlays showing
provisional boundaries and domains eliminated during construction; a standalone
TikZ map with oxidation increasing bottom-to-top and acidity decreasing
left-to-right, using matching boundary labels; and a TikZ node style for labels
appended at the end of the corresponding addplot.

The author explicitly approved representing a species eliminated by
**disproportionation** by the band between its incompatible potential limits,
with distinct styling and an "incompatible domain" label. This is an explanatory
band, not a nonempty stable domain. Zero-width events have no fillable band.
Other inactive candidates do not necessarily define a deleted species domain.

Implementation choices: number retained pairs independently in original inventory
order (redox 1,2,... and vertical a,...,z,aa,...). Multiple disconnected segments
of the same chemical pair share one final identifier; source provisional names
and individual segment indices remain available. Expose a final/<id>/ readout
namespace alongside selection/segment N/. Coalesce final domain strips by
species and bounding equations to avoid grid-cell seams.

The command `\pgfplotsaddpourbaix[options]{name}` requires a selected snapshot,
a two-dimensional linear axis and explicit finite decimal xmin/xmax/ymin/ymax.
It clips regions and boundary pieces to that viewport and the selected pH range,
then submits normal addplot coordinates/polygons and appended label nodes during
survey. It performs no private plot-list mutation or eager E-pH drawing. A name
is resolved once before submission; a plot/handle option also supports snapshots.
Local option-list styles remain TeX tokens, captured into each addplot or node;
use PGF's generic unexpanded alias for ConTeXt compatibility. The plotting macro
does not change diagram aliases or handles. The shared pourbaix/axis style keeps
axes on top of filled regions; no limits, fonts or global compat are imposed.

The initial renderer distinguished solids (blue tint) and aqueous species (green
tint). That default is superseded by adjacency coloring below; phase coloring
remains optional. Fills, domain names and boundary labels can be independently disabled.
Overlays are off by default and have separate option-list styles. Final aqueous
plot labels omit the redundant (aq); the standalone map retains explicit phases.
Manual label placement/style overrides are allowed; automatic collision avoidance
is not claimed. The current default uses the visible area centroid with an interior fallback,
as specified below; incompatible labels sit inside their diagnostic band.

`\pic {pourbaix map=<name>}` requires selection but no axis. It shows all declared
species, dims those absent from every selected cell, and joins retained pairs
with final identifiers. Reuse the existing species-node naming convention and
provide styles for edges, labels and long connections. Old classification pics
remain independent preparation-only views.

## 8. Maintenance and recovery

### Addressed species, boundary and thermodynamic keys

The author approved extending addressed keys to species properties, boundary
presentation, solubility products and pair constants. Use `species/<formula>`
in declarations, `boundary/<final id>` in plot options, and
`solubility product/<solid>` or `standard potential/<oxidized>|<reduced>`
in constants. The author corrected the proposed slash between species: use a
literal `|`, since slash separates PGF paths, and verify this in all three formats.
The slash-pair proposal is superseded. The equivalent equilibrium-constant key
uses `first|second`, preserving the existing balanced-reaction direction.
Keep legacy records compatible. Path identities cannot be overridden by nested
endpoint fields. Require option-list values, reject malformed pairs, and retain
atomic declarations and TeX scope. Boundary display labels never rename data or
change the species map's identifiers.
MkIV makes the pipe active: normalize its meaning only within the declaration
group before PGF expands key names, then restore it. Do not change global catcodes
or expand arbitrary chemical text as Lua source. Tests must check restoration.

### Final-only presentation, coloring and domain nodes

The author subsequently requested species-addressed keys, for example
`domain/Fe(s)={label=$M$,label at={4,-.9},label style={draw,fill=white,name=metal}}`.
This is now the preferred interface. Retain `domain={species=..., ...}` as a
compatibility form. The path identifies the species; a nested species field in
the new form is an error. Both forms share validation, scoping and rendering.

The author requests a simple final-only diagram view, with retained species and
boundaries and no intermediate illustrations. The explicit scientific stages
remain available; a presentation shortcut must not omit required checking.
Provide fill switches and configurable coloring that distinguishes adjacent
domains, plus ordinary opacity and pattern options for diagram overlays.
Provide automatic mathematical uppercase labels (A, B, ..., AA, ...) for all
retained species or an explicit subset, as well as per-species text overrides.
Labels must be fully configurable TikZ nodes, centered automatically within a
domain by default, with user-adjustable positions and node styles.

Implementation choices: adjacency coloring uses the full selected pair graph,
not just viewport-visible edges; zooming does not renumber colors or letters.
Distinct palette entries and sufficient palette size are required. Explicit
per-domain fill overrides can deliberately supersede this automatic guarantee.
The center is the area centroid of visible strips when inside the species domain;
otherwise use the largest visible strip's centroid. Disconnected/nonconvex regions
and finite viewport clipping must be documented, not hidden by an outside label.
The previous phase-only default coloring and vertex-average placement are
superseded, while a phase-coloring option preserves the older presentation.

When new instructions arrive, record settled requirements here and summarize
critical execution rules in `AGENTS.md`. Update affected manual sections and
tests alongside behavior changes. Preserve unresolved questions as unresolved,
and remove stale blockers once the author settles them.

On resuming after compaction, read `AGENTS.md` and this contract, then inspect
the relevant source and tests rather than reconstructing requirements from
memory. These project-specific files are the durable reference; a separate
cross-project skill is not needed for this purpose.

## Water stability overlay

The author requests an independent water diagram overlay with H2(g), H2O and
O2(g) regions, bounded by H+/H2(g) and O2(g)/H2O equilibria. H+, H3O+ and OH-
are not extra redox domains; acid/base identities remain chemically distinct.
The author explicitly approved separate default partial pressures of 1 bar for
each ideal gas, independently adjustable, with standard pressure fixed at 1 bar.
These are two separate equilibria, not a gas mixture with total pressure 1 bar.
Use gas activity p_i/p_standard, water activity 1, and potentials versus SHE.
Implementation: a separate pure model and a scoped PGF water data record, with
explicit temperature or inheritance from a named diagram. Never modify element
species, concentration, provisional/final identifiers or diagram handles.
At 298.15 K the documented rounded oxygen standard potential is 1.229 V
(JRC120120, entry 720, SATP defined in entry 1069); elsewhere require a supplied
value at the specified temperature and the same standard state. Hydrogen E0=0
by SHE convention. No temperature extrapolation or reference conversion.
Provide ordinary deferred addplots, optional transparent/patterned fills and
TikZ labels, scoped styles and queryable equations. Preparation failure preserves
the previous water record. Reject nonpositive pressures, nonfinite quantities,
and parameters without an open central stability region. These boundaries are
thermodynamic equilibria, not overpotential or gas evolution rate predictions.

## Nine additional classical diagrams

The author requests these exact domain inventories (do not substitute hydrated
formulae or add omitted species): Cu(s), Cu^2+, Cu2O(s), Cu(OH)2(s);
Zn(s), Zn^2+, Zn(OH)2(s), ZnO2^2-; Al(s), Al^3+, Al(OH)3(s), Al(OH)4^-;
Ag(s), Ag^+, Ag2O(s); Pb(s), Pb^2+, Pb(OH)2(s), HPbO2^-;
Ni(s), Ni^2+, Ni(OH)2(s); Cr(s), Cr^3+, Cr(OH)3(s), Cr2O7^2-, CrO4^2-;
Mn(s), Mn^2+, Mn(OH)2(s), MnO2(s), MnO4^-;
Cl^-, Cl2(aq), HClO(aq), ClO^-.
The author explicitly approved traditional ZnO2^2- and HPbO2^- notation for
hydrated Zn(OH)4^2- and Pb(OH)3^- at unit water activity. Treat the hydration
relations as documented notation conventions, not measured constants; retain
original domain labels and counts and do not add hydrated domains.
Add inline executable manual examples with water overlays. Implementation choices:
298.15 K, ct=.01 mol/L and explicitly equal element concentrations, consistent
with the earlier report examples. Extend the Pb viewport to pH 20 to show the
plumbite branch of the retained source dataset; document the very alkaline
extension as a formal ideal-model illustration, not realistic dilute speciation.
The nine-species-set gallery supersedes the statement that the requested chromium
hydroxide/chromate example is future work. Keep the older reduced-set report as
a separate pedagogical example. The deferred audit of older data remains pending.
The original 74-record edition is extended to 87 entries: 11 sourced reaction
records plus two explicit notation identities. New phase defaults include
cuprite, pyrolusite and amorphous Cr(OH)3; unspecified source phases stay so.

## Concise plot commands and characteristic extra ticks

The author requests `\addpourbaix` and `\addpourbaixwater` inside an axis.
These are now the preferred spellings; preserve the original long commands as
compatible aliases. Update documentation examples to use the short names.
The author also requests optional native PGFPlots extra x ticks at vertical
boundary pH values, and extra y ticks at intercepts of horizontal/oblique
boundaries which actually reach pH=0, with configurable styles and partial or
complete selection. Do not extrapolate a retained line from a positive-pH support
back to zero merely to supply a tick.
Implementation choices: no automatic extra ticks by default. Plot keys select
all, none, or explicit final boundary IDs independently for x and y. Only visible
retained supports contribute; y additionally requires pH=0 in the viewport and
the retained support. Water can contribute H2/O2 intercepts independently.
Selections refer to chemical final IDs, not overridden display labels. Invalid
or wrong-axis IDs fail before submitting plots or ticks. Coalesce numerical
coincidences within 64 machine epsilons relative to max(1,abs(value)); preserve
user extra ticks and avoid re-adding recognizable literal numerical values.
Existing TeX expressions/ranges remain opaque, so their duplicates cannot be
identified without changing PGF's evaluation semantics.
Apply native extra tick styles in the caller's TeX scope before visualization,
through public keys. Native extra tick styles apply to the entire corresponding
axis tick set; later style options can override earlier ones. No per-plot native
tick-style isolation is promised. Ordinary major ticks/labels are unchanged.
A small adapter reads PGFPlots' stored extra-tick macros because those public
keys use .store in, not stored key values; never write them directly or touch
private plot lists. Tests cover all three formats, accumulation, aliases,
clipping, origin support, scoping, styles and failure atomicity.

## Named domain color and pattern palettes

The author requests multiple recognized color palettes (for example Matplotlib
or Material), TikZ pattern palettes and monochrome printing options. Every
adjacent retained domain must receive a different automatic fill. Apply the
existing graph assignment to pattern slots as well as color slots; fail on
insufficient capacity instead of cycling. Named presentation presets are scoped
and must not alter scientific snapshots. Preserve custom per-domain styles;
explicit arbitrary TikZ overrides can defeat the automatic distinction and must
be documented as such. Color alone does not guarantee grayscale readability.
Implementation choices: Matplotlib/Tableau tab10 and its explicitly identified
25-percent tint, a four-tone grayscale palette, two stock TikZ pattern lists,
and a monochrome alias selecting black patterns with transparent backgrounds.

## Generic pourbaix axis environment

The author requests a format-independent pourbaix environment inside a TikZ
picture, defined in the same manner as axis, with optional key=value input in
the pourbaix family and a PGFKeys fallback to the underlying axis family.
Support declare, check, calculate and explicit finalize. Implementation choice:
execute in written order with no automatic stages or inferred selection bounds.
The author left selection placement open; explicit finalize is retained because
final plotting requires a selected snapshot, while provisional plotting need not.
Use generic pourbaix/endpourbaix commands, LaTeX environment syntax and ConTeXt
startpourbaix/stoppourbaix aliases. Prefer chemical keys on collisions; absolute
paths disambiguate. Keep strict nested-family validation, normal TeX grouping,
ordinary addplot processing and immutable snapshots. Do not create a picture or
a plot implicitly. Named diagrams declared inside remain local to the axis.

## Renamed finalization keys (October 2026)

The author requests removing the ambiguous public `select` key, which can be
confused with choosing a current diagram. The replacement is `finalize`, with
`finalize handle` for explicit handles. The earlier key names `select` and
`select handle` are superseded and must not remain as compatibility aliases.
Update all public examples and key references. This renames the TeX action only:
the scientific algorithm, Lua selection API and result paths `selection/` and
`selected` remain unchanged. Finalization builds retained domains and boundaries
after calculation; it does not choose a current diagram or draw implicitly.

## Legacy pourbaix retirement notice (October 2026)

The author explicitly authorizes publishing an unsupported/superseded notice on
`git@github.com:cjorssen/pourbaix.git` and documenting it in luapourbaix. The
legacy pourbaix package was published only on GitHub, never on CTAN. Direct users
to luapourbaix. This authorizes the legacy README and repository-description
notice, not publication of luapourbaix, repository deletion or GitHub archival.
The successor repository exists but was empty when checked for this task; state
that its publication is in preparation rather than promising a public download.
The current PGFPlots library identifier, key family and environment still use
`pourbaix`; distinguish these from the retired standalone package.

## Reader-facing prose and introductory tutorials

Remove references to implementation chronology or development conversations from
public documentation and code comments. Keep this internal contract and AGENTS.md
as durable requirements; keep the explicitly required AI disclosure prominent.
The manual starts with narrative TikZ-style tutorials, with inline executable
examples: Maxime's five-species iron worksheet at ct=0.01 mol/L, using catalogue
fallback, lettered domains, boundary equations and thermodynamic corrosion in
water; Sophie's IO3^-/I^-/I2(aq) diagram, explicit missing potentials, both aqueous
boundary conventions and provisional lines illustrating disproportionation;
Aya's seven-species uranium diagram at ct=1 mol/L.
The author supplies E(U4+/U)=-1.51 V, E(U4+/U3+)=-0.61 V,
E(UO2^2+/U4+)=0.33 V and pKs=18.5,49.0,24.0 for U(OH)3,
U(OH)4 and UO2(OH)2. Preserve these values exactly. Tutorial assumptions are
298.15 K, SHE, pKw=14 and the ideal concentration model. Initially demonstrate the uranyl hydroxide as an acid-balanced equilibrium
with logK=4, equivalent to pKs=24. Then demonstrate the optional explicit
reaction on its solubility record with logKs=-24. Only automatic solubility
inference is restricted to monatomic cations.
Sophie uses ct=0.001 mol/L and explicitly sourced aqueous iodine potentials;
these illustrative records are not added to the offline catalogue.
Nested addressed declaration keys must execute immediately even during axis
option filtering; interrupt filtering locally through PGF's public mechanism.

The author requests a combined declaration/check/calculation/finalization action
and executable .get examples for Maxime and Sophie. The public key is build;
it accepts declaration options and uses preceding scoped pH bounds/step. All
four stages must succeed before committing a snapshot or changing aliases.
Preserve the separate stages for inspection and report normal diagnostic errors.
Tutorial queries show final coefficients, vertical pH, provisional coefficients
and the iodine elimination threshold, with explicit TeX scope and support rules.

Aya's tutorial must omit the water overlay and demonstrate both a color version
for the presentation and a monochrome TikZ-pattern version for audience handouts,
reusing one calculated diagram with foreach.

The author requests tutorial pictures for increasing oxidation number, increasing
acidity and their combination. Show these in Sophie's tutorial, explicitly noting
that its iodine set has only one species in each oxidation group and therefore
no nontrivial within-group acidity comparison. The presentation key
/tikz/pourbaix/acidity direction supports increasing/decreasing (default
unchanged: decreasing), with matching captions in acidity pics and maps.
This display choice must not alter chemical ordering, handles or boundary IDs.

The author also requests all three classification pictures in Aya's uranium
tutorial. Show increasing oxidation number, increasing within-group acidity and
the combined final-boundary map. Explain the nontrivial +III/+IV/+VI acidity
pairs and distinguish classification from stability: U(OH)3(s) is retained in
classification but dimmed in the final map; U3+ remains over part of the pH range.
Keep the complete example inline and preserve all supplied numerical data.

Maxime's tutorial must demonstrate characteristic extra x/y ticks as numerical
hints for students. Recall s=RT ln(10)/F locally in the water discussion, as well
as defining it in the boundary derivation. Sophie's plotted comparisons must
show extra ticks and a native PGFPlots grid, demonstrating ordinary axis options.
Her iodine set has no vertical boundary: query the elimination event threshold
with .get for an explicit native extra x tick, rather than implying that the
automatic vertical-boundary tick selector supplies a disproportionation pH.

The author requests a configurable Nernst factor, notably 0.06 V at 25 degrees C.
Use declaration key nernst factor=auto (default RT ln(10)/F) or a positive finite
value in volts. Apply the effective factor consistently in E0/log K closure,
boundary equations, selection and reported data; retain the actual temperature
and all source inputs. This is an explicit teaching approximation. Redundant
inconsistent datasets must still fail. Export the effective factor and origin.
Water associated with a diagram inherits its factor as well as temperature;
reject explicit mismatches. Standalone water supports its own factor setting.
Do not change existing defaults or retroactively modify immutable snapshots.

Use the equals sign (=), not paired harpoons, for chemical equilibria and
half-reactions in the documentation and generated report reactions. This is
presentation only; retain reaction orientations and stoichiometric data.
Aya's tutorial must include an actually generated report for her presentation
notes, with supplied/derived constants, elimination events and boundary equations.
Keep its complete input and rendering inline, with page breaks between cards.

Oxidation-number labels in all three classification pics support the scoped
TikZ key pourbaix/oxidation number format=arabic|roman (default arabic).
Roman notation is upright, preserves signs and writes zero as 0; nonintegers
and magnitudes above 3999 retain numeric notation without integer rounding.
This presentation choice must not alter chemical data, charges or boundary IDs.
Demonstrate it in Aya's inline classification pictures.

Explicit non-redox constant reactions are supported through optional reaction
fields on solubility-product and equilibrium-constant records, including
addressed records. Preserve the equation's orientation, coefficient scale and
associated K/log K. Validate atoms, charge, pair/solid references and bounded
rational stoichiometry; never repair an unbalanced equation. HO^- is an explicit
OH^- alias; auxiliary participants never add domains. Unknown ligand activities
are not supplied merely by parsing a reaction. Keep source reactions and their
coefficients queryable and visible in report input cards. Without reaction,
retain existing documented inference. Aya's tutorial first retains the manual
log K=4 conversion, then executes the explicit uranyl dissolution with log Ks=-24.
This supersedes the requirement to use only the manual acid-balanced record
for uranyl hydroxide: monatomic-only inference remains a shorthand limitation,
not a restriction on explicit solubility reactions. The simple Lua parser needs
no LPeg dependency; errors identify malformed terms and failed conservation laws.

Maxime's tutorial must demonstrate the water-stability region filled with TikZ
hatching over the colored iron domains. Keep the pattern background transparent,
leave the hydrogen/oxygen outer regions unfilled by the water overlay, and
explain drawing order, independent styles and hatch-stroke opacity. Use existing
water domain styles; preserve the chemical snapshots and color adjacency rules.


Provide the generic public shortcut \pgfpourbaixset{keys}, exactly equivalent
to \pgfkeys{/pgfplots/pourbaix/.cd,keys}, without adding a group or an automatic
stage. Prefer it for tutorial settings, actions and data queries; retain native
PGFPlots/TikZ commands for their own families. Preserve key order, handlers,
absolute paths, errors and TeX scope in all three supported formats.


Both \addpourbaix[options]{name}; and \addpourbaixwater[options]; require a
semicolon terminator, as do their original long-name aliases. Whitespace before
the terminator is accepted. Check it before any plot submission or water
preparation; report a clear error without consuming following input if missing.
No appended node/path syntax is supported: use existing label keys. This
supersedes the former unterminated syntax; update inline examples and internal
report/final-diagram callers while preserving the normal PGFPlots pipeline.


## Interface and documentation review (October 2026)

The final review preserves the generic TeX/engine-bridge/pure-Lua separation,
immutable snapshots and normal PGFPlots survey/visualization path. Errors during
plot-option processing must cancel the affected request even in nonstop mode.
In particular, failed water preparation must not render an older water record.
An explicitly empty reaction field is invalid; only omission requests inference.
Export reaction participants in sorted order and document detokenized source text.
Keep the manual organized by usage: an entry-point/family map, input reference,
plotting syntax, domain presentation, water, extra ticks, classification and
reports. In Sophie's tutorial, explain disproportionation and query its threshold
before optional classification views. Keep the required semicolon migration
explicit for both short and long plot names. Scientific source harmonization
remains the separately recorded deferred audit, not a result of this code review.


### Scientific audit (2026-10-08)

The author explicitly authorized the previously deferred scientific audit.
The source/conversion audit is now recorded in `doc/scientific-audit.md`; this
supersedes the earlier pending status for that audit, not the qualifications
about reference-grade source harmonization. All 59 USGS-derived reactions were
reconstructed from newly retrieved, hash-verified pinned files. Keep this
offline optional check separate from ordinary tests and runtime lookup.
The ordinary suite now checks the phase-aware cycle inventory: the copper
2.5 mV discrepancy is documented, not silently averaged away. Primary source
traceability and common standard states remain incomplete. No numerical
literature data were replaced on the strength of secondary-table agreement.

Catalogue edition 2026-10-08.1 corrects the aqueous chlorine E0 storage: its
source value 1.396 V must remain fixed with a rounded Nernst factor. In contrast,
records whose source supplies log K retain that log K. Preserve both behaviors
in regression tests. Aya's prescribed inputs remain unchanged, with an explicit
ideal-model qualification at 1 mol/L. No publication is authorized.

### GitHub and CTAN publication preparation

The author supplied the CTAN upload basics, addendum and API documentation and
reported maintainer advice against a TDS ZIP for this package. The CTAN location
is /macros/luatex/generic/luapourbaix/, superseding graphics/pgf/contrib/luapourbaix.
Runtime installation remains tex/generic/luapourbaix/. The source ZIP is now the
only release archive produced; previous optional TDS generation is superseded.

The author requests real manual-figure captures in the GitHub README and an
English package announcement. Capture the inline manual results, with provenance,
without externalizing examples. Exclude these derived GitHub assets from CTAN;
maintain doc/README-CTAN.md as the archive's unique top-level README. Preserve the
license, author and AI disclosure in both READMEs. Use the documented CTAN API
with local JSON fields and separate offline-check, validation and upload actions.
The choice of API over l3build is an implementation decision. No publication or
external submission was authorized by this preparation request. Remaining steps
and the announcement are in doc/releasing.md and doc/announcement.txt.


### Version 1.0 GitHub publication authorization

On 2026-10-08 the author approved the announcement and prepared artifacts,
selected version 1.0 for publication that day, and authorized cleanup, the
first Git commit, a version tag and GitHub publication. This supersedes earlier
GitHub publication restrictions for this release. CTAN publication is explicitly
reserved for the next step and remains unauthorized. Preserve source files,
regression tests, the scientific audit and persistent instructions.
