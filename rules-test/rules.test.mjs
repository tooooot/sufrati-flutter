// اختبار قواعد Firestore على المحاكي الحقيقي (يشمل get/getAfter/exists التي لا يغطيها الاختبار عن بعد)
import { test, before, after, beforeEach } from 'node:test';
import fs from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, getDocs, collection, writeBatch, Timestamp } from 'firebase/firestore';

let env;
const future = () => Timestamp.fromDate(new Date(Date.now() + 86400e3));
const past = () => Timestamp.fromDate(new Date(Date.now() - 86400e3));
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-sufrati',
    firestore: { rules: fs.readFileSync('./firestore.rules', 'utf8'), host: '127.0.0.1', port: 8089 },
  });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'households/h1'), { label: 'x', programId: 'kidney_salama', members: { own: 'owner', cok: 'cook', doc: 'doctor' } });
    await setDoc(doc(db, 'households/h2'), { label: 'y', programId: 'keto_general', members: { doc: 'doctor' } }); // بلا صاحب
    await setDoc(doc(db, 'households/h1/weeks/w1'), { days: 1, prepared: [] });
    await setDoc(doc(db, 'households/h1/shopping/w1'), { a: 0 });
    await setDoc(doc(db, 'households/h1/private/profile'), { note: 'سري' });
    await setDoc(doc(db, 'users/doc'), { isDoctor: true });
    await setDoc(doc(db, 'users/new'), { isDoctor: false });
    await setDoc(doc(db, 'invites/CODE1'), { hid: 'h1', role: 'cook', createdBy: 'own', usedBy: null, expiresAt: future() });
    await setDoc(doc(db, 'invites/OLD1'), { hid: 'h1', role: 'cook', createdBy: 'own', usedBy: null, expiresAt: past() });
    await setDoc(doc(db, 'invites/OWN1'), { hid: 'h1', role: 'owner', createdBy: 'doc', usedBy: null, expiresAt: future() });
  });
});
const as = (uid, claims = {}) => env.authenticatedContext(uid, claims).firestore();
const anon = () => env.unauthenticatedContext().firestore();

