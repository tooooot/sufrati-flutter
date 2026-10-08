#!/usr/bin/env python3
"""يختبر firestore.rules على خدمة Firebase Rules (بلا نشر ولا Firestore): python3 test_rules.py <service-account.json>
كل حالة: (اسم، توقّع، uid، claims، طريقة، مسار، بيانات، محاكاة get)."""
import json, sys, time, jwt, requests
k = json.load(open(sys.argv[1])); now = int(time.time())
a = jwt.encode({'iss': k['client_email'], 'scope': 'https://www.googleapis.com/auth/cloud-platform', 'aud': 'https://oauth2.googleapis.com/token', 'iat': now, 'exp': now + 3000}, k['private_key'], algorithm='RS256')
H = {'Authorization': 'Bearer ' + requests.post('https://oauth2.googleapis.com/token', data={'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion': a}).json()['access_token']}
src = open(__file__.rsplit('/', 1)[0] + '/firestore.rules').read()
D = '/databases/(default)/documents'
HH = {'label': 'x', 'members': {'own': 'owner', 'cok': 'cook', 'doc': 'doctor'}}
HH_NOOWNER = {'label': 'x', 'members': {'doc': 'doctor'}}
def fv(d): return {'value': {'data': d}}
def mock(path, d): return {'function': 'get', 'args': [{'exact_value': f'{D}/{path}'}], 'result': fv(d)}
def exists(path): return {'function': 'exists', 'args': [{'exact_value': f'{D}/{path}'}], 'result': {'value': True}}
H_MOCK = mock('households/h1', HH)
USER_DOC = mock('users/doc', {'isDoctor': True})
cases = []
def case(name, ok, uid, method, path, data=None, mocks=(), admin=False, existing=None):
    c = {'expectation': 'ALLOW' if ok else 'DENY',
         'request': {'auth': {'uid': uid, 'token': {'admin': True} if admin else {}} if uid else None, 'time': '2026-10-08T12:00:00Z'},
         'functionMocks': list(mocks)}
    c['request'].update({'path': f'{D}/{path}', 'method': method.lower()})
    if data is not None: c['request']['resource'] = {'data': data}
    if existing is not None: c['resource'] = {'data': existing}
    cases.append((name, c))
