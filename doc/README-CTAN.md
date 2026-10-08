# luapourbaix

Version 1.0 (2026-10-08).

A generic PGFPlots library for limiting potential-pH (Pourbaix) diagrams of
aqueous chemical systems. Requires LuaTeX, PGF/TikZ and PGFPlots; supports
plain LuaTeX, LuaLaTeX and ConTeXt MkIV.

Declare species, temperature, concentration and a boundary convention. The
library checks thermodynamic data, uses a sourced offline catalogue when needed,
calculates boundaries and reconstructs final domains, including disproportionation.
It provides water overlays, color and pattern palettes, classification pictures,
reports and PGF key access to numerical results. It uses a limiting ideal model,
not full aqueous speciation. See doc/scientific-audit.md for data qualifications.

Author and current maintainer: Christophe Jorssen
Contact: christophe.jorssen@gmail.com
Repository: https://github.com/cjorssen/luapourbaix
License: LPPL version 1.3c or, at your option, any later version.
Maintenance status: maintained. See COPYING.md and LICENSE.

AI disclosure: this package was "vibe coded" with ChatGPT 6 Astra under the
direction of Christophe Jorssen, who is the author and maintainer.

## Installation

Copy all files from tex/ into tex/generic/luapourbaix/ in a personal TeX tree.
Keep the Lua modules alongside pgflibrarypgfplots.pourbaix.code.tex and refresh
the filename database if needed. No shell escape or network access is required.

For LuaLaTeX, load pgfplots and then use:

    \usepgfplotslibrary{pourbaix}

Plain LuaTeX uses \input pgfplots.tex before the same library command.
ConTeXt MkIV uses \usemodule[pgfplots] and \usepgfplotslibrary[pourbaix].

## Documentation and source

Read doc/luapourbaix-manual.pdf. Its complete TeX source is provided, including
all examples inline. The source work is listed in MANIFEST.md. Maintainers can
run make check or make dist with Python 3.8+, Make and a suitable TeX installation.

The unsupported pourbaix package was distributed only on GitHub, never on CTAN.
luapourbaix replaces it; the PGFPlots library identifier pourbaix now refers to
this implementation.

Copyright 2026 Christophe Jorssen.
