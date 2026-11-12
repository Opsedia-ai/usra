import subprocess, os, re, sys
S = os.path.dirname(os.path.abspath(__file__))
src = open(f'{S}/after.py', encoding='utf-8').read()
# Reuse the shared head, icons and nav from after.py without re-rendering its screens.
exec(src.split("home = HEAD")[0])
C = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
BACK = '<path d="M5 12h14M13 6l6 6-6 6"/>'
USERS = '<circle cx="9" cy="8" r="3.5"/><path d="M3 20c.8-3.5 3.2-5 6-5s5.2 1.5 6 5"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7"/><path d="M18 15c1.8.5 3 2 3.5 5"/>'
DOCB = '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V4h6v3M12 11v5M9.5 13.5h5"/>'
WALLET = '<rect x="3" y="6" width="18" height="13" rx="2"/><path d="M16 12h2"/>'
CLOUD = '<path d="M7 18a4.5 4.5 0 0 1-.5-9 6 6 0 0 1 11.5 1.5A3.8 3.8 0 0 1 17.5 18z"/>'
LOCK = '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>'
BELL = '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 21h4"/>'
CAM = '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>'
LAB = '<path d="M9 3h6M10 3v6l-5 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-5-9V3"/>'
SCALE = '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M9 9h6"/>'
XRAY = '<path d="M4 8V5h3M17 5h3v3M20 16v3h-3M7 19H4v-3M8 12h8"/>'
CARD = '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M7 10h4M7 14h6"/>'
CUT = '<path d="M5 19L19 5M8 8l8 8"/>'


def toggle(on):
    bg = 'var(--accent)' if on else 'rgba(169,183,203,.3)'
    pos = 'left:3px' if on else 'right:3px'
    return f'<span style="width:46px;height:28px;border-radius:14px;background:{bg};position:relative;flex:none"><span style="position:absolute;top:3px;{pos};width:22px;height:22px;border-radius:50%;background:var(--onaccent)"></span></span>'


def row(icon, title, sub='', right=None, last=False):
    line = '' if last else 'border-bottom:1px solid var(--line);'
    s = f'<div class="muted" style="font-size:14px;line-height:20px">{sub}</div>' if sub else ''
    r = right if right is not None else f'<span class="muted">{ico(CHEV, 18)}</span>'
    return f'<div style="display:flex;align-items:center;gap:12px;min-height:56px;padding:8px 0;{line}"><span class="muted">{ico(icon, 20)}</span><div style="flex:1"><div style="font-size:16px">{title}</div>{s}</div>{r}</div>'


def header(t, back=True, extra=''):
    b = f'<span style="width:40px;height:40px;border-radius:50%;background:var(--surface);display:grid;place-items:center">{ico(BACK, 20)}</span>' if back else ''
    return f'<div style="display:flex;align-items:center;gap:12px">{b}<div class="d" style="flex:1;font-size:26px;font-weight:600">{t}</div>{extra}</div>'


person = HEAD + f'''<div class="page" style="gap:14px">
<div style="display:flex;align-items:center;gap:8px">
 <span style="width:40px;height:40px;border-radius:50%;background:var(--surface);display:grid;place-items:center">{ico(BACK, 20)}</span>
 <span style="flex:1"></span>
 <a class="btn" style="min-height:40px;color:var(--red);border-color:var(--line);background:var(--surface)">{ico(CROSS, 16, 'var(--red)')}طوارئ</a>
 <a class="btn" style="min-height:40px;border-color:var(--line)">تعديل</a>
</div>
<div style="display:flex;align-items:center;gap:14px">
 <span class="d" style="width:68px;height:64px;background:var(--pinkpeb);border-radius:45% 55% 40% 60% / 55% 45% 60% 40%;display:grid;place-items:center;font-size:28px;font-weight:600">ج</span>
 <div><div class="d" style="font-size:28px;font-weight:600;line-height:36px">جميلة</div><div class="muted">سنتين · بنتك</div></div>
</div>
<div class="card" style="padding:4px 16px">
 <div style="display:flex;align-items:center;gap:12px;min-height:56px;border-bottom:1px solid var(--line)"><span class="dot" style="background:var(--amber)"></span><div style="flex:1"><div style="font-size:16px;font-weight:600">تعبانة من النهارده</div><div class="muted" style="font-size:14px">مفيش قراءات حرارة لسه</div></div><a class="btn" style="min-height:40px">قراءة</a></div>
 <div style="display:flex;align-items:center;gap:12px;min-height:56px"><span class="dot" style="background:var(--amber)"></span><div style="flex:1"><div style="font-size:16px;font-weight:600">١٨ جرعة تطعيم ناقصة</div><div class="muted" style="font-size:14px">٧ ممكن تتاخد دلوقتي · جدول وزارة الصحة</div></div><span class="muted">{ico(CHEV, 18)}</span></div>
</div>
<div class="card" style="padding:4px 16px">
 {row(SYR, 'التطعيمات', '٠ من ١٨ · جدول مصر')}
 {row(SCALE, 'النمو', '١١٫٥ كجم · ١٢ نوفمبر')}
 {row(DOCB, 'الزيارات والتحاليل', 'لسه مفيش')}
 {row(CARD, 'التأمين', 'لسه مفيش', last=True)}
</div>
<div style="position:absolute;left:20px;right:20px;bottom:24px;display:flex;gap:10px">
 <a class="btn primary" style="flex:1.4">{ico(PLUS_I, 20)}إضافة لجميلة</a>
 <a class="btn" style="flex:1">ملخص للدكتور</a>
</div>
</div></body></html>'''


