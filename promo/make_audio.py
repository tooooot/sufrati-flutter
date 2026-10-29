#!/usr/bin/env python3
"""تعليق عبدالرحمن (ElevenLabs) لإعلانات الأدوار: نص السكون (waqf) لكل مشهد → audio/<role>_<p|s|f|c>.mp3"""
import json, pathlib, requests
H = pathlib.Path(__file__).parent
key = next(l.split('=', 1)[1].strip().strip('"\'') for l in open('/root/env/.env') if l.startswith('ELEVENLABS_API_KEY='))
vs = requests.get('https://api.elevenlabs.io/v1/voices', headers={'xi-api-key': key}, timeout=30).json()['voices']
vid = next(v['voice_id'] for v in vs if v['name'].startswith('Abdulrahman'))
T = json.load(open(H / 'texts.json', encoding='utf-8'))
(H / 'audio').mkdir(exist_ok=True)
for role, d in T.items():
    for k in 'psfc':
        out = H / 'audio' / f'{role}_{k}.mp3'
        if out.exists() and out.stat().st_mtime > (H / 'texts.json').stat().st_mtime: continue
        r = requests.post(f'https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128', headers={'xi-api-key': key},
                          json={'text': d[k][1], 'model_id': 'eleven_multilingual_v2', 'voice_settings': {'stability': 0.5, 'similarity_boost': 0.8}}, timeout=120)
        r.raise_for_status(); out.write_bytes(r.content); print(role, k, len(r.content))
