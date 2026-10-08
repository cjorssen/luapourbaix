# Contributing

Use English for code, comments, diagnostics, documentation and tests. The library
is format independent: changes must remain compatible with plain LuaTeX,
LuaLaTeX and ConTeXt MkIV. Keep the pure Lua modules independent of TeX services;
only `luapourbaix-tex.lua` may access the engine. All user text crosses that
boundary as data, never Lua source.

Run `make doctor` to inspect local tools and `make check` before submitting a
change. Preserve failure atomicity, TeX scope and immutable snapshots. Plots and
ticks must use PGFPlots' ordinary survey/visualization pipeline. Add independent
analytic checks when changing chemical calculations. Keep all manual examples
inline and executable; do not use TikZ externalization.

Scientific data changes must state the source reaction, temperature, standard
state, reference electrode, solid phase and any conversion performed. Do not
replace a data source merely because a different hosting site seems preferable.
The source audit and remaining qualifications are described in `doc/SOURCES.md`.

The repository's `AGENTS.md` and `doc/project-contract.md` preserve detailed
maintainer instructions. They are working references, not user documentation.
The publication procedure is in `doc/releasing.md`.

Author and current maintainer: Christophe Jorssen,
<christophe.jorssen@gmail.com>. Contributions are distributed under LPPL 1.3c
or later. Keep the explicit AI-assistance disclosure in `AUTHORS.md`, the
README and the manual.
