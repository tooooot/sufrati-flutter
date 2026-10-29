#!/usr/bin/env python3
"""يصيّر إعلانات سفرتي (9:16) لكل دور: مشكلة ← حل ← إثبات ← ختام. فكرة واحدة ومرئي واحد في كل مشهد. يعمل على GitHub Actions (promo.yml)."""
import json, pathlib, subprocess, html
from playwright.sync_api import sync_playwright
H = pathlib.Path(__file__).parent.resolve(); OUT = H / 'out'; OUT.mkdir(exist_ok=True); W = H / 'work'; W.mkdir(exist_ok=True)
T = json.load(open(H / 'texts.json', encoding='utf-8'))
CP = {'help': 0xe309, 'timer_off': 0xe667, 'person_add': 0xe492, 'restaurant_menu': 0xe533, 'fitness_center': 0xe28d, 'local_fire_department': 0xe392, 'medical_services': 0xe3d8}
E = html.escape
MOCK = {
 'notify': '<div class="nt"><div class="c"><span class="mi">&#58448;</span></div><div><b>العشاء · بعد 45 دقيقة</b><span>سمك مشوي مع أرز وخضار</span></div></div><div class="nt two"><div class="c"><span class="mi">&#57458;</span></div><div><b>حان موعد العشاء · 8:00 م</b><span>سمك مشوي مع أرز وخضار</span></div></div>',
 'done': '<div class="done"><div class="m">العشاء · 8:00 م</div><div class="go">حُضّرت ✓</div></div><div class="toast">وصل مدير البيت: الوجبة جاهزة</div>',
 'code': '<div class="bub code">K7M2QX</div><div class="bub">رمز الدعوة يعمل مرة واحدة<small>أرسله بواتساب أو انسخه</small></div>',
 'link': '<div class="done"><div class="m">طلب ربط من طبيبك</div><div class="sub">لا يتم الربط إلا بموافقتك</div><div class="go">موافقة</div></div>',
}
def dur(f): return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(f)], capture_output=True, text=True).stdout)
CSS = """
@font-face{font-family:T;src:url(fonts/Tajawal-Regular.ttf);font-weight:400}@font-face{font-family:T;src:url(fonts/Tajawal-Bold.ttf);font-weight:700}
@font-face{font-family:T;src:url(fonts/Tajawal-ExtraBold.ttf);font-weight:800}@font-face{font-family:T;src:url(fonts/Tajawal-Black.ttf);font-weight:900}
@font-face{font-family:MI;src:url(fonts/MaterialIcons-Regular.otf)}
.mi{font-family:MI;font-style:normal;font-weight:400;line-height:1;direction:ltr;display:inline-block}
html{width:1080px;height:1920px;overflow:hidden}*{box-sizing:border-box;margin:0}
body{width:1080px;height:1920px;font-family:T,sans-serif;direction:rtl;color:#fff;background:linear-gradient(170deg,#2b7a5d,#123528 70%);position:relative;overflow:hidden}
body.dark{background:radial-gradient(circle at 50% 38%,#24352d,#0c1713 75%)}
.logo{position:absolute;top:70px;right:70px;display:flex;align-items:center;gap:16px;font-weight:900;font-size:46px}.logo img{width:80px;height:80px}
.big{position:absolute;left:80px;right:80px;text-align:center;font-weight:900;color:#fff}
.pr .ico{position:absolute;top:360px;left:0;right:0;text-align:center;font-size:420px;color:#e0a63a;height:420px}
.pr .big{top:900px;font-size:112px;line-height:1.35}.pr .big em{font-style:normal;color:#e0a63a}
.photo{position:absolute;top:190px;left:70px;right:70px;height:820px;border-radius:64px;overflow:hidden;box-shadow:0 30px 80px #0007}.photo img{width:100%;height:100%;object-fit:cover}
.s .big,.f .big{font-size:88px;line-height:1.35}.s .big{top:1090px}
.meal{position:absolute;left:70px;right:70px;top:1500px;background:#faf4e6;color:#1f2937;border-radius:48px;padding:38px 48px;box-shadow:0 20px 60px #0006}.meal b{display:block;font-size:40px;color:#bf8630;font-weight:900}.meal span{font-size:56px;font-weight:900;line-height:1.35}
.f .big{top:200px}.f .note{position:absolute;left:80px;right:80px;bottom:90px;text-align:center;font-size:36px;color:#ffffffb0;font-weight:700}
.vis{position:absolute;top:560px;left:170px;right:170px;height:1230px;border-radius:64px;overflow:hidden;background:#fff;box-shadow:0 30px 90px #000a;border:12px solid #fff}.vis img{width:100%;height:100%;object-fit:cover;object-position:top}
.mock{position:absolute;top:760px;left:90px;right:90px;display:flex;flex-direction:column;gap:34px;color:#1f2937}
.photo.sm{top:560px;height:640px}.f .meal{top:1290px}
.day{position:absolute;top:520px;left:80px;right:80px;display:flex;flex-direction:column;gap:26px}
.row{display:flex;align-items:center;gap:30px;background:#faf4e6;border-radius:44px;padding:20px;color:#1f2937;box-shadow:0 14px 40px #0005}.row img{flex:none;width:210px;height:210px;border-radius:32px;object-fit:cover}.row b{display:block;font-size:40px;color:#bf8630;font-weight:900}.row span{font-size:50px;font-weight:900;line-height:1.3}
.bub{background:#fff;border-radius:44px;padding:48px;font-size:54px;font-weight:800;line-height:1.5;box-shadow:0 16px 50px #0005}.bub small{display:block;color:#2a7a5d;font-weight:800;margin-top:12px;font-size:44px}.bub.code{text-align:center;font-size:130px;letter-spacing:18px;font-weight:900;color:#1f5a44;padding:70px}
.nt{display:flex;align-items:center;gap:34px;background:#fff;border-radius:48px;padding:42px;box-shadow:0 16px 50px #0005}.nt .c{flex:none;width:128px;height:128px;border-radius:50%;background:#bf8630;display:grid;place-items:center}.nt .c .mi{color:#fff;font-size:84px}.nt.two .c{background:#1f5a44}.nt b{font-size:56px;display:block}.nt span{font-size:46px;color:#4b5563}
.done{background:#fff;border-radius:48px;padding:50px;box-shadow:0 16px 50px #0005}.done .m{font-weight:900;font-size:64px}.done .sub{font-size:44px;color:#4b5563;margin-top:10px}.done .go{margin-top:34px;border-radius:36px;background:#1f5a44;color:#fff;text-align:center;padding:42px;font-weight:900;font-size:68px}.toast{background:#faf4e6;color:#1f5a44;border-radius:70px;padding:40px;font-weight:900;font-size:54px;text-align:center}
.end{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:56px;text-align:center;padding:0 80px}
.end img{width:340px;height:340px}.end h1{font-size:150px;font-weight:900}.end .btn{background:#e0a63a;color:#1b2b24;border-radius:80px;padding:44px 90px;font-weight:900;font-size:76px;box-shadow:0 20px 60px #0006}.end p{font-size:52px;font-weight:700;color:#ffffffcc}
"""
def src(name): return f'photos/{name}.jpg'
def page(role, k):
    d = T[role]; logo = '<div class="logo"><img src="logo.svg"><span>سفرتي</span></div>'; cls = {'p': 'pr', 's': 's', 'f': 'f', 'c': ''}[k]; dark = ' class="dark"' if k == 'p' else ''
    if k == 'p':
        body = f'<div class="ico mi">&#{CP[d["icon"]]};</div><div class="big">{E(d["p"][0])}</div>'
    elif k == 'c':
        body = f'<div class="end"><img src="logo.svg"><h1>سفرتي</h1><div class="btn">حمّل التطبيق الآن</div><p>الرابط في البايو</p></div>'
    else:
        v = d[k + '_vis']; kind = v[0]; head = f'<div class="big">{E(d[k][0])}</div>'; vis = ''
        if kind == 'photo':
            if k == 's': vis = f'<div class="photo"><img src="{src(v[1])}"></div><div class="meal"><b>{E(v[2])}</b><span>{E(v[3])}</span></div>'
            else: vis = f'<div class="photo sm"><img src="{src(v[1])}"></div><div class="meal"><b>{E(v[2])}</b><span>{E(v[3])}</span></div>'
        elif kind == 'day':
            vis = '<div class="day">' + ''.join(f'<div class="row"><img src="{src(i)}"><div><b>{E(s)}</b><span>{E(n)}</span></div></div>' for i, s, n in v[1]) + '</div>'
        elif kind == 'img': vis = f'<div class="vis"><img src="shots/{v[1]}"></div>'
        else: vis = f'<div class="mock">{MOCK[v[1]]}</div>'
        note = f'<div class="note">{E(d["note"])}</div>' if d.get('note') and k == 'f' else ''
        body = f'{logo}{head}{vis}{note}'
    return f'<!doctype html><meta charset=utf-8><style>{CSS}</style><body{dark}><div class="{cls}">{body}</div></body>'
