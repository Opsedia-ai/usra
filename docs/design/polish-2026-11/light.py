import re, os
S = os.path.dirname(os.path.abspath(__file__))
DARK_ROOT = re.search(r':root\{[^}]*\}', open(f'{S}/after.py').read()).group(0)
LIGHT_ROOT = ':root{--bg:#F4F5F9;--surface:#FFFFFF;--raised:#EEF2F8;--line:rgba(20,38,61,.10);--text:#14263D;--muted:#55657A;--accent:#24405F;--onaccent:#FFFFFF;--amber:#9A6200;--red:#B42318;--pinkpeb:#E8CBD8;--bluepeb:#D3E0F0}'
SUBS = [(DARK_ROOT, LIGHT_ROOT),
        ('rgba(169,183,203,', 'rgba(85,101,122,'),
        ('rgba(234,240,247,', 'rgba(20,38,61,'),
        ('rgba(226,174,85,.14)', 'rgba(212,154,42,.16)'), ('rgba(226,174,85,.12)', 'rgba(212,154,42,.14)'),
        ('rgba(240,138,138,.5)', 'rgba(180,35,24,.4)'),
        ('rgba(5,10,20,.55)', 'rgba(20,24,32,.45)'),
        ('#E2AE55', '#D49A2A')]
def lighten(src):
    for a, b in SUBS: src = src.replace(a, b)
    src = src.replace("'after-", "'light-after-").replace('"after-', '"light-after-').replace('after-{n}', 'light-after-{n}').replace('before-{n}', 'light-before-{n}')
    src = src.replace('compare-app2', 'light-compare2').replace('compare-app', 'light-compare1')
    for t in ('home', 'sicklist'):
        src = src.replace(f"'before-{t}.png'", f"'light-before-{t}.png'")
    return src
a = lighten(open(f'{S}/after.py').read())
open(f'{S}/light_after.py', 'w').write(a)
b = lighten(open(f'{S}/after2.py').read()).replace("after.py", "light_after.py")
open(f'{S}/light_after2.py', 'w').write(b)