W = {'prepared': ['0:lunch']}
# قراءة
case('الطباخ يقرأ بيته', True, 'cok', 'GET', 'households/h1', mocks=[H_MOCK])
case('غريب لا يقرأ البيت', False, 'zzz', 'GET', 'households/h1', mocks=[H_MOCK])
case('بلا تسجيل لا يقرأ', False, None, 'GET', 'households/h1', mocks=[H_MOCK])
case('الطباخ لا يقرأ البيانات الصحية', False, 'cok', 'GET', 'households/h1/private/profile', mocks=[H_MOCK])
case('الطبيب يقرأ البيانات الصحية', True, 'doc', 'GET', 'households/h1/private/profile', mocks=[H_MOCK])
case('الصاحب يقرأ البيانات الصحية', True, 'own', 'GET', 'households/h1/private/profile', mocks=[H_MOCK])
case('المدير يقرأ أي بيت', True, 'adm', 'GET', 'households/h1/private/profile', mocks=[H_MOCK], admin=True)
# الخطط
case('الطباخ يعلّم جاهز', True, 'cok', 'UPDATE', 'households/h1/weeks/2026-10-04', data={'prepared': ['0:lunch'], 'days': 1}, existing={'prepared': [], 'days': 1}, mocks=[H_MOCK])
case('الطباخ لا يغيّر الأيام', False, 'cok', 'UPDATE', 'households/h1/weeks/2026-10-04', data={'prepared': [], 'days': 2}, existing={'prepared': [], 'days': 1}, mocks=[H_MOCK])
case('الصاحب يعدّل الخطة', True, 'own', 'UPDATE', 'households/h1/weeks/2026-10-04', data={'days': 2}, existing={'days': 1}, mocks=[H_MOCK])
case('الطبيب يعدّل الخطة', True, 'doc', 'UPDATE', 'households/h1/weeks/2026-10-04', data={'days': 2}, existing={'days': 1}, mocks=[H_MOCK])
# المشتريات
case('الطباخ يقرأ المشتريات', True, 'cok', 'GET', 'households/h1/shopping/2026-10-04', mocks=[H_MOCK])
case('الطباخ لا يعدّل المشتريات', False, 'cok', 'UPDATE', 'households/h1/shopping/2026-10-04', data={'a': 1}, existing={'a': 0}, mocks=[H_MOCK])
case('الصاحب يعدّل المشتريات', True, 'own', 'UPDATE', 'households/h1/shopping/2026-10-04', data={'a': 1}, existing={'a': 0}, mocks=[H_MOCK])
# الحذف
case('الصاحب يحذف بيته', True, 'own', 'DELETE', 'households/h1', existing=HH, mocks=[H_MOCK])
case('الطبيب لا يحذف بيتاً له صاحب', False, 'doc', 'DELETE', 'households/h1', existing=HH, mocks=[H_MOCK])
case('الطباخ لا يحذف', False, 'cok', 'DELETE', 'households/h1', existing=HH, mocks=[H_MOCK])
case('الطبيب يحذف بيتاً بلا صاحب', True, 'doc', 'DELETE', 'households/h1', existing=HH_NOOWNER, mocks=[mock('households/h1', HH_NOOWNER)])
case('المدير يحذف', True, 'adm', 'DELETE', 'households/h1', existing=HH, mocks=[H_MOCK], admin=True)
# إنشاء بيت
case('مستخدم ينشئ بيتاً كصاحب', True, 'new', 'CREATE', 'households/h9', data={'members': {'new': 'owner'}})
case('لا يُنشئ بيتاً بعضو آخر', False, 'new', 'CREATE', 'households/h9', data={'members': {'new': 'owner', 'x': 'cook'}})
case('طبيب غير معتمد لا ينشئ', False, 'new', 'CREATE', 'households/h9', data={'members': {'new': 'doctor'}}, mocks=[mock('users/new', {'isDoctor': False})])
case('طبيب معتمد ينشئ', True, 'doc', 'CREATE', 'households/h9', data={'members': {'doc': 'doctor'}}, mocks=[USER_DOC])
# المستخدمون
case('المستخدم يجعل نفسه طبيباً', False, 'new', 'UPDATE', 'users/new', data={'isDoctor': True}, existing={'isDoctor': False})
case('المستخدم يعدّل اسمه', True, 'new', 'UPDATE', 'users/new', data={'name': 'a', 'isDoctor': False}, existing={'name': 'b', 'isDoctor': False})
case('المدير يمنح الطبيب', True, 'adm', 'UPDATE', 'users/doc', data={'isDoctor': True}, existing={'isDoctor': False}, admin=True)
# الدعوات
INV = {'hid': 'h1', 'role': 'cook', 'usedBy': None, 'expiresAt': '2026-12-01T00:00:00Z', 'createdBy': 'own'}
INV_AFTER = dict(INV, usedBy='new')
mem_new = {'own': 'owner', 'cok': 'cook', 'doc': 'doctor', 'new': 'cook'}
redeem_mocks = [H_MOCK, exists('invites/CODE1'), mock('invites/CODE1', INV), {'function': 'getAfter', 'args': [{'exact_value': f'{D}/invites/CODE1'}], 'result': fv(INV_AFTER)}]
case('قبول دعوة طباخ صحيحة', True, 'new', 'UPDATE', 'households/h1', data={'label': 'x', 'members': mem_new, 'lastInvite': 'CODE1'}, existing=HH, mocks=redeem_mocks)
case('قبول دعوة بدور أعلى من المدعو', False, 'new', 'UPDATE', 'households/h1', data={'label': 'x', 'members': dict(mem_new, new='owner'), 'lastInvite': 'CODE1'}, existing=HH, mocks=redeem_mocks)
case('غريب بلا دعوة يضيف نفسه', False, 'new', 'UPDATE', 'households/h1', data={'label': 'x', 'members': mem_new}, existing=HH, mocks=[H_MOCK])
case('الطباخ لا يضيف عضواً', False, 'cok', 'UPDATE', 'households/h1', data={'label': 'x', 'members': dict(mem_new, new='owner')}, existing=HH, mocks=[H_MOCK])
case('الطبيب لا يغيّر الأعضاء', False, 'doc', 'UPDATE', 'households/h1', data={'label': 'x', 'members': dict(mem_new, new='owner')}, existing=HH, mocks=[H_MOCK])
case('الصاحب يدعو طباخاً', True, 'own', 'CREATE', 'invites/C2', data={'hid': 'h1', 'role': 'cook', 'createdBy': 'own', 'expiresAt': '2026-12-01T00:00:00Z'}, mocks=[H_MOCK])
case('الصاحب لا ينشئ دعوة مالك', False, 'own', 'CREATE', 'invites/C2', data={'hid': 'h1', 'role': 'owner', 'createdBy': 'own', 'expiresAt': '2026-12-01T00:00:00Z'}, mocks=[H_MOCK])
case('الطباخ لا يدعو', False, 'cok', 'CREATE', 'invites/C2', data={'hid': 'h1', 'role': 'cook', 'createdBy': 'cok', 'expiresAt': '2026-12-01T00:00:00Z'}, mocks=[H_MOCK])
case('الطبيب يدعو مريضاً', True, 'doc', 'CREATE', 'invites/C2', data={'hid': 'h1', 'role': 'owner', 'createdBy': 'doc', 'expiresAt': '2026-12-01T00:00:00Z'}, mocks=[H_MOCK])
case('لا يقرأ قائمة الدعوات', False, 'own', 'LIST', 'invites')
# لوحة المنصة
case('الصاحب لا يقرأ البلاغات', False, 'own', 'GET', 'reports/r1')
case('المدير يقرأ البلاغات', True, 'adm', 'GET', 'reports/r1', admin=True)

body = {'source': {'files': [{'name': 'firestore.rules', 'content': src}]},
        'testSuite': {'testCases': [c for _, c in cases]}}
r = requests.post(f"https://firebaserules.googleapis.com/v1/projects/{k['project_id']}:test", headers=H, json=body)
j = r.json()
if r.status_code != 200 or j.get('issues'):
    print(r.status_code, json.dumps(j, ensure_ascii=False, indent=1)[:2500]); sys.exit(1)
res = j.get('testResults', [])
bad = 0
for (name, c), t in zip(cases, res):
    ok = t.get('state') == 'SUCCESS'; bad += not ok
    print(('✅' if ok else '❌'), name, '' if ok else json.dumps({x: t.get(x) for x in ('state', 'errorPosition', 'debugMessages', 'expressionReports') if t.get(x)}, ensure_ascii=False)[:600])
print(f'\n{len(cases)-bad}/{len(cases)} نجحت'); sys.exit(1 if bad else 0)
