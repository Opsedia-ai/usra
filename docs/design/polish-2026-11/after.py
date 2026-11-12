import subprocess, os
S = os.path.dirname(os.path.abspath(__file__))
C = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

HEAD = '''<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Baloo+Bhaijaan+2:wght@500;600&family=IBM+Plex+Sans+Arabic:wght@400;500;600&display=swap">
<style>
:root{--bg:#0C1A2E;--surface:#13233A;--raised:#182B45;--line:rgba(234,240,247,.08);--text:#EAF0F7;--muted:#A9B7CB;--accent:#83A6CE;--onaccent:#0B1B32;--amber:#E2AE55;--red:#F08A8A;--pinkpeb:#4A3550;--bluepeb:#243B5C}
*{box-sizing:border-box}html{margin:0;background:var(--bg);display:flex;justify-content:center}
body{width:402px;height:874px;position:relative;overflow:hidden;color:var(--text);font-family:'IBM Plex Sans Arabic',sans-serif}
.d{font-family:'Baloo Bhaijaan 2','IBM Plex Sans Arabic',sans-serif}
.page{padding:64px 20px 0;display:flex;flex-direction:column;gap:16px}
.card{background:var(--surface);border-radius:16px;outline:1px solid var(--line);outline-offset:-1px;padding:16px}
.muted{color:var(--muted)}
.btn{display:flex;align-items:center;justify-content:center;gap:8px;min-height:48px;border-radius:14px;font-size:16px;font-weight:500;border:1px solid rgba(169,183,203,.35);color:var(--text);background:transparent;padding:0 16px}
.primary{background:var(--accent);color:var(--onaccent);border:0;font-weight:600}
.chip{display:inline-flex;align-items:center;gap:6px;min-height:28px;padding:0 10px;border-radius:999px;font-size:14px;font-weight:500}
.dot{width:8px;height:8px;border-radius:50%;display:inline-block;flex:none}
nav{position:absolute;left:0;right:0;bottom:0;height:96px;background:var(--surface);border-top:1px solid var(--line);display:flex;align-items:flex-start;justify-content:space-around;padding-top:10px}
nav a{display:flex;flex-direction:column;align-items:center;gap:4px;font-size:13px;color:var(--muted);text-decoration:none;width:64px}
nav .on{color:var(--accent)}
nav .add{margin-top:-30px}
nav .add span.c{width:56px;height:56px;border-radius:50%;background:var(--accent);color:var(--onaccent);display:grid;place-items:center}
svg{flex:none}
</style></head><body>'''


def ico(path, s=20, c='currentColor', w=1.8):
    return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="{c}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round">{path}</svg>'


HOME_I = '<path d="M4 11l8-7 8 7"/><path d="M6 10v9h12v-9"/>'
PILL_I = '<path d="M10.5 3.5a5 5 0 0 1 7 7l-7 7a5 5 0 0 1-7-7z"/><path d="M7 7l7 7"/>'
DOC_I = '<path d="M7 3h7l4 4v14H6V3z"/><path d="M9 12h6M9 16h6"/>'
MENU_I = '<path d="M4 7h16M4 12h16M4 17h16"/>'
PLUS_I = '<path d="M12 5v14M5 12h14"/>'
CHEV = '<path d="M15 6l-6 6 6 6"/>'
PHONE = '<path d="M6 3h3l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v3a3 3 0 0 1-3 3A15 15 0 0 1 3 6a3 3 0 0 1 3-3z"/>'
CROSS = '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M12 8v8M8 12h8"/>'
THERM = '<path d="M14 4v10.5a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0z"/>'
SHIELD = '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>'
SYR = '<path d="M14 4l6 6"/><path d="M17 7L8 16l-3 3"/><path d="M12 7l5 5"/>'


def nav(active):
    items = [('الرئيسية', HOME_I), ('الأدوية', PILL_I), None, ('السجلات', DOC_I), ('المزيد', MENU_I)]
    out = '<nav>'
    for it in items:
        if it is None:
            out += f'<a class="add"><span class="c">{ico(PLUS_I, 26, w=2.2)}</span><span style="color:var(--text)">إضافة</span></a>'
            continue
        out += f'<a class="{"on" if it[0] == active else ""}">{ico(it[1], 22)}<span>{it[0]}</span></a>'
    return out + '</nav>'


def peb(name, status, bg, shape, top=0):
    return f'<div style="flex:1;height:112px;margin-top:{top}px;background:{bg};border-radius:{shape};display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px"><span class="d" style="font-size:22px;font-weight:600">{name}</span>{status}</div>'