def dose(name, when, last=False):
    line = '' if last else 'border-bottom:1px solid var(--line);'
    return f'<div style="display:flex;align-items:center;gap:12px;min-height:60px;{line}"><span class="dot" style="background:var(--amber)"></span><div style="flex:1"><div style="font-size:16px">{name}</div><div class="muted" style="font-size:14px">{when}</div></div><a style="color:var(--accent);font-size:15px;font-weight:500;padding:10px 4px">تسجيل</a></div>'


vaccines = HEAD + f'''<div class="page" style="gap:14px">
{header('تطعيمات جميلة', extra=f'<span class="muted">{ico(DOC_I, 22)}</span>')}
<div class="card" style="display:flex;flex-direction:column;gap:10px">
 <div style="display:flex;justify-content:space-between;align-items:baseline"><span style="font-size:16px;font-weight:600">٠ من ١٨ جرعة إجباري اتاخدت</span></div>
 <div style="height:6px;border-radius:3px;background:var(--raised)"></div>
 <div class="muted" style="font-size:13px">جدول وزارة الصحة والسكان، مصر · اتراجع ٤ نوفمبر ٢٠٢٦</div>
 <a class="btn" style="margin-top:4px">{ico('<path d="M5 12l5 5 9-10"/>', 18)}خدت كل اللي فات؟ علّمها مرة واحدة</a>
</div>
<div style="font-size:15px;font-weight:600;color:var(--amber);display:flex;align-items:center;gap:8px"><span class="dot" style="background:var(--amber)"></span>ممكن تتاخد دلوقتي · ٧</div>
<div class="card" style="padding:0 16px">
 {dose('الالتهاب الكبدي ب، الجرعة الصفرية', 'كان ميعادها عند الولادة')}
 {dose('الدرن (BCG)، جرعة ١', 'كان ميعادها عند الولادة')}
 {dose('شلل الأطفال بالفم، الجرعة الصفرية', 'كان ميعادها عند الولادة')}
 {dose('الخماسي، جرعة ١', 'كان ميعادها عند شهرين', True)}
</div>
<div class="muted" style="font-size:14px">و٣ كمان · بعدها ١١ جرعة بالترتيب</div>
</div>{nav('الرئيسية')}</body></html>'''

more = HEAD + f'''<div class="page" style="gap:12px">
<div class="d" style="font-size:28px;font-weight:600">المزيد</div>
<div class="muted" style="font-size:14px;margin-top:4px">العيلة</div>
<div class="card" style="padding:0 16px">{row(USERS, 'كل العيلة', '٢ أفراد')}{row(DOCB, 'الدكاترة')}{row(WALLET, 'المصاريف', last=True)}</div>
<div class="muted" style="font-size:14px;margin-top:4px">الأمان</div>
<div class="card" style="padding:0 16px">
 {row(CLOUD, 'النسخة الاحتياطية', '<span style="color:var(--amber)">● لسه مفيش نسخة</span>')}
 {row(LOCK, 'قفل التطبيق', 'مش شغّال')}
 {row(BELL, 'تنبيهات من غير أسامي', 'التنبيه يقول "ميعاد الدوا" بس', toggle(True), last=True)}
</div>
<div class="muted" style="font-size:14px;margin-top:4px">التطبيق</div>
<div class="card" style="padding:0 16px">{row(HOME_I, 'الوضع البسيط', 'مش شغّال')}{row(MENU_I, 'اللغة والبلد', 'العربية · مصر', last=True)}</div>
</div>{nav('المزيد')}</body></html>'''


