#!/usr/bin/env python3
"""يصيّر إعلانات سفرتي (9:16) لكل دور: عنوان على لوحة ← ٣ خطوات تظهر تباعاً ← بطاقة ختام. يعمل على GitHub Actions (promo.yml)."""
import json, pathlib, subprocess, html
from playwright.sync_api import sync_playwright
H = pathlib.Path(__file__).parent.resolve(); OUT = H / 'out'; OUT.mkdir(exist_ok=True); W = H / 'work'; W.mkdir(exist_ok=True)
T = json.load(open(H / 'texts.json', encoding='utf-8'))
# لكل دور: أيقونة الخطوة، ومرئي الخطوة: لقطة حقيقية من التطبيق (img) أو بطاقة بنمط التطبيق (mock)
CP = {'restaurant_menu': 0xe533, 'fact_check': 0xe256, 'share': 0xe593, 'send': 0xe571, 'notifications_active': 0xe450, 'check_circle': 0xe159, 'person_add': 0xe492, 'calendar_month': 0xf06bb, 'shopping_cart': 0xe59c, 'alarm': 0xe072}
def ic(n): return f'&#{CP[n]};'
ICONS = {'owner': ['restaurant_menu', 'fact_check', 'share'], 'cook': ['send', 'notifications_active', 'check_circle'], 'partner': ['person_add', 'calendar_month', 'shopping_cart']}
VIS = {'owner': [('img', '3_result.png'), ('img', '6_week.png'), ('img', '5_shopping.png')],
       'cook': [('mock', 'invite'), ('mock', 'notify'), ('mock', 'done')],
       'partner': [('mock', 'code'), ('img', '4_today.png'), ('img', '5_shopping.png')]}
