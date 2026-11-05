# Splits a BSD ar archive into numbered member files, keeping members whose
# names repeat (`ar -x` would overwrite them). Used by mlkit_simulator.sh.
#
#   python3 -I ar_split.py LIBRARY.a OUT_DIR
import os
import sys

data = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
assert data[:8] == b'!<arch>\n', 'not an ar archive'
i, n = 8, 0
while i < len(data):
    header = data[i:i + 60]
    name = header[:16].decode().strip()
    size = int(header[48:58])
    i += 60
    body = data[i:i + size]
    if name.startswith('#1/'):  # BSD long name, stored before the data
        k = int(name[3:])
        name = body[:k].rstrip(b'\0').decode()
        body = body[k:]
    i += size + (size % 2)
    if name.startswith('__.SYMDEF'):
        continue
    with open(os.path.join(out, '%04d_%s' % (n, os.path.basename(name))), 'wb') as f:
        f.write(body)
    n += 1
print(n)