def tile(icon, t):
    return f'<div style="background:var(--surface);outline:1px solid var(--line);outline-offset:-1px;border-radius:14px;min-height:76px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;font-size:15px"><span class="muted">{ico(icon, 22)}</span>{t}</div>'


add = HEAD + f'''<div style="position:absolute;inset:0;background:rgba(5,10,20,.55)"></div>
<div style="position:absolute;left:0;right:0;bottom:0;top:210px;background:var(--surface);border-radius:20px 20px 0 0;padding:12px 20px;display:flex;flex-direction:column;gap:14px">
 <span style="align-self:center;width:36px;height:4px;border-radius:2px;background:rgba(169,183,203,.4)"></span>
 <div class="d" style="font-size:24px;font-weight:600">هنضيف إيه؟</div>
 <div style="display:flex;align-items:center;gap:8px"><span class="muted" style="font-size:15px">لمين؟</span>
  <span class="chip" style="min-height:40px;padding:0 16px;border:1px solid rgba(169,183,203,.35);font-size:15px">آية</span>
  <span class="chip" style="min-height:40px;padding:0 16px;background:var(--accent);color:var(--onaccent);font-size:15px">جميلة</span></div>
 <div style="background:var(--raised);border-radius:14px;padding:14px;display:flex;flex-direction:column;gap:10px">
  <div style="display:flex;gap:10px;align-items:center"><span class="muted">{ico(CAM, 22)}</span><div><div style="font-size:16px;font-weight:600">صوّر روشتة أو علبة دوا</div><div class="muted" style="font-size:13px">بنقرا الكلام المطبوع بالإنجليزي، والتأكيد عليك</div></div></div>
  <div style="display:flex;gap:8px"><a class="btn primary" style="flex:1;min-height:44px">روشتة</a><a class="btn" style="flex:1;min-height:44px">علبة دوا</a></div>
 </div>
 <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px">
  {tile(PILL_I, 'دوا')}{tile(SYR, 'تطعيم')}{tile(DOCB, 'زيارة')}{tile(LAB, 'تحليل')}
  {tile(XRAY, 'أشعة')}{tile(THERM, 'سخونية')}{tile(SCALE, 'وزن وطول')}{tile(CUT, 'عملية')}
 </div>
 <div class="muted" style="font-size:14px;display:flex;align-items:center;gap:8px">{ico(CARD, 18)}كارت تأمين</div>
</div></body></html>'''

for name, html in [('after-person', person), ('after-vaccines', vaccines), ('after-more', more), ('after-add', add)]:
    p = f'{S}/{name}.html'
    open(p, 'w', encoding='utf-8').write(html)
    subprocess.run([C, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=3', '--window-size=500,874', '--virtual-time-budget=5000', f'--screenshot={S}/{name}.full.png', f'file://{p}'], capture_output=True)
    subprocess.run(['sips', '-c', '2622', '1206', f'{S}/{name}.full.png', '--out', f'{S}/{name}.png'], capture_output=True)

pairs = [('Person page', 'person'), ('Vaccines', 'vaccines'), ('More', 'more'), ('Add sheet', 'add')]
cmp = '<!doctype html><body style="margin:0;background:#E9E7EC;padding:24px;font-family:system-ui;width:1760px"><div style="display:grid;grid-template-columns:repeat(2,860px);gap:40px">'
for t, n in pairs:
    cmp += f'<div style="display:flex;gap:20px"><figure style="margin:0"><figcaption style="font:600 20px system-ui;color:#56637A;margin-bottom:8px">{t}: now</figcaption><img src="before-{n}.png" style="width:390px;border-radius:24px"></figure><figure style="margin:0"><figcaption style="font:600 20px system-ui;color:#14532D;margin-bottom:8px">{t}: polished sample</figcaption><img src="after-{n}.png" style="width:390px;border-radius:24px"></figure></div>'
open(f'{S}/compare-app2.html', 'w').write(cmp + '</div></body>')
subprocess.run([C, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--window-size=1808,1840', '--virtual-time-budget=3000', f'--screenshot={S}/compare-app2.png', f'file://{S}/compare-app2.html'], capture_output=True)
print(os.path.exists(f'{S}/compare-app2.png'))
