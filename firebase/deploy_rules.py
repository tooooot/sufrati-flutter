#!/usr/bin/env python3
"""ينشر firebase/firestore.rules على مشروع sufrati-8555a بعد نجاح اختبارات المحاكي. الاستعمال:
   rules-test/run.sh && python3 firebase/deploy_rules.py"""
import json, pathlib, sys, time
import jwt, requests
PID = 'sufrati-8555a'
k = json.load(open('/root/env/sufrati-8555a-firebase-adminsdk-fbsvc-98de3e2150.json')); now = int(time.time())
a = jwt.encode({'iss': k['client_email'], 'scope': 'https://www.googleapis.com/auth/cloud-platform', 'aud': 'https://oauth2.googleapis.com/token', 'iat': now, 'exp': now + 3000}, k['private_key'], algorithm='RS256')
H = {'Authorization': 'Bearer ' + requests.post('https://oauth2.googleapis.com/token', data={'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion': a}).json()['access_token']}
src = (pathlib.Path(__file__).parent / 'firestore.rules').read_text()
rs = requests.post(f'https://firebaserules.googleapis.com/v1/projects/{PID}/rulesets', headers=H, json={'source': {'files': [{'name': 'firestore.rules', 'content': src}]}})
if not rs.ok: sys.exit(f'✗ ruleset: {rs.status_code} {rs.text[:400]}')
name = rs.json()['name']
rel = requests.patch(f'https://firebaserules.googleapis.com/v1/projects/{PID}/releases/cloud.firestore', headers=H,
                     json={'release': {'name': f'projects/{PID}/releases/cloud.firestore', 'rulesetName': name}})
if not rel.ok: sys.exit(f'✗ release: {rel.status_code} {rel.text[:400]}')
print('✅ نُشرت القواعد:', name.split('/')[-1])
