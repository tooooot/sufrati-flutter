#!/usr/bin/env python3
"""يصيّر إعلانات سفرتي (9:16) لكل دور: عنوان على لوحة ← ٣ خطوات تظهر تباعاً ← بطاقة ختام. يعمل على GitHub Actions (promo.yml)."""
import json, pathlib, subprocess, html
from playwright.sync_api import sync_playwright
H = pathlib.Path(__file__).parent.resolve(); OUT = H / 'out'; OUT.mkdir(exist_ok=True); W = H / 'work'; W.mkdir(exist_ok=True)
T = json.load(open(H / 'texts.json', encoding='utf-8'))
E = html.escape
def dur(f): return float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', str(f)], capture_output=True, text=True).stdout)
CSS = """
@font-face{font-family:T;src:url(fonts/Tajawal-Regular.ttf);font-weight:400}@font-face{font-family:T;src:url(fonts/Tajawal-Bold.ttf);font-weight:700}
@font-face{font-family:T;src:url(fonts/Tajawal-ExtraBold.ttf);font-weight:800}@font-face{font-family:T;src:url(fonts/Tajawal-Black.ttf);font-weight:900}
*{box-sizing:border-box;margin:0}body{width:1080px;height:1920px;font-family:T,sans-serif;direction:rtl;color:#fff;background:linear-gradient(170deg,#2b7a5d,#123528 70%);position:relative;overflow:hidden}
.logo{position:absolute;top:70px;left:70px;display:flex;align-items:center;gap:16px;font-weight:900;font-size:44px}.logo img{width:84px;height:84px}
.title{position:absolute;top:240px;left:70px;right:70px;background:#faf4e6;color:#1f5a44;border-radius:56px;padding:70px 56px;text-align:center;font-weight:900;font-size:92px;line-height:1.35;box-shadow:0 24px 70px #0005}
.steps{position:absolute;top:760px;left:70px;right:70px;display:flex;flex-direction:column;gap:34px}
.step{display:flex;align-items:center;gap:30px;background:#fff;color:#1f2937;border-radius:48px;padding:40px;box-shadow:0 18px 50px #0004;font-weight:800;font-size:56px;line-height:1.4}
.step i{flex:none;width:110px;height:110px;border-radius:50%;background:#bf8630;color:#fff;display:grid;place-items:center;font-style:normal;font-weight:900;font-size:62px}
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
        steps = ''.join(f'<div class="step"><i>{k + 1}</i><span>{E(d["steps"][k][0])}</span></div>' for k in range(n))
        body = f'{logo}<div class="title">{E(d["title"][0])}</div><div class="steps">{steps}</div>'
    return f'<!doctype html><meta charset=utf-8><style>{CSS}</style>{body}'
with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={'width': 1080, 'height': 1920})
    for role in T:
        segs = ['t', '1', '2', '3', 'c']; clips = []
        for n, s in enumerate(segs):
            f = H / f'_{role}_{n}.html'; f.write_text(page(role, n), encoding='utf-8')
            pg.goto(f'file://{f}'); pg.wait_for_timeout(500); png = W / f'{role}_{n}.png'; pg.screenshot(path=str(png))
            a = H / 'audio' / f'{role}_{s}.mp3'; d = dur(a) + (1.4 if s == 'c' else 0.7); c = W / f'{role}_{n}.mp4'
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-loop', '1', '-i', str(png), '-i', str(a), '-af', f'adelay=350|350,apad=whole_dur={d:.2f}',
                            '-vf', 'scale=1080:1920,fade=t=in:st=0:d=0.35,format=yuv420p', '-t', f'{d:.2f}', '-r', '30', '-c:v', 'libx264', '-crf', '21', '-c:a', 'aac', '-b:a', '160k', str(c)], check=True)
            clips.append(c)
        lst = W / f'{role}.txt'; lst.write_text(''.join(f"file '{c}'\n" for c in clips))
        o = OUT / f'sufrati_promo_{role}.mp4'
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(lst), '-c', 'copy', str(o)], check=True)
        print(role, round(dur(o), 1), 's')
    b.close()
