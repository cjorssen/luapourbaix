#!/usr/bin/env python3
# Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
# This file is part of luapourbaix.
# Distributed under the LPPL 1.3c or, at your option, any later version.
# Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

"""Repository-local builds; no installation, shell escape or network access."""

import argparse
import hashlib
import json
import re
import zipfile
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
SOURCE = ROOT / "tex" / "generic" / "luapourbaix"
if not SOURCE.is_dir():
    SOURCE = ROOT / "tex"  # Browsing-friendly CTAN source archive.
METADATA = json.loads((ROOT / "release.json").read_text(encoding="utf-8"))
ENV = os.environ.copy()
# A trailing separator preserves the distribution's normal Kpathsea search.
ENV["TEXINPUTS"] = os.pathsep.join((str(SOURCE), str(ROOT / "tests/tex"),
                                  ENV.get("TEXINPUTS", "")))
# Keep ConTeXt's cache local; --path below feeds its independent resolver.
ENV["TEXMFCACHE"] = str(BUILD / "cache")
ENV["TEXMFVAR"] = str(BUILD / "texmf-var")
# LuaTeX's openout_any=p also applies to Lua font-cache writes. Allow this
# output tree explicitly without weakening the distribution's file policy.
ENV["TEXMFOUTPUT"] = str(BUILD)


def run(name, args, cwd, expected_error=None, pdf=None):
    cwd.mkdir(parents=True, exist_ok=True)
    log = cwd / (name + ".console.log")
    environment = ENV.copy()
    if name in ("smoke-context", "context-cache"):
        # ConTeXt does not interpret Kpathsea's trailing-colon default path.
        environment.pop("TEXINPUTS", None)
    if pdf:
        # A previous successful build must never hide a missing new output.
        (cwd / (pdf + ".pdf")).unlink(missing_ok=True)
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(args, cwd=cwd, env=environment, stdout=stream,
                                stderr=subprocess.STDOUT, check=False)
    output = log.read_text(encoding="utf-8", errors="replace")
    if expected_error:
        ok = result.returncode != 0 and expected_error in output
    else:
        ok = result.returncode == 0
    if not ok:
        print(output[-6000:], file=sys.stderr)
        raise RuntimeError(f"{name} failed; see {log}")
    if pdf:
        require_pdf(cwd, pdf)
    print(f"PASS {name} ({log.relative_to(ROOT)})", flush=True)


def require_pdf(directory, name):
    pdf = directory / (name + ".pdf")
    if not pdf.exists() or pdf.stat().st_size == 0:
        raise RuntimeError(f"Missing output: {pdf}")


def doctor():
    for program in ("texlua", "luatex", "lualatex", "context", "pdftex", "makeindex"):
        path = shutil.which(program)
        print(f"{program}: {path or 'MISSING'}")
        if path:
            result = subprocess.run([path, "--version"], capture_output=True,
                                    text=True, check=False)
            print("\n".join(result.stdout.splitlines()[:2]))
    for filename in ("pgfplots.code.tex", "pgfmanual.sty", "pgfmanual-en-macros.tex"):
        subprocess.run(["kpsewhich", filename], check=True)