MOCK = {
 'invite': '<div class="bub">دعوة للانضمام إلى بيتي في تطبيق سفرتي بدور الطاهي.<br>افتح الرابط وسجّل دخولك فتنضم مباشرة<small>↓ شاهد الشرح القصير بلغتك</small></div><div class="bub" style="background:#fff">Watch this short video (30 seconds)</div>',
 'notify': '<div class="nt"><div class="c"><span class="mi">&#58448;</span></div><div><b>العشاء · بعد 45 دقيقة</b><span>سمك مشوي مع أرز وخضار</span></div></div><div class="nt" style="background:#c9d8d0"><div class="c" style="background:#1f5a44"><span class="mi">&#57458;</span></div><div><b>حان موعد العشاء · 8:00 م</b><span>سمك مشوي مع أرز وخضار</span></div></div>',
 'done': '<div class="done"><div class="m">العشاء · 8:00 م</div><div class="go">حُضّرت ✓</div></div><div class="toast">وصل مدير البيت: الوجبة جاهزة</div>',
 'code': '<div class="bub" style="text-align:center;font-size:64px;letter-spacing:12px;font-weight:900;background:#fff">K7M2QX</div><div class="bub">رمز الدعوة يعمل مرة واحدة · ينتهي بعد 7 أيام<small>أرسله بواتساب أو انسخه</small></div>',
}
E = html.escape
def dur(f): return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(f)], capture_output=True, text=True).stdout)
CSS = """
@font-face{font-family:T;src:url(fonts/Tajawal-Regular.ttf);font-weight:400}@font-face{font-family:T;src:url(fonts/Tajawal-Bold.ttf);font-weight:700}
@font-face{font-family:T;src:url(fonts/Tajawal-ExtraBold.ttf);font-weight:800}@font-face{font-family:T;src:url(fonts/Tajawal-Black.ttf);font-weight:900}
@font-face{font-family:MI;src:url(fonts/MaterialIcons-Regular.otf)}
.mi{font-family:MI;font-feature-settings:'liga';font-style:normal;font-weight:400;line-height:1;direction:ltr;display:inline-block}
html{width:1080px;height:1920px;overflow:hidden}*{box-sizing:border-box;margin:0}body{width:1080px;height:1920px;font-family:T,sans-serif;direction:rtl;color:#fff;background:linear-gradient(170deg,#2b7a5d,#123528 70%);position:relative;overflow:hidden}
.logo{position:absolute;top:70px;left:70px;display:flex;align-items:center;gap:16px;font-weight:900;font-size:44px}.logo img{width:84px;height:84px}
.title{position:absolute;top:210px;left:70px;right:70px;background:#faf4e6;color:#1f5a44;border-radius:56px;padding:46px 56px;text-align:center;font-weight:900;font-size:82px;line-height:1.3;box-shadow:0 24px 70px #0005}
.steps{position:absolute;top:520px;left:70px;right:70px;display:flex;flex-direction:column;gap:22px}
.step{display:flex;align-items:center;gap:26px;background:#fff;color:#1f2937;border-radius:40px;padding:26px 34px;box-shadow:0 14px 40px #0004;font-weight:800;font-size:50px;line-height:1.35;opacity:.55;transform:scale(.97)}.step.now{opacity:1;transform:none;outline:6px solid #bf8630}.step .ic{margin-inline-start:auto;font-size:76px;color:#1f5a44;width:76px;height:76px;overflow:hidden;white-space:nowrap}
.step i{flex:none;width:92px;height:92px;border-radius:50%;background:#bf8630;color:#fff;display:grid;place-items:center;font-style:normal;font-weight:900;font-size:54px}
.vis{position:absolute;top:1150px;left:150px;right:150px;height:700px;border-radius:56px;overflow:hidden;background:#fff;box-shadow:0 30px 90px #000a;border:10px solid #fff}.vis img{width:100%;height:100%;object-fit:cover;object-position:top}
.mock{position:absolute;top:1150px;left:110px;right:110px;height:700px;display:flex;flex-direction:column;justify-content:center;gap:26px;color:#1f2937}
.bub{background:#dcf8c6;border-radius:34px;padding:34px;font-size:42px;line-height:1.6;box-shadow:0 14px 40px #0004}.bub small{display:block;color:#2a7a5d;font-weight:800;margin-top:10px;font-size:36px}
.nt{display:flex;align-items:center;gap:26px;background:#fff;border-radius:38px;padding:30px;box-shadow:0 14px 40px #0004}.nt .c{flex:none;width:96px;height:96px;border-radius:50%;background:#bf8630;color:#fff;display:grid;place-items:center;font-size:64px}.nt .c .mi{color:#fff;font-size:64px}.nt b{font-size:46px;display:block}.nt span{font-size:38px;color:#4b5563}
.done{background:#fff;border-radius:40px;padding:36px;box-shadow:0 14px 40px #0004}.done .m{font-weight:900;font-size:52px;color:#1f2937}.done .go{margin-top:26px;border-radius:30px;background:#1f5a44;color:#fff;text-align:center;padding:30px;font-weight:900;font-size:56px}.toast{background:#faf4e6;color:#1f5a44;border-radius:60px;padding:28px 36px;font-weight:900;font-size:44px;text-align:center}
.end{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:50px;text-align:center;padding:0 80px}
.end img{width:300px;height:300px}.end h1{font-size:120px;font-weight:900}.end p{font-size:64px;font-weight:800;line-height:1.5}
.badges{display:flex;gap:36px;margin-top:20px}.badge{background:#fff;color:#1f5a44;border-radius:36px;padding:30px 44px;font-weight:900;font-size:46px;line-height:1.3}.badge small{display:block;font-size:34px;color:#bf8630}
"""
def page(role, n):
    d = T[role]
    logo = '<div class="logo"><img src="logo.svg"><span>سفرتي</span></div>'
    if n == 4:
        body = f'<div class="end"><img src="logo.svg"><h1>سفرتي</h1><p>{E(d["close"][0])}</p><div class="badges"><div class="badge">Google Play<small>قريباً</small></div><div class="badge">App Store<small>قريباً</small></div></div></div>'
    else:
        steps = ''.join(f'<div class="step{" now" if k == n - 1 else ""}"><i>{k + 1}</i><span>{E(d["steps"][k][0])}</span><span class="ic mi">{ic(ICONS[role][k])}</span></div>' for k in range(n))
        vis = ''
        if n >= 1:
            kind, v = VIS[role][n - 1]
            vis = f'<div class="vis"><img src="shots/{v}"></div>' if kind == 'img' else f'<div class="mock">{MOCK[v]}</div>'
        body = f'{logo}<div class="title">{E(d["title"][0])}</div><div class="steps">{steps}</div>{vis}'
    return f'<!doctype html><meta charset=utf-8><style>{CSS}</style>{body}'
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1080, 'height': 1920})
    for role in T:
        segs = ['t', '1', '2', '3', 'c']; clips = []
        for n, s in enumerate(segs):
            f = H / f'_{role}_{n}.html'; f.write_text(page(role, n), encoding='utf-8')
            pg.goto(f'file://{f}'); pg.evaluate('document.fonts.ready'); pg.wait_for_timeout(1200); png = W / f'{role}_{n}.png'; pg.screenshot(path=str(png))
            a = H / 'audio' / f'{role}_{s}.mp3'; d = dur(a) + (1.4 if s == 'c' else 0.7); c = W / f'{role}_{n}.mp4'
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-loop', '1', '-i', str(png), '-i', str(a), '-af', f'adelay=350|350,apad=whole_dur={d:.2f}',
                            '-vf', 'scale=1080:1920,fade=t=in:st=0:d=0.35,format=yuv420p', '-t', f'{d:.2f}', '-r', '30', '-c:v', 'libx264', '-crf', '21', '-c:a', 'aac', '-b:a', '160k', str(c)], check=True)
            clips.append(c)
        lst = W / f'{role}.txt'; lst.write_text(''.join(f"file '{c}'\n" for c in clips))
        o = OUT / f'sufrati_promo_{role}.mp4'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(lst), '-c', 'copy', str(o)], check=True)
        print(role, round(dur(o), 1), 's')
    b.close()