test('القراءة: الأعضاء فقط', async () => {
  await assertSucceeds(getDoc(doc(as('cok'), 'households/h1')));
  await assertFails(getDoc(doc(as('zzz'), 'households/h1')));
  await assertFails(getDoc(doc(anon(), 'households/h1')));
  await assertSucceeds(getDoc(doc(as('adm', { admin: true }), 'households/h1')));
});
test('البيانات الصحية: الطاهي لا يراها', async () => {
  await assertFails(getDoc(doc(as('cok'), 'households/h1/private/profile')));
  await assertSucceeds(getDoc(doc(as('doc'), 'households/h1/private/profile')));
  await assertSucceeds(getDoc(doc(as('own'), 'households/h1/private/profile')));
  await assertSucceeds(getDoc(doc(as('adm', { admin: true }), 'households/h1/private/profile')));
});
test('الخطط: الطاهي يعلّم «جاهز» فقط', async () => {
  await assertSucceeds(updateDoc(doc(as('cok'), 'households/h1/weeks/w1'), { prepared: ['0:lunch'] }));
  await assertFails(updateDoc(doc(as('cok'), 'households/h1/weeks/w1'), { days: 2 }));
  await assertSucceeds(updateDoc(doc(as('own'), 'households/h1/weeks/w1'), { days: 2 }));
  await assertSucceeds(updateDoc(doc(as('doc'), 'households/h1/weeks/w1'), { days: 3 }));
  await assertFails(updateDoc(doc(as('zzz'), 'households/h1/weeks/w1'), { prepared: ['x'] }));
});
test('المشتريات: الطباخ قراءة فقط', async () => {
  await assertSucceeds(getDoc(doc(as('cok'), 'households/h1/shopping/w1')));
  await assertFails(updateDoc(doc(as('cok'), 'households/h1/shopping/w1'), { a: 1 }));
  await assertSucceeds(updateDoc(doc(as('own'), 'households/h1/shopping/w1'), { a: 1 }));
});
test('الحذف', async () => {
  await assertFails(deleteDoc(doc(as('cok'), 'households/h1')));
  await assertFails(deleteDoc(doc(as('doc'), 'households/h1')), 'الطبيب لا يحذف بيتاً له صاحب');
  await assertSucceeds(deleteDoc(doc(as('doc'), 'households/h2')));
  await assertSucceeds(deleteDoc(doc(as('own'), 'households/h1')));
});
test('إنشاء بيت: صاحب', async () => { await assertSucceeds(setDoc(doc(as('new'), 'households/h9'), { members: { new: 'owner' } })); });
test('إنشاء بيت: عضو إضافي مرفوض', async () => { await assertFails(setDoc(doc(as('new'), 'households/h9'), { members: { new: 'owner', x: 'cook' } })); });
test('إنشاء بيت: طبيب غير معتمد مرفوض', async () => { await assertFails(setDoc(doc(as('new'), 'households/h9'), { members: { new: 'doctor' } })); });
test('إنشاء بيت: طبيب معتمد', async () => { await assertSucceeds(setDoc(doc(as('doc'), 'households/h9'), { members: { doc: 'doctor' } })); });
test('المستخدمون: لا يمنح أحد نفسه طبيباً', async () => {
  await assertFails(updateDoc(doc(as('new'), 'users/new'), { isDoctor: true }));
  await assertSucceeds(updateDoc(doc(as('new'), 'users/new'), { name: 'a' }));
  await assertSucceeds(updateDoc(doc(as('adm', { admin: true }), 'users/new'), { isDoctor: true }));
  await assertFails(setDoc(doc(as('n2'), 'users/n2'), { isDoctor: true }));
  await assertSucceeds(setDoc(doc(as('n2'), 'users/n2'), { isDoctor: false, name: 'x' }));
  await assertFails(getDoc(doc(as('n2'), 'users/new')));
});
test('قبول الدعوة (الدفعة): الدور المحدد فقط ومرة واحدة', async () => {
  const join = (uid, role, code) => {
    const db = as(uid), b = writeBatch(db);
    b.update(doc(db, 'invites', code), { usedBy: uid, usedAt: Timestamp.now() });
    b.update(doc(db, 'households/h1'), { members: { own: 'owner', cok: 'cook', doc: 'doctor', [uid]: role }, lastInvite: code });
    return b.commit();
  };
  await assertSucceeds(join('new', 'cook', 'CODE1'));
  await assertFails(join('n3', 'cook', 'CODE1')); // مستخدمة
  await assertFails(join('n4', 'owner', 'CODE1'), 'رفع الدور فوق الدعوة');
  await assertFails(join('n5', 'cook', 'OLD1')); // منتهية
});
test('الدعوة بلا علامة الاستخدام أو من غريب مرفوضة', async () => {
  const db = as('new');
  await assertFails(updateDoc(doc(db, 'households/h1'), { members: { own: 'owner', cok: 'cook', doc: 'doctor', new: 'cook' }, lastInvite: 'CODE1' }));
  await assertFails(updateDoc(doc(as('cok'), 'households/h1'), { members: { own: 'owner', cok: 'cook', doc: 'doctor', zzz: 'owner' } }));
  await assertFails(updateDoc(doc(as('doc'), 'households/h1'), { members: { own: 'owner', cok: 'cook', doc: 'doctor', zzz: 'owner' } }));
});
const inv = (uid, role) => setDoc(doc(as(uid), 'invites/NEWC'), { hid: 'h1', role, createdBy: uid, expiresAt: future() });
test('دعوة: الصاحب يدعو طاهياً', async () => { await assertSucceeds(inv('own', 'cook')); });
test('دعوة: الصاحب يدعو طبيباً', async () => { await assertSucceeds(inv('own', 'doctor')); });
test('دعوة: الصاحب لا ينشئ دعوة مالك', async () => { await assertFails(inv('own', 'owner')); });
test('دعوة: الطاهي لا يدعو', async () => { await assertFails(inv('cok', 'cook')); });
test('دعوة: الطبيب يدعو مريضاً', async () => { await assertSucceeds(inv('doc', 'owner')); });
test('دعوة: الطبيب لا يدعو طاهياً', async () => { await assertFails(inv('doc', 'cook')); });
test('دعوة: لا قراءة للقائمة', async () => { await assertFails(getDocs(collection(as('own'), 'invites'))); });
test('لوحة المنصة والبلاغات', async () => {
  await assertFails(getDoc(doc(as('own'), 'reports/r1')));
  await assertSucceeds(getDoc(doc(as('adm', { admin: true }), 'reports/r1')));
  await assertSucceeds(setDoc(doc(as('own'), 'reports/r2'), { createdBy: 'own', reason: 'x' }));
  await assertFails(setDoc(doc(as('own'), 'reports/r3'), { createdBy: 'someone-else' }));
});
test('دعوة المالك: المريض/المستخدم القديم يصير صاحب البيت', async () => {
  const db = as('pat'), b = writeBatch(db);
  b.update(doc(db, 'invites/OWN1'), { usedBy: 'pat', usedAt: Timestamp.now() });
  b.update(doc(db, 'households/h1'), { members: { own: 'owner', cok: 'cook', doc: 'doctor', pat: 'owner' }, lastInvite: 'OWN1' });
  await assertSucceeds(b.commit());
});
test('دعوة المالك لا تُستعمل لدور الطاهي', async () => {
  const db = as('pat'), b = writeBatch(db);
  b.update(doc(db, 'invites/OWN1'), { usedBy: 'pat', usedAt: Timestamp.now() });
  b.update(doc(db, 'households/h1'), { members: { own: 'owner', cok: 'cook', doc: 'doctor', pat: 'cook' }, lastInvite: 'OWN1' });
  await assertFails(b.commit());
});
test('عزل البيوت: عضو بيت لا يقرأ بيتاً آخر ولا خططه', async () => {
  await assertFails(getDoc(doc(as('own'), 'households/h2')));
  await assertFails(getDoc(doc(as('cok'), 'households/h2/weeks/w1')));
});