def test():
    run("lua-scientific-audit", ["texlua", str(ROOT / "tests/lua/scientific-audit.lua"),
                               str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-ticks", ["texlua", str(ROOT / "tests/lua/ticks.lua"),
                      str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-tutorials", ["texlua", str(ROOT / "tests/lua/tutorials.lua"),
                          str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-gallery", ["texlua", str(ROOT / "tests/lua/gallery.lua"),
                        str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-water", ["texlua", str(ROOT / "tests/lua/water.lua"),
                      str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-core", ["texlua", str(ROOT / "tests/lua/core.lua"),
                     str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-thermodynamics", ["texlua", str(ROOT / "tests/lua/thermodynamics.lua"),
                             str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-database", ["texlua", str(ROOT / "tests/lua/database.lua"),
                         str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-equations", ["texlua", str(ROOT / "tests/lua/equations.lua"),
                          str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-selection", ["texlua", str(ROOT / "tests/lua/selection.lua"),
                          str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-rendering", ["texlua", str(ROOT / "tests/lua/rendering.lua"),
                          str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    run("lua-report", ["texlua", str(ROOT / "tests/lua/report.lua"),
                       str(SOURCE / "luapourbaix.lua")], BUILD / "lua")
    for name, engine in (("plain", "luatex"), ("latex", "lualatex")):
        directory = BUILD / name
        job = "smoke-" + name
        run(job, [engine, "--interaction=nonstopmode", "--halt-on-error",
                  "--no-shell-escape", str(ROOT / "tests/tex" / (job + ".tex"))],
            directory, pdf=job)
    directory = BUILD / "context"
    mtxrun = subprocess.check_output(["kpsewhich", "mtxrun.lua"], text=True).strip()
    context_script = subprocess.check_output(
        ["kpsewhich", "mtx-context.lua"], text=True).strip()
    if not mtxrun or not context_script:
        raise RuntimeError("Cannot locate the ConTeXt runner scripts")
    marker = BUILD / "cache" / ".mkiv-initialized"
    if not marker.exists():
        # Populate MkIV's resolver before asking it to locate mtx-context.lua.
        # The native launcher may otherwise return zero after a cold-cache miss.
        run("context-cache", ["luatex", "--luaonly", mtxrun, "--generate"], directory)
        marker.touch()
    # Select MkIV directly, even when `context` is a LuaMetaTeX launcher.
    run("smoke-context", ["luatex", "--luaonly", mtxrun, "--script", context_script,
                          "--luatex", "--batchmode", "--nonstopmode",
                          "--no-shell-escape", "--path=" + str(SOURCE) + "," + str(ROOT / "tests/tex"),
                          str(ROOT / "tests/tex/smoke-context.tex")], directory,
        pdf="smoke-context")
    log = (directory / "smoke-context.log").read_text(errors="replace")
    if "LuaTeX" not in log or ("luapourbaix " + METADATA["version"] + " loaded") not in log:
        raise RuntimeError("MkIV engine or Lua bridge was not verified")
    run("reject-pdftex", ["pdftex", "--interaction=nonstopmode", "--halt-on-error",
                          "--no-shell-escape", str(ROOT / "tests/tex/reject-pdftex.tex")],
        BUILD / "negative", "luapourbaix requires a LuaTeX-compatible engine")
    run("reject-declaration", ["luatex", "--interaction=nonstopmode", "--halt-on-error",
                              "--no-shell-escape", str(ROOT / "tests/tex/reject-declaration.tex")],
        BUILD / "negative", "boundary convention must explicitly")
    run("reject-temperature", ["luatex", "--interaction=nonstopmode", "--halt-on-error",
                              "--no-shell-escape", str(ROOT / "tests/tex/reject-temperature.tex")],
        BUILD / "negative", "temperature (K)")

    run("reject-thermodynamics", ["luatex", "--interaction=nonstopmode", "--halt-on-error",
                                 "--no-shell-escape", str(ROOT / "tests/tex/reject-thermodynamics.tex")],
        BUILD / "negative", "insufficient thermodynamic data")

def doc():
    directory = BUILD / "manual"
    command = ["lualatex", "--interaction=nonstopmode", "--halt-on-error",
               "--no-shell-escape", str(ROOT / "doc/luapourbaix-manual.tex")]
    run("manual-pass-1", command, directory, pdf="luapourbaix-manual")
    # Settle the contents and cross-references before collecting index pages.
    run("manual-pass-2", command, directory, pdf="luapourbaix-manual")
    run("manual-index", ["makeindex", "luapourbaix-manual.idx"], directory)
    run("manual-pass-3", command, directory, pdf="luapourbaix-manual")
    run("manual-index-final", ["makeindex", "luapourbaix-manual.idx"], directory)
    run("manual-pass-4", command, directory, pdf="luapourbaix-manual")



def clean():
    """Delete only regenerable output below the repository build directory."""
    if BUILD.is_symlink():
        raise RuntimeError("Refusing to clean a symlinked build directory")
    if BUILD.exists():
        shutil.rmtree(BUILD)
    print("Removed build/; source files were not changed.")


def source_members():
    """Explicit distribution allowlist: no git metadata or working notes."""
    members = {}
    for name in ("README.md", "AUTHORS.md", "COPYING.md", "LICENSE", "MANIFEST.md",
                 "CONTRIBUTING.md", "Makefile", "release.json"):
        members[name] = ROOT / name
    ctan_readme = ROOT / "doc/README-CTAN.md"
    if ctan_readme.is_file():
        members["README.md"] = ctan_readme
    for name in ("luapourbaix-manual.tex", "SOURCES.md", "scientific-audit.md", "releasing.md", "announcement.txt"):
        members["doc/" + name] = ROOT / "doc" / name
    members["scripts/dev.py"] = ROOT / "scripts/dev.py"
    members["scripts/ctan.py"] = ROOT / "scripts/ctan.py"
    for path in sorted(SOURCE.iterdir()):
        if path.suffix in (".tex", ".lua"):
            members["tex/" + path.name] = path
    for directory, suffix in (("lua", ".lua"), ("tex", ".tex")):
        for path in sorted((ROOT / "tests" / directory).glob("*" + suffix)):
            members["tests/" + directory + "/" + path.name] = path
    return members


def manifest():
    lines = ["<!-- Copyright 2026 Christophe Jorssen; LPPL-1.3c-or-later. -->",
             "# Distribution manifest", "",
             "The source work consists of the files below, listed by their paths",
             "inside the CTAN archive's `luapourbaix/` directory. In the repository,",
             "the runtime `tex/` entries are under `tex/generic/luapourbaix/`.",
             "The derived documentation is `doc/luapourbaix-manual.pdf`.", "",
             "`LICENSE` retains its own LaTeX3 Project copyright. Local instructions",
             "(`AGENTS.md`, `doc/project-contract.md`) and generated build files are",
             "not part of the distribution. See `COPYING.md` for the license notice.", ""]
    lines.extend("- `" + name + "`" for name in sorted(source_members()))
    (ROOT / "MANIFEST.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Updated MANIFEST.md")


def distribution():
    version = METADATA["version"]
    core = (SOURCE / "luapourbaix.lua").read_text(encoding="utf-8")
    manual = (ROOT / "doc/luapourbaix-manual.tex").read_text(encoding="utf-8")
    if ('version = "' + version + '"') not in core or version not in manual:
        raise RuntimeError("Release, core and manual versions disagree")
    for name in ("README.md", "AUTHORS.md", "doc/luapourbaix-manual.tex"):
        if "ChatGPT 6 Astra" not in (ROOT / name).read_text(encoding="utf-8"):
            raise RuntimeError("Missing AI disclosure in " + name)
    if "LPPL Version 1.3c" not in (ROOT / "LICENSE").read_text(encoding="utf-8"):
        raise RuntimeError("Missing full LPPL 1.3c license")
    members = source_members()
    listed = set(re.findall(r"^- `([^`]+)`$", (ROOT / "MANIFEST.md").read_text(), re.M))
    if listed != set(members):
        raise RuntimeError("Manifest is stale; run make manifest and review it")
    readme = members["README.md"].read_text(encoding="utf-8")
    if "ChatGPT 6 Astra" not in readme or version not in readme:
        raise RuntimeError("CTAN README version or AI disclosure is missing")
    basenames = set()
    for name, path in members.items():
        if path.name.lower() in basenames:
            raise RuntimeError("Duplicate filename: " + name)
        basenames.add(path.name.lower())
        if any(not re.fullmatch(r"[A-Za-z0-9_.-]+", part) or part.startswith(".")
               for part in Path(name).parts):
            raise RuntimeError("Non-portable archive path: " + name)
        if not path.is_file() or path.is_symlink():
            raise RuntimeError("Missing or symlinked distribution source: " + str(path))
        content = path.read_bytes()
        if not content or content.startswith(b"\xef\xbb\xbf") or b"\r" in content:
            raise RuntimeError("Empty, BOM-prefixed or non-LF source: " + name)
    require_pdf(BUILD / "manual", "luapourbaix-manual")
    members["doc/luapourbaix-manual.pdf"] = BUILD / "manual/luapourbaix-manual.pdf"
    destination = BUILD / "dist"
    destination.mkdir(parents=True, exist_ok=True)

    def archive(name, entries):
        path = destination / name
        # Stable entry timestamps/order. PDF byte reproducibility additionally
        # depends on the TeX engine, fonts and SOURCE_DATE_EPOCH used for the build.
        with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as output:
            for target, source in sorted(entries.items()):
                stamp = tuple(int(value) for value in METADATA["date"].split("-"))
                info = zipfile.ZipInfo(target, stamp + (0, 0, 0))
                info.create_system = 3
                info.internal_attr = 0 if source.suffix == ".pdf" else 1
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                output.writestr(info, source.read_bytes())
        with zipfile.ZipFile(path) as output:
            if output.testzip() is not None or set(output.namelist()) != set(entries):
                raise RuntimeError("Archive content check failed: " + name)
            for target, source in entries.items():
                if output.read(target) != source.read_bytes():
                    raise RuntimeError("Archive differs from its verified source: " + target)
        return path

    archives = [archive("luapourbaix.zip", {"luapourbaix/" + k: v for k, v in members.items()})]
    # Retire a stale generated TDS artifact from earlier local builds.
    (destination / "luapourbaix.tds.zip").unlink(missing_ok=True)
    checksums = [hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name for path in archives]
    (destination / "SHA256SUMS").write_text("\n".join(checksums) + "\n", encoding="utf-8")
    fields = {"Package": METADATA["name"], "Version": version, "Date": METADATA["date"],
              "Status": METADATA["status"], "Author and maintainer": METADATA["author"],
              "Email": METADATA["email"], "License": METADATA["license_statement"],
              "CTAN license identifier": METADATA["license"],
              "Suggested CTAN path": METADATA["ctan_path_proposal"],
              "Repository": METADATA["repository"], "Summary": METADATA["summary"],
              "AI disclosure": METADATA["ai_disclosure"]}
    draft = "LOCAL DRAFT ONLY - nothing has been uploaded.\n\n"
    draft += "\n".join(key + ": " + value for key, value in fields.items())
    draft += "\n\nReview the release version/date before an explicitly authorized submission.\n"
    (destination / "ctan-upload.txt").write_text(draft, encoding="utf-8")
    api_fields = {
        "pkg": METADATA["name"], "version": version, "update": "false",
        "author": METADATA["author"], "uploader": METADATA["author"],
        "email": METADATA["email"], "license": METADATA["license"],
        "ctanPath": METADATA["ctan_path_proposal"], "summary": METADATA["summary"],
        "description": METADATA["description"], "repository": METADATA["repository"],
        "announcement": (ROOT / "doc/announcement.txt").read_text(encoding="utf-8"),
        "note": METADATA["ctan_note"],
    }
    (destination / "ctan-fields.json").write_text(json.dumps(api_fields, indent=2) + "\n", encoding="utf-8")
    print("PASS source archive membership, byte identity, license, manifest and metadata")
    print("Local archive: build/dist/luapourbaix.zip (no TDS archive)")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("doctor", "test", "doc", "check", "clean", "manifest", "dist"))
    action = parser.parse_args().action
    if action == "clean":
        clean()
        return
    if action == "manifest":
        manifest()
        return
    (BUILD / "cache").mkdir(parents=True, exist_ok=True)
    if action in ("check", "dist"):
        test()
        doc()
        if action == "dist":
            distribution()
    else:
        {"doctor": doctor, "test": test, "doc": doc}[action]()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
