#!/usr/bin/env python3
"""Pack a trained profile for the lock: pack-profile.py GCDA_DIR OUT.tar.gz

GCDA_DIR holds the flat .gcda files an instrumented core wrote (their names are
the mangled object paths under /tmp/pgo). The archive is byte-stable: sorted
names, zero times and owners, gzip without a name or time, so the same profile
always gives the same sha256 for the lock's pgo.profile_sha256.
"""
import gzip
import hashlib
import io
import os
import sys
import tarfile

src, dst = sys.argv[1], sys.argv[2]
names = sorted(n for n in os.listdir(src) if n.endswith('.gcda'))
if not names:
    sys.exit(f'no .gcda files in {src}')
buf = io.BytesIO()
with tarfile.open(fileobj=buf, mode='w', format=tarfile.GNU_FORMAT) as tar:
    for name in names:
        data = open(os.path.join(src, name), 'rb').read()
        info = tarfile.TarInfo(name)
        info.size, info.mtime, info.mode = len(data), 0, 0o644
        info.uid = info.gid = 0
        info.uname = info.gname = ''
        tar.addfile(info, io.BytesIO(data))
with open(dst, 'wb') as out:
    with gzip.GzipFile(filename='', mode='wb', fileobj=out, mtime=0, compresslevel=9) as gz:
        gz.write(buf.getvalue())
print(f'{len(names)} files, sha256 {hashlib.sha256(open(dst, "rb").read()).hexdigest()}')
