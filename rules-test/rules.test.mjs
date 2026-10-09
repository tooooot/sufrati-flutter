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
