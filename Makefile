# Copyright 2026 Christophe Jorssen <christophe.jorssen@gmail.com>.
# This file is part of luapourbaix.
# Distributed under the LPPL 1.3c or, at your option, any later version.
# Maintained by Christophe Jorssen. See COPYING.md, LICENSE and MANIFEST.md.

.PHONY: all doctor test doc check clean manifest dist
all: check
doctor test doc check clean manifest dist:
	python3 scripts/dev.py $@
