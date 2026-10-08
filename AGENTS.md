# Development contract

Publication metadata: author and current maintainer Christophe Jorssen
<christophe.jorssen@gmail.com>; LPPL 1.3c or later, status `maintained`.
Keep the explicit disclosure that the package was "vibe coded" with
ChatGPT 6 Astra prominent in the README, manual and author notice.
The intended remote is `git@github.com:cjorssen/luapourbaix.git`.
The author authorized the first commit, tag and GitHub publication of version
1.0 dated 2026-10-08. CTAN submission remains unauthorized until the next step. The author explicitly authorized publishing the legacy pourbaix
repository deprecation notice; this supersedes the earlier blanket announcement
restriction for that notice only. Preserve regression tests and this durable
contract when cleaning intermediate outputs. Organize the manual by usage and
reference topics, not development chronology. See `doc/releasing.md` for local
source archive preparation.

Generic PGFPlots library for limiting potential-pH (Pourbaix) diagrams.
Required targets: plain LuaTeX, LuaLaTeX and ConTeXt MkIV. All project files,
code, comments, diagnostics and documentation must be in English. Conversation
with the author may remain in French.

## Persistent instructions and resuming work

Before changing this project, including after context compaction or a new
session, read [the project contract](doc/project-contract.md). It records the
author's requirements, scientific rules, unresolved wording and the distinction
between requirements and implementation choices. Do not rely on chat history
alone. Consult the README and source/tests for the current implementation.

When the author adds or corrects an instruction, update this file and/or that
contract during the same task; update the manual when the instruction affects
documented behavior. Mark resolved questions and superseded decisions explicitly.
Keep project-specific instructions in this repository; a separate reusable skill
is not required to preserve them.

The manual must be as comprehensive as possible, following the presentation and
reference style of the TikZ/PGF and PGFPlots manuals. Scientific explanations and
examples should support undergraduate solution-chemistry teaching.

## Scientific scope

The user declares an element, selected species, thermodynamic constants, temperature, total
element concentration, an explicit aqueous boundary convention, and optionally
a diagram name. The concentration includes aqueous and generalized solid
concentrations weighted by the number of atoms of the selected element.
On a limiting boundary, contributions from species outside the pair are
neglected. Equal species concentrations and equal element concentrations are
distinct conventions; never select either implicitly.

Aqueous domains express predominance; solid domains express existence. At an
aqueous-solid boundary, the solid is at its existence limit: its incipient amount
has a generalized concentration negligible compared with that of the aqueous
species. Other species' contributions are neglected in the limiting model.
Do not confuse this amount rule with an activity assignment.

At a boundary between two solids, both are at their existence limit and both
activities equal 1. This is the only solid-solid boundary input needed by the
algorithm: do not infer solid amounts, solve for other species concentrations,
or use the total concentration or aqueous convention to assign these activities.
After declaration, classify species by increasing oxidation number and, within
each group, decreasing H+/H2O stoichiometric acidity. Allow explicit oxidation
numbers for delicate cases; require complete explicit acidity ranks when ligand
compositions prevent comparison. The author approved this fallback and an
inventory of **all unordered species pairs**, not just adjacent ones.
Different oxidation numbers identify Nernst (horizontal/oblique) candidates;
equal numbers identify equilibrium-quotient (vertical) candidates. Assign
configurable names, defaulting to `a-temp`, `b-temp`, ... for vertical candidates
and `1-temp`, `2-temp`, ... for redox candidates. Preparation only inventories these candidates. The subsequent explicit calculation
computes all provisional equations; the subsequent selection stage reconstructs
the limiting oxidation-state chain.
Expose both classifications as ordinary TikZ pics outside a PGFPlots axis.

After declaration, offer an explicit thermodynamic sufficiency check (the author
chose a separate step). It must precede every boundary calculation or
plot. Derive missing constants from supplied reaction data where possible,
expose results through PGF key=value data, and otherwise identify the affected
provisional boundaries in a clear error. Combine reaction free energies, never
unweighted standard potentials. Preserve preparation and valid snapshots on failure.
The author approved a default water ion product at 298.15 K: the implementation
uses the teaching approximation 1e-14, overridden by supplied or derivable data.
No water default or temperature extrapolation is allowed at other temperatures.