test('مغادرة: الطاهي يحذف نفسه فقط', async () => {
  await assertSucceeds(updateDoc(doc(as('cok'), 'households/h1'), { members: { own: 'owner', doc: 'doctor' } }));
});
test('مغادرة: لا يحذف غيره ولا يغيّر شيئاً آخر', async () => {
  await assertFails(updateDoc(doc(as('cok'), 'households/h1'), { members: { cok: 'cook', doc: 'doctor' } }));
  await assertFails(updateDoc(doc(as('cok'), 'households/h1'), { members: { own: 'owner', doc: 'doctor' }, label: 'hack' }));
});
test('الدعوة: يحفظ اسم من انضم', async () => {
  const db = as('new'), b = writeBatch(db);
  b.update(doc(db, 'invites/CODE1'), { usedBy: 'new', usedAt: Timestamp.now(), usedByName: 'ماريا' });
  b.update(doc(db, 'households/h1'), { 'members.new': 'cook', lastInvite: 'CODE1' });
  await assertSucceeds(b.commit());
});

test('بروفايل الطبيب: المعتمد يُقرأ علناً، وغير المعتمد لصاحبه والمدير فقط، ولا يفعّل نفسه', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'doctors/VERIF1'), { uid: 'doc', name: 'د. أ', verified: true });
    await setDoc(doc(ctx.firestore(), 'doctors/PEND1'), { uid: 'doc', name: 'د. ب', verified: false });
  });
  await assertSucceeds(getDoc(doc(anon(), 'doctors/VERIF1')));
  await assertFails(getDoc(doc(anon(), 'doctors/PEND1')));
  await assertSucceeds(getDoc(doc(as('doc'), 'doctors/PEND1')));
  await assertSucceeds(getDoc(doc(as('adm', { admin: true }), 'doctors/PEND1')));
  await assertFails(getDocs(collection(anon(), 'doctors')));
  // الطبيب لا يفعّل نفسه ولا يغيّر مالك البروفايل
  await assertFails(updateDoc(doc(as('doc'), 'doctors/PEND1'), { verified: true }));
  await assertSucceeds(updateDoc(doc(as('doc'), 'doctors/PEND1'), { bio: 'نبذة' }));
  await assertFails(updateDoc(doc(as('doc'), 'doctors/PEND1'), { uid: 'zzz' }));
  await assertSucceeds(updateDoc(doc(as('adm', { admin: true }), 'doctors/PEND1'), { verified: true }));
  // إنشاء: لطبيب معتمد فقط، بلا verified
  await assertSucceeds(setDoc(doc(as('doc'), 'doctors/NEW1'), { uid: 'doc', name: 'د. ج', verified: false }));
  await assertFails(setDoc(doc(as('doc'), 'doctors/NEW2'), { uid: 'doc', name: 'د. د', verified: true }));
  await assertFails(setDoc(doc(as('new'), 'doctors/NEW3'), { uid: 'new', name: 'غير طبيب', verified: false }));
  await assertFails(setDoc(doc(as('doc'), 'doctors/NEW4'), { uid: 'other', name: 'ينتحل', verified: false }));
});
test('طلبات الربط: صاحب البيت ينشئ، والطبيب صاحب البروفايل يقرأ ويحذف، وغيرهما لا', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'doctors/VERIF1'), { uid: 'doc', name: 'د. أ', verified: true });
    await setDoc(doc(ctx.firestore(), 'doctors/VERIF1/requests/r1'), { from: 'own', hid: 'h1', inviteCode: 'OWN1' });
  });
  await assertSucceeds(setDoc(doc(as('own'), 'doctors/VERIF1/requests/r2'), { from: 'own', hid: 'h1', inviteCode: 'X' }));
  await assertFails(setDoc(doc(as('cok'), 'doctors/VERIF1/requests/r3'), { from: 'cok', hid: 'h1', inviteCode: 'X' }), 'الطاهي ليس مالكاً');
  await assertFails(setDoc(doc(as('own'), 'doctors/VERIF1/requests/r4'), { from: 'zzz', hid: 'h1', inviteCode: 'X' }));
  await assertSucceeds(getDocs(collection(as('doc'), 'doctors/VERIF1/requests')));
  await assertFails(getDocs(collection(as('own'), 'doctors/VERIF1/requests')));
  await assertSucceeds(getDoc(doc(as('own'), 'doctors/VERIF1/requests/r1')));
  await assertFails(getDoc(doc(as('cok'), 'doctors/VERIF1/requests/r1')));
  await assertSucceeds(deleteDoc(doc(as('doc'), 'doctors/VERIF1/requests/r1')));
});
test('روابط التسويق: قراءة بالرمز للجميع، وتسجيل الفتح مرة واحدة فقط، والباقي للمدير', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'pitchLinks/TOK1'), { kind: 'doctor', name: 'أحمد', openedAt: null });
  });
  await assertSucceeds(getDoc(doc(anon(), 'pitchLinks/TOK1')));
  await assertFails(getDocs(collection(anon(), 'pitchLinks')));
  await assertFails(setDoc(doc(anon(), 'pitchLinks/TOK2'), { kind: 'doctor', name: 'x' }));
  await assertFails(updateDoc(doc(anon(), 'pitchLinks/TOK1'), { name: 'مزوّر' }));
  await assertSucceeds(updateDoc(doc(anon(), 'pitchLinks/TOK1'), { openedAt: Timestamp.now() }));
  await assertFails(updateDoc(doc(anon(), 'pitchLinks/TOK1'), { openedAt: Timestamp.now() }), 'مرة واحدة');
  await assertSucceeds(setDoc(doc(as('adm', { admin: true }), 'pitchLinks/TOK3'), { kind: 'cook', name: 'ماريا' }));
});

