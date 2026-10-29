#!/usr/bin/env python3
"""تعليق عبدالرحمن (ElevenLabs) لإعلانات الأدوار: نص السكون (waqf) لكل مقطع → audio/<role>_<seg>.mp3 (seg: t,1,2,3,c)."""
import json, pathlib, requests
H = pathlib.Path(__file__).parent
key = next(l.split('=', 1)[1].strip().strip('"\'') for l in open('/root/env/.env') if l.startswith('ELEVENLABS_API_KEY='))
vs = requests.get('https://api.elevenlabs.io/v1/voices', headers={'xi-api-key': key}, timeout=30).json()['voices']
vid = next(v['voice_id'] for v in vs if v['name'].startswith('Abdulrahman'))
T = json.load(open(H / 'texts.json', encoding='utf-8'))
for role, d in T.items():
    segs = {'t': d['title'][1], '1': d['steps'][0][1], '2': d['steps'][1][1], '3': d['steps'][2][1], 'c': d['close'][1]}
    for k, text in segs.items():
        r = requests.post(f'https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128', headers={'xi-api-key': key},
                          json={'text': text, 'model_id': 'eleven_multilingual_v2', 'voice_settings': {'stability': 0.5, 'similarity_boost': 0.8}}, timeout=120)
        r.raise_for_status(); (H / 'audio' / f'{role}_{k}.mp3').write_bytes(r.content); print(role, k, len(r.content))