Before reporting missing thermodynamic data, consult an offline library for
aqueous systems: standard potentials, acidity, solubility and (currently only)
hydroxide complex formation. The author supplied the Wikipedia standard-electrode
potential data page as a starting source. Preserve source reactions, temperature,
standard-state conventions and provenance; distinguish cumulative beta from
hydrolysis constants. User data and their consequences take priority over fallback
data. Do not add diagram domains for auxiliary aqueous reaction participants.
The author chose documented default solid phases, with explicit overrides,
rather than a mandatory phase choice. Do not silently identify polymorphs.

After a successful explicit check, calculate every provisional equation and expose
its coefficients and expression through PGF keys. The author approved the ideal
dilute model: aqueous activity [species]/c0, c0=1 mol/L, pure solids and water
activity 1, pH=-log10(a(H+)). Document this default and the source-standard-state
approximation. Use the pair's element balance and selected aqueous convention.
Do not assign a finite vertical line to a pH-independent equilibrium: report an
identity or an empty locus. Calculation creates another immutable snapshot.

The author now requires a pH sweep that removes incompatible intermediate domains
and reconstructs the replacement boundaries. They confirmed that "disjoint"
means an empty common potential interval: a lower bound above the upper bound
causes disproportionation. They approved explicit pH min/max, default step 0.1,
and additional known intersection events. Merge touching intervals only for the
same species pair and equation; retain gaps and distinct coincident pairs.
Inventory all inactive supports and explicit elimination/replacement events,
including cascades, through PGF data. Replacement pairs already exist in the
all-pair inventory: reuse their checked equation with their own concentration
convention, not an average of the retired numerical lines.

Final retained chemical pairs must be identified by numbers for redox boundaries
and lowercase letters for vertical boundaries. Render final boundaries and
existence/predominance domains through ordinary PGFPlots addplot commands. Offer
configurable overlays for provisional/inactive boundaries and eliminated domains.
The author approved showing a disproportionating species as the band between its
incompatible limits, explicitly labeled "incompatible domain", never as a stable
region. Labels belong to node commands appended to the boundary addplot, with a
public TikZ style usable in user-written plots.
Provide a standalone TikZ species map, oxidation increasing bottom to top and
acidity decreasing left to right, with matching final boundary labels. Preserve
prepared and selected data; plotting must not change handles or names.

This is still a limiting construction, not full aqueous speciation. Document
roundoff resolution, degenerate cases, viewport clipping, and pairwise ambiguities.
Do not silently add domain species, temperatures, reference electrodes or
standard states. Auxiliary reaction participants are not diagram domains.

## Architecture and quality

Final-only plots must be simple to request. Automatic domain colors distinguish
adjacent retained species; allow fill switches, transparency and TikZ patterns.
Offer mathematical uppercase domain labels for all species or a chosen subset,
per-species text/node-style overrides, and automatic interior centering with
explicit user positions. Keep these presentation choices separate from chemistry.
Prefer species-addressed keys `domain/<species>={label=...,label at=...,
label style=...,style=...}`; retain the older species-field record as compatible
syntax. The species in the path must not be silently overridden by nested data.
Apply this addressed-key convention to species data, final-boundary presentation
and thermodynamic constants. Pair addresses use a literal `|`, never `/`, between
species; verify PGFKeys processing in all three supported formats.

Provide reusable, configurable diagram reports with foreach composition:
classification pics, final plots and diagnostic overlays, thermodynamic inputs
and derived constants, and boundary equations. Include inline Fe/Cu/Zn/Cr manual
examples, documenting incomplete species sets. Reports consume immutable selected
snapshots. A future scientific source audit is recorded in the project contract;
do not confuse GitHub hosting with scientific validation or silently migrate data.

- Distributable sources live in `tex/generic/luapourbaix/` (TDS layout).
- Load through `\usepgfplotslibrary{pourbaix}`; keys belong to
  `/pgfplots/pourbaix`. Respect PGF key styles, overrides and TeX grouping.
- Keep the library format independent. Preserve catcodes; reserve internal
  control sequences with the `\luapourbaix` prefix. Do not set global `compat`,
  fonts or axis limits.
- Keep the Lua core independent of `tex`, `token`, `node`, `kpse`, and
  `resolvers`. Return module tables, use local variables and defensive copies.
  Isolate engine services in the bridge. No user text becomes Lua source.
- Describe expansion, escaping and catcodes at every TeX/Lua boundary. Validate
  finite numbers, units, references and required values before committing data.
  Failed declarations must not replace an existing valid diagram.
- Store independent diagram snapshots. Names are TeX-scoped aliases for stable
  handles; a deferred plot must capture a handle, not a mutable name lookup.