test('التسويق: المستهدفون للمدير وحده، وختم «سجّل» مرة واحدة باسم صاحبه', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'marketingTargets/T1'), { name: 'د. خالد', phone: '0500000000' });
    await setDoc(doc(ctx.firestore(), 'pitchLinks/TOK9'), { kind: 'doctor', name: 'خالد', openedAt: null });
  });
  await assertFails(getDoc(doc(anon(), 'marketingTargets/T1')));
  await assertFails(getDoc(doc(as('doc'), 'marketingTargets/T1')));
  await assertFails(getDocs(collection(as('own'), 'marketingTargets')));
  await assertFails(setDoc(doc(as('own'), 'marketingTargets/T2'), { name: 'x' }));
  await assertSucceeds(getDoc(doc(as('adm', { admin: true }), 'marketingTargets/T1')));
  await assertSucceeds(setDoc(doc(as('adm', { admin: true }), 'marketingTargets/T2'), { name: 'y' }));
  // ختم التسجيل
  await assertFails(updateDoc(doc(anon(), 'pitchLinks/TOK9'), { registeredAt: Timestamp.now(), registeredBy: 'x' }), 'غير مسجَّل');
  await assertFails(updateDoc(doc(as('own'), 'pitchLinks/TOK9'), { registeredAt: Timestamp.now(), registeredBy: 'غيري' }), 'باسم غيره');
  await assertFails(updateDoc(doc(as('own'), 'pitchLinks/TOK9'), { registeredAt: Timestamp.now(), registeredBy: 'own', name: 'مزوّر' }));
  await assertSucceeds(updateDoc(doc(as('own'), 'pitchLinks/TOK9'), { registeredAt: Timestamp.now(), registeredBy: 'own' }));
  await assertFails(updateDoc(doc(as('cok'), 'pitchLinks/TOK9'), { registeredAt: Timestamp.now(), registeredBy: 'cok' }), 'مرة واحدة');
});

