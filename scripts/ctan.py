#!/usr/bin/env python3
# Copyright 2026 Christophe Jorssen; LPPL-1.3c-or-later.
"""Check a prepared CTAN request locally, or explicitly validate/submit via curl.

Default action is offline. Network actions send the archive and its metadata.
See doc/releasing.md for the publication sequence and required authorization.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / 'build/dist'
LIMITS = {'pkg':32, 'version':32, 'update':8, 'author':128, 'uploader':255,
          'email':255, 'license':2048, 'ctanPath':255, 'summary':128,
          'description':4096, 'repository':255, 'announcement':8192, 'note':2048}
REQUIRED = {'pkg', 'version', 'update', 'author', 'uploader', 'email',
            'ctanPath', 'summary', 'description'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', nargs='?', choices=('check', 'validate', 'upload'), default='check')
    parser.add_argument('--confirm-publication', action='store_true',
                        help='required only for an explicitly authorized CTAN upload')
    args = parser.parse_args()
    fields = json.loads((DIST / 'ctan-fields.json').read_text())
    for key in REQUIRED:
        if not fields.get(key):
            parser.error('Missing field: '+key)
    for key, value in fields.items():
        if key not in LIMITS or not isinstance(value, str) or len(value)>LIMITS[key]:
            parser.error('Invalid or oversized field: '+key)
    archive = DIST / 'luapourbaix.zip'
    expected = (DIST / 'SHA256SUMS').read_text().split()[0]
    if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
        parser.error('Archive checksum mismatch; rebuild the distribution')
    with zipfile.ZipFile(archive) as z:
        if z.testzip() or any(not n.startswith('luapourbaix/') or n.endswith('.zip') for n in z.namelist()):
            parser.error('Invalid source archive or nested ZIP')
    print('PASS local CTAN fields and archive checksum', flush=True)
    if args.action == 'check':
        return
    if args.action == 'upload' and not args.confirm_publication:
        parser.error('Publication needs explicit authorization and --confirm-publication')
    # An argument vector preserves newlines without shell expansion. Metadata
    # uses --form-string so leading @ signs cannot become local file reads.
    command = ['curl', '--silent', '--show-error', '--max-time', '120',
               '--output', str(DIST / ('ctan-'+args.action+'-response.json')),
               '--write-out', '%{http_code}']
    for key, value in fields.items():
        command.extend(['--form-string', key+'='+value])
    command.extend(['--form', 'file=@'+str(archive)+';type=application/zip',
                    'https://www.ctan.org/submit/'+args.action])
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    response = (DIST / ('ctan-'+args.action+'-response.json')).read_text()
    print(response)
    if result.stdout.strip() != '200':
        raise SystemExit('CTAN returned HTTP '+result.stdout.strip())
    print('Review every CTAN warning; validation is not acceptance or publication.')

if __name__ == '__main__':
    main()