- PGFPlots surveys plots and renders them at axis end. Plots must enter
  its normal survey/visualization pipeline; never draw eagerly or patch private
  PGFPlots lists merely to implement declarations.
- Source and document all scientific data. Separate data, calculation and
  rendering; use problem-specific tolerances and avoid premature rounding.
- No runtime external dependency, shell escape or network access.
- Document each key's syntax, defaults, scope, units, errors and examples.
  All manual examples remain inline and execute during manual compilation.
  No TikZ externalization or precompiled example figures. `../pgf/` is an
  editorial reference, not a runtime dependency.

## Verification

`make check` runs standalone Lua tests, all three TeX formats, negative tests,
and the manual with its index. `make doctor` reports local tools.
Test behavior, failure atomicity, scope and transport, not just implementation
details. Use independent analytic results for scientific tests. Never claim
unverified compatibility. Generated files belong in `build/`; do not alter the
global TeX installation.

The independent water overlay uses ideal gas activities p_i/(1 bar), with the
user-approved default p(H2)=p(O2)=1 bar for separate equilibria. Use a(H2O)=1
and SHE potentials; inherit or explicitly require temperature. The rounded
oxygen E0=1.229 V default is valid only at 298.15 K; require user data elsewhere.
Do not add H+, H3O+ or OH- redox regions or alter the element diagram snapshots.

Prefer `\addpourbaix` and `\addpourbaixwater` inside axes; keep the original
long names compatible. Characteristic extra ticks are opt-in and use native
PGFPlots ticks/styles. Vertical ticks use retained visible boundaries; intercept
ticks require actual retained support at pH=0, never extrapolation. Preserve
user extra ticks, scientific snapshots and TeX scope; permit ID-based subsets.

Named color and TikZ pattern palettes must both respect retained-domain adjacency.
Reject insufficient or repeated entries instead of cycling onto a neighbor.
Provide monochrome printing presets; do not promise grayscale separation from
color hues alone. Keep recognized palette provenance and tint transformations
documented, and preserve deferred rendering and TeX scope.

Use `finalize` and `finalize handle` for the explicit final-domain construction
stage after calculation. The former `select` and `select handle` keys have been
removed at the author's request; do not restore compatibility aliases. The Lua
selection API and exported selection data paths are unchanged.

The legacy `cjorssen/pourbaix` package is unsupported and superseded by luapourbaix.
It was published only on GitHub, never on CTAN. State this in the README/manual;
distinguish that old package from the current pourbaix library identifier, key
family and environment. Do not imply the successor has been published while its
repository is still empty.

Public prose and code comments describe usage and behavior, not development
conversations or chronology. Preserve the required AI disclosure and internal
requirements record. Keep the introductory Maxime (Fe), Sophie (I) and Aya (U)
tutorials inline, with sourced or explicitly supplied numerical inputs; see the
contract for the uranium dataset and the uranyl solubility conversion.

The author requests a combined declaration/check/calculation/finalization action
and executable .get examples for Maxime and Sophie. The public key is build;
it accepts declaration options and uses preceding scoped pH bounds/step. All
four stages must succeed before committing a snapshot or changing aliases.
Preserve the separate stages for inspection and report normal diagnostic errors.
Tutorial queries show final coefficients, vertical pH, provisional coefficients
and the iodine elimination threshold, with explicit TeX scope and support rules.

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


The authorized scientific source/conversion audit is recorded in
`doc/scientific-audit.md`. Preserve its distinction between verified source
reconstruction and incomplete reference-grade evaluation. Keep the documented
copper cycle exception visible; do not silently average conflicting sources.
Source E0 records remain fixed in volts under a rounded Nernst factor; source
log-K records remain fixed in log K. The chlorine regression covers this rule.

CTAN preparation follows the maintainer advice supplied by the author: propose
/macros/luatex/generic/luapourbaix/ and submit a browsing-friendly source ZIP
without a TDS ZIP. This is distinct from the tex/generic/luapourbaix installation
path. Use the CTAN API with the existing build tooling; no l3build migration is
needed. Maintain a plain CTAN README separately from the illustrated GitHub
README. GitHub captures must come from compiled inline manual examples and stay
out of the CTAN archive. Keep an English announcement in doc/announcement.txt.
Preparation does not authorize GitHub publication or a CTAN submission.

The 2026-10-08 GitHub publication authorization supersedes earlier preparation-only
restrictions for version 1.0. Preserve tests, source provenance and contracts
during cleanup. Do not submit to CTAN in this task.