test('موافقة واحدة: المدير ينشئ البروفايل المعتمد، والطبيب يخفض verified ولا يرفعه', async () => {
  await assertSucceeds(setDoc(doc(as('adm', { admin: true }), 'doctors/ADM1'), { uid: 'doc', name: 'د. أ', licenseNo: '1', verified: true }));
  await assertFails(setDoc(doc(as('own'), 'doctors/ADM2'), { uid: 'doc', name: 'منتحل', verified: true }), 'غير المدير لا ينشئ معتمداً');
  // الطبيب يعدّل نبذته ويبقى معتمداً
  await assertSucceeds(updateDoc(doc(as('doc'), 'doctors/ADM1'), { bio: 'نبذة' }));
  // خفض verified (بعد تعديل الاسم/الترخيص) مسموح، ثم لا يعيد رفعه
  await assertSucceeds(updateDoc(doc(as('doc'), 'doctors/ADM1'), { name: 'د. جديد', verified: false }));
  await assertFails(updateDoc(doc(as('doc'), 'doctors/ADM1'), { verified: true }));
  await assertSucceeds(updateDoc(doc(as('adm', { admin: true }), 'doctors/ADM1'), { verified: true }));
});

test('طابور الإشعارات: كل نوع لكاتبه الصحيح فقط، وبلا قراءة لغير المدير', async () => {
  const ev = (type, extra) => ({ type, from: 'x', createdAt: Timestamp.now(), ...extra });
  const q = (ctx) => collection(ctx, 'notifyQueue');
  // الطاهي يبلّغ حُضّرت لبيته فقط
  await assertSucceeds(setDoc(doc(q(as('cok')), 'a1'), ev('prepared', { from: 'cok', hid: 'h1', meal: 'العشاء' })));
  await assertFails(setDoc(doc(q(as('cok')), 'a2'), ev('prepared', { from: 'own', hid: 'h1' })), 'باسم غيره');
  await assertFails(setDoc(doc(q(as('own')), 'a3'), ev('prepared', { from: 'own', hid: 'h1' })), 'الصاحب ليس طاهياً');
  await assertFails(setDoc(doc(q(as('cok')), 'a4'), ev('prepared', { from: 'cok', hid: 'h2' })), 'بيت غيره');
  // الصاحب والطبيب يبلّغان تغيّر الخطة، والطاهي لا
  await assertSucceeds(setDoc(doc(q(as('own')), 'b1'), ev('planChanged', { from: 'own', hid: 'h1' })));
  await assertSucceeds(setDoc(doc(q(as('doc')), 'b2'), ev('planChanged', { from: 'doc', hid: 'h1' })));
  await assertFails(setDoc(doc(q(as('cok')), 'b3'), ev('planChanged', { from: 'cok', hid: 'h1' })));
  // طلب ربط بطبيب: أي مسجَّل بكود، ولا حدث مجهول الكود
  await assertSucceeds(setDoc(doc(q(as('own')), 'c1'), ev('doctorRequest', { from: 'own', code: 'AB12CD34', fromName: 'س' })));
  await assertFails(setDoc(doc(q(as('own')), 'c2'), ev('doctorRequest', { from: 'own' })));
  await assertFails(setDoc(doc(q(anon()), 'c3'), ev('doctorRequest', { code: 'AB12CD34' })));
  // «اعتُمد» للمدير وحده
  await assertSucceeds(setDoc(doc(q(as('adm', { admin: true })), 'd1'), ev('doctorApproved', { from: 'adm', toUid: 'doc' })));
  await assertFails(setDoc(doc(q(as('own')), 'd2'), ev('doctorApproved', { from: 'own', toUid: 'doc' })));
  // حقول غريبة مرفوضة، والقراءة للمدير
  await assertFails(setDoc(doc(q(as('own')), 'e1'), ev('planChanged', { from: 'own', hid: 'h1', body: 'نص مزوّر' })));
  await assertFails(getDocs(q(as('own'))));
  await assertSucceeds(getDocs(q(as('adm', { admin: true }))));
});