home = HEAD + f'''<div class="page">
<div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px">
 <div><div class="d" style="font-size:28px;line-height:38px;font-weight:600">مساء الخير يا آية</div>
 <div class="muted" style="font-size:16px;line-height:24px"><span style="color:var(--text);text-decoration:underline;text-underline-offset:4px">جميلة</span> محتاجة انتباهك</div></div>
 <a class="btn" style="color:var(--red);min-height:44px;padding:0 14px;background:var(--surface);border:1px solid var(--line)">{ico(CROSS, 18, 'var(--red)')}طوارئ</a>
</div>
<div style="display:flex;gap:12px">
 {peb('آية', '<span class="muted" style="font-size:14px">مفيش حاجة مطلوبة</span>', 'var(--pinkpeb)', '58% 42% 55% 45% / 48% 58% 42% 52%')}
 {peb('جميلة', '<span class="chip" style="background:rgba(226,174,85,.14);color:var(--amber)">' + ico(THERM, 16, 'var(--amber)') + 'تعبانة</span>', 'var(--pinkpeb)', '45% 55% 40% 60% / 55% 45% 60% 40%', 18)}
</div>
<a class="btn" style="align-self:center;border-style:dashed;min-height:44px">{ico(PLUS_I, 18)}فرد جديد</a>
<div class="card" style="display:flex;gap:12px;align-items:flex-start">
 <span style="width:36px;height:36px;border-radius:10px;background:var(--raised);display:grid;place-items:center;color:var(--muted)">{ico(SHIELD, 20)}</span>
 <div style="flex:1;display:flex;flex-direction:column;gap:4px">
  <div style="font-size:16px;font-weight:600;display:flex;align-items:center;gap:8px"><span class="dot" style="background:var(--amber)"></span>لسه مفيش نسخة احتياطية</div>
  <div class="muted" style="font-size:14px;line-height:22px">لو الموبايل ضاع، السجلات بتضيع معاه. النسخة متشفرة وبتتحفظ برّه الموبايل</div>
  <a class="btn" style="align-self:flex-start;min-height:44px;margin-top:8px">نسخة احتياطية دلوقتي</a>
 </div>
</div>
<div class="card" style="display:flex;gap:12px;align-items:center">
 <span style="width:36px;height:36px;border-radius:10px;background:var(--raised);display:grid;place-items:center;color:var(--muted)">{ico(SYR, 20)}</span>
 <div style="flex:1"><div style="font-size:16px;font-weight:600">تطعيمات جميلة</div>
 <div style="font-size:14px;color:var(--amber);display:flex;align-items:center;gap:6px"><span class="dot" style="background:var(--amber)"></span>١٨ جرعة ناقصة · ٧ ممكن تتاخد دلوقتي</div></div>
 <span class="muted">{ico(CHEV, 20)}</span>
</div>
</div>{nav('الرئيسية')}</body></html>'''

sick = HEAD + f'''<div class="page">
<div style="display:flex;align-items:center;gap:12px">
 <span style="width:44px;height:44px;border-radius:50%;background:var(--surface);display:grid;place-items:center">{ico('<path d="M5 12h14M13 6l6 6-6 6"/>', 20)}</span>
 <div class="d" style="font-size:26px;font-weight:600">الحرارة والتعب · جميلة</div>
</div>
<div class="card" style="display:flex;gap:12px;align-items:center">
 <span style="width:36px;height:36px;border-radius:10px;background:rgba(226,174,85,.12);display:grid;place-items:center;color:var(--amber)">{ico(THERM, 20, 'var(--amber)')}</span>
 <div style="flex:1"><div style="font-size:16px;font-weight:600">لسه تعبانة</div><div class="muted" style="font-size:14px">من ١٢ نوفمبر · مفيش قراءات لسه</div></div>
 <span class="muted">{ico(CHEV, 20)}</span>
</div>
<a class="btn primary">{ico(PLUS_I, 20)}قراءة حرارة</a>
<div class="card" style="display:flex;flex-direction:column;gap:10px">
 <div style="font-size:16px;font-weight:600;color:var(--red)">اطلب الإسعاف فورًا لو ظهر</div>
 <div class="muted" style="font-size:15px;line-height:24px">صعوبة في النفس · تشنج · طفح مش بيختفي بالضغط · نعسانة جدًا وصعب تصحى</div>
 <a class="btn" style="border-color:rgba(240,138,138,.5);color:var(--red)">{ico(PHONE, 18, 'var(--red)')}اتصال بالإسعاف ١٢٣</a>
 <a class="muted" style="font-size:14px;display:flex;align-items:center;gap:4px">كل العلامات وإمتى نكلم الدكتور {ico(CHEV, 16)}</a>
</div>
<div class="muted" style="font-size:14px;text-align:center">أيام التعب اللي فاتت هتظهر هنا</div>
</div>{nav('الرئيسية')}</body></html>'''

for name, html in [('after-home', home), ('after-sicklist', sick)]:
    p = f'{S}/{name}.html'
    open(p, 'w', encoding='utf-8').write(html)
    subprocess.run([C, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=3', '--window-size=500,874', '--virtual-time-budget=5000', f'--screenshot={S}/{name}.full.png', f'file://{p}'], capture_output=True)
    subprocess.run(['sips', '-c', '2622', '1206', f'{S}/{name}.full.png', '--out', f'{S}/{name}.png'], capture_output=True)

cmp = '''<!doctype html><body style="margin:0;background:#E9E7EC;padding:24px;font-family:system-ui;width:1760px">
<div style="display:flex;gap:56px">'''
for title, b, a in [('Home', 'before-home.png', 'after-home.png'), ('Sick days', 'before-sicklist.png', 'after-sicklist.png')]:
    cmp += f'''<div style="display:flex;gap:20px;align-items:flex-start">
<figure style="margin:0"><figcaption style="font:600 20px system-ui;color:#56637A;margin-bottom:8px">{title}: now</figcaption><img src="{b}" style="width:390px;border-radius:24px"></figure>
<figure style="margin:0"><figcaption style="font:600 20px system-ui;color:#14532D;margin-bottom:8px">{title}: polished sample</figcaption><img src="{a}" style="width:390px;border-radius:24px"></figure></div>'''
cmp += '</div></body>'
open(f'{S}/compare-app.html', 'w').write(cmp)
subprocess.run([C, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--window-size=1808,920', '--virtual-time-budget=3000', f'--screenshot={S}/compare-app.png', f'file://{S}/compare-app.html'], capture_output=True)
print(os.path.exists(f'{S}/compare-app.png'))
