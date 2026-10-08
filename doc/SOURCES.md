# Scientific source notes

The offline catalogue is a teaching-data collection, not a globally harmonized
reference database. It contains 85 sourced reaction records and two explicit traditional-notation
identities.
Complete reactions, source locators, revision identifiers and transformations
are recorded in `luapourbaix-database.lua` and the manual's data part.

- Twenty-four standard potentials use
  [Wikipedia, revision 1377006472](https://en.wikipedia.org/w/index.php?title=Standard_electrode_potential_(data_page)&oldid=1377006472).
- Fifty equilibrium records use the pinned
  [USGS PHREEQC database](https://github.com/usgs-coupled/phreeqc3/blob/b0b3be767158ccc3322d2c816625cf470045e67e/database/phreeqc.dat).
- Supplementary reactions use the same revision's `minteq.v4.dat` and
  `llnl.dat`, the chromium benchmark cited in the manual, and a compiled aqueous
  chlorine potential credited to Lide (1999) in the cited research thesis.
- ZnO2^2- and HPbO2^- are traditional notation for hydrated
  species at unit water activity. Their identities are not measured hydration
  constants and must not be presented as additional independent species.
- The independent water overlay's rounded 1.229 V oxygen potential at 298.15 K
  is documented against JRC120120, DOI
  [10.2760/732809](https://doi.org/10.2760/732809). Its gas standard pressure is
  1 bar and its potential reference is SHE.

GitHub hosting provides a pinned source revision, not scientific validation.
The compiled potentials have not all been traced to primary measurements;
consistency of all reaction cycles, standard states and phases is not certified. Sources that use molality have not been
silently converted to molarity. No temperature extrapolation is implemented.

Only selected numerical facts and original catalogue code are distributed.
Downloaded upstream files used for verification are not part of the package.
The [scientific audit](scientific-audit.md) records the checked coverage, the
copper cycle discrepancy, and remaining reference-quality limitations. The optional
`tests/lua/source-audit.lua` reconstructs 59 source reactions and log K values
from separately obtained pinned copies of `phreeqc.dat`, `minteq.v4.dat` and
`llnl.dat`; with only the first file it checks the original 50 entries.
The ordinary tests also audit phase-aware cycles and distinguish source E0
from source log K when a rounded Nernst factor is requested.

## Tutorial inputs outside the catalogue

The iodine tutorial uses the [university teaching compilation by Woravith](https://sci.rmutp.ac.th/woravith/?page_id=1786):
E0(I2(aq)/I-)=0.620 V and the alkaline E0(IO3-/I-)=0.269 V.
The balanced alkaline reaction consumes three waters. At 298.15 K, with
pKw=14, conversion to the acid-balanced reaction gives 1.0972309 V.
The manual distinguishes dissolved iodine from solid iodine and states the
concentration and activity conventions. These values are explicit example
inputs, not evaluated additions to the offline catalogue.

The uranium tutorial uses the six numerical values supplied for that example:
-1.51, -0.61 and 0.33 V for U4+/U, U4+/U3+ and UO2^2+/U4+;
pKs=18.5, 49.0 and 24.0 for U(OH)3, U(OH)4 and UO2(OH)2.
The example assumes 298.15 K and SHE; no mineral phase is assigned.
The acid-balanced uranyl dissolution logK=4 follows from pKs=24 and pKw=14.
These inputs are not catalogue reference data.