test('رابط المشتريات: يُقرأ بالرمز، ويعلّم أي حامل «اشتريتُ» فقط، وإنشاؤه وتعديله لصاحبة البيت', async () => {
  const ln = { hid: 'h1', createdBy: 'own', title: 'قائمة', lines: [{ k: 'egg', label: 'بيض', packs: 1 }], bought: {}, createdAt: Timestamp.now() };
  await assertSucceeds(setDoc(doc(as('own'), 'shopLinks/T1'), ln));
  await assertFails(setDoc(doc(as('cok'), 'shopLinks/T2'), { ...ln, createdBy: 'cok' }), 'الطاهي ليس مديراً للبيت');
  await assertFails(setDoc(doc(as('own'), 'shopLinks/T3'), { ...ln, createdBy: 'غيري' }));
  await assertFails(setDoc(doc(anon(), 'shopLinks/T4'), ln));
  await assertSucceeds(getDoc(doc(anon(), 'shopLinks/T1')));
  await assertFails(getDocs(collection(anon(), 'shopLinks')));
  await assertSucceeds(updateDoc(doc(anon(), 'shopLinks/T1'), { 'bought.egg': true, updatedAt: Timestamp.now() }));
  await assertFails(updateDoc(doc(anon(), 'shopLinks/T1'), { title: 'مزوّر' }));
  await assertFails(updateDoc(doc(anon(), 'shopLinks/T1'), { lines: [] }));
  await assertSucceeds(updateDoc(doc(as('own'), 'shopLinks/T1'), { lines: [] }));
  await assertFails(deleteDoc(doc(anon(), 'shopLinks/T1')));
  await assertSucceeds(deleteDoc(doc(as('own'), 'shopLinks/T1')));
});