roles = __import__('sys').argv[1:] or list(T)
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1080, 'height': 1920})
    for role in roles:
        clips = []
        for n, s in enumerate('psfc'):
            f = H / f'_{role}_{n}.html'; f.write_text(page(role, s), encoding='utf-8')
            pg.goto(f'file://{f}'); pg.evaluate('document.fonts.ready'); pg.wait_for_timeout(1200); png = W / f'{role}_{n}.png'; pg.screenshot(path=str(png))
            a = H / 'audio' / f'{role}_{s}.mp3'; d = dur(a) + (1.6 if s == 'c' else 0.9); c = W / f'{role}_{n}.mp4'; fr = int(d * 30)
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-loop', '1', '-i', str(png), '-i', str(a), '-af', f'adelay=400|400,apad=whole_dur={d:.2f}',
                            '-vf', f"zoompan=z='1+0.00045*on':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d={fr}:s=1080x1920:fps=30,fade=t=in:st=0:d=0.3,format=yuv420p",
                            '-t', f'{d:.2f}', '-c:v', 'libx264', '-crf', '21', '-c:a', 'aac', '-b:a', '160k', str(c)], check=True)
            clips.append(c)
        lst = W / f'{role}.txt'; lst.write_text(''.join(f"file '{c}'\n" for c in clips))
        o = OUT / f'sufrati_promo_{role}.mp4'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(lst), '-c', 'copy', str(o)], check=True)
        print(role, round(dur(o), 1), 's')
    b.close()
