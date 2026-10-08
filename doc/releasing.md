# Release preparation

Author and maintainer: Christophe Jorssen, <christophe.jorssen@gmail.com>.
Repository: `git@github.com:cjorssen/luapourbaix.git`.

Version 1.0 dated 2026-10-08 is authorized for GitHub publication.
CTAN submission is reserved for a later, separately authorized step.
The commands below prepare reviewable artifacts. Do not send an announcement independently: the reviewed
text accompanies the eventual CTAN submission and GitHub release.

## Distribution decisions

Submit **only `build/dist/luapourbaix.zip`** to CTAN, with the proposed location
`/macros/luatex/generic/luapourbaix/`. This follows the CTAN maintainer's advice
for generic packages requiring LuaTeX. It is an archive location, not a TDS
installation path: runtime files still install in `tex/generic/luapourbaix/`.
No TDS ZIP is generated or nested in the submission.

The source ZIP contains one `luapourbaix/` directory, handwritten runtime sources
in `tex/`, PDF documentation and inline TeX source in `doc/`, tests, build tools
and license notices. Subdirectories keep the numerous files navigable.
Sources have portable filenames, LF line endings and readable permissions.
The builder rejects duplicate basenames, empty sources and BOM/CR text, and sets
ZIP text flags. It excludes caches, logs, downloaded scientific data, working
instructions and GitHub-only screenshot assets.

`doc/README-CTAN.md` is the separately maintained, text-oriented CTAN README;
it becomes the archive's top-level `README.md`. The illustrated repository
README remains on GitHub. Keep version, author, license and AI disclosure
consistent in both. Do not include a second copy of either README in the ZIP.
`MANIFEST.md` records the distributed source work.

## Remaining publication steps

1. Choose the first public version and actual release date. The first GitHub release
   is 1.0, dated 2026-10-08. Synchronize `release.json`, the Lua
   module, manual and both READMEs. Use the actual release date for subsequent releases.
2. Review `doc/announcement.txt`, the API description and administrative note
   in `release.json`, and the scientific qualifications in the manual. The
   primary-source harmonization work is disclosed; do not call this a certified
   reference database.
3. Run `make dist`. It runs all tests, all three formats, the manual and its index,
   then creates the source ZIP, checksums, `ctan-fields.json` and the human-readable
   `ctan-upload.txt`. Run `python3 scripts/ctan.py check` for offline field checks.
   Rebuild and inspect the unpacked archive as an independent source tree.
4. Refresh GitHub captures with `python3 scripts/readme-figures.py` after the final
   manual build. This maintainer-only command needs Poppler and Pillow. It crops
   existing manual result boxes; all examples remain inline in the manual.
   Review all three images visually. `doc/images/captures.json` records their
   page numbers, crop coordinates and source PDF digest. These assets and the
   capture script are excluded from CTAN.
5. After explicit publication authorization, create/review the Git commit and version tag, publish the repository and GitHub release, and attach the manual
   PDF and source ZIP. Confirm repository links resolve before the CTAN request.
   Do not commit build caches, downloaded source databases or archive leftovers.
6. Validate the prepared request with `python3 scripts/ctan.py validate`, inspect
   the returned errors/warnings, and then submit once with
   `python3 scripts/ctan.py upload --confirm-publication`. Both network commands
   send the ZIP and metadata; validation does not submit it for publication.
   The first CTAN request uses `update=false`: the old pourbaix project was never
   on CTAN. An eventual update must explicitly change this field in the builder.
7. Retain CTAN's response and await the upload manager. After acceptance, verify
   the catalogue and mirror links, then update publication status and add the
   canonical CTAN links to the documentation. Do not add a release badge or
   imply TeX Live/MiKTeX availability before that availability is verified.

## Submission mechanism

Use the documented CTAN HTTP API with the existing Python build tooling; no
migration to l3build is needed. `scripts/ctan.py` defaults to an offline check.
Its explicit `validate` and `upload` actions use curl, save the JSON response,
preserve multiline fields, and distinguish validation from actual submission.
The publication switch is a guard against accidental invocation, not a substitute
for the maintainer's authorization. Local checks do not guarantee CTAN acceptance.
No API request has been sent as part of local preparation.

The announcement describes the package rather than a development changelog.
Administrative notes explain the generic LuaTeX location, handwritten files,
absence of a TDS archive, and the GitHub-only predecessor. They are not the
public announcement.

References checked for this preparation:
[upload basics](https://ctan.org/help/upload-pkg),
[upload addendum](https://ctan.org/file/help/ctan/CTAN-upload-addendum), and
[submission API](https://ctan.org/help/submit).
