import 'package:sufrati/auth/auth_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/events.dart';

import 'fake_auth.dart';

void main() {
  test('طابور الإشعارات: يكتب الحدث بصاحبه، ويطوي المتكرر خلال المهلة، ولا يفعل شيئاً بلا دخول', () async {
    final db = FakeFirebaseFirestore();
    final q = EventQueue.instance;
    final auth = FakeAuthService();
    q.configure(db, auth);
    await q.emit('planChanged', hid: 'h1'); // بلا دخول
    expect((await db.collection('notifyQueue').get()).docs, isEmpty);

    await auth.signIn(SignInMethod.google);
    await q.emit('prepared', hid: 'h1', meal: 'العشاء');
    await q.emit('planChanged', hid: 'h1', throttleKey: 'k1', every: const Duration(minutes: 1));
    await q.emit('planChanged', hid: 'h1', throttleKey: 'k1', every: const Duration(minutes: 1)); // يُطوى
    final docs = (await db.collection('notifyQueue').get()).docs.map((d) => d.data()).toList();
    expect(docs, hasLength(2));
    expect(docs.first['from'], auth.user!.uid);
    expect(docs.any((d) => d['type'] == 'prepared' && d['meal'] == 'العشاء' && d['hid'] == 'h1'), isTrue);
    expect(docs.every((d) => !d.containsKey('code') && !d.containsKey('toUid')), isTrue, reason: 'الحقول الفارغة لا تُكتب');
  });
}
