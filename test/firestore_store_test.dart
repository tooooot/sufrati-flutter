import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/data/firestore_store.dart';
import 'package:sufrati/data/repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(FakeFirebaseFirestore, Library)> setup() async {
    final db = FakeFirebaseFirestore();
    await db.doc('households/h1').set({'label': 'بيت', 'programId': 'kidney_salama', 'eaters': 2, 'members': {'own': 'owner', 'cok': 'cook'}});
    return (db, await Library.load());
  }

  final ws = DateTime(2026, 10, 3); // سبت

  test('مدير البيت يولّد الأسبوع مرة واحدة ويُحفظ، والطاهي يقرأ نفس الخطة', () async {
    final (db, lib) = await setup();
    final owner = await FirestoreStore.open(db, lib, 'h1', canManage: true);
    final plan = await owner.week(ws);
    expect(plan.days.length, 7);
    expect(plan.days.every((d) => d.isNotEmpty), isTrue);
    expect((await db.doc('households/h1/weeks/2026-10-03').get()).exists, isTrue);

    final cook = await FirestoreStore.open(db, lib, 'h1', canManage: false);
    final seen = await cook.week(ws);
    expect(seen.days.first, plan.days.first, reason: 'الطاهي يرى نفس الخطة');
  });

  test('الطاهي قبل تجهيز الخطة: PlanNotReady ولا يكتب شيئاً', () async {
    final (db, lib) = await setup();
    final cook = await FirestoreStore.open(db, lib, 'h1', canManage: false);
    await expectLater(cook.week(ws), throwsA(isA<PlanNotReady>()));
    expect((await db.collection('households/h1/weeks').get()).docs, isEmpty);
  });

  test('«جاهز» يُحفظ ويظهر للجميع، والتراجع يعمل', () async {
    final (db, lib) = await setup();
    final owner = await FirestoreStore.open(db, lib, 'h1', canManage: true);
    await owner.week(ws);
    final cook = await FirestoreStore.open(db, lib, 'h1', canManage: false);
    await cook.setPrepared(ws, 0, 'lunch', true);
    expect(((await db.doc('households/h1/weeks/2026-10-03').get()).data()!['prepared'] as List), contains('0:lunch'));
    await cook.setPrepared(ws, 0, 'lunch', false);
    expect(((await db.doc('households/h1/weeks/2026-10-03').get()).data()!['prepared'] as List), isEmpty);
  });

  test('المشتريات تُحسب وتُحفظ ويُحفظ تعديل العبوات و«تم الشراء»', () async {
    final (db, lib) = await setup();
    final owner = await FirestoreStore.open(db, lib, 'h1', canManage: true);
    await owner.week(ws);
    final lines = await owner.shopping(ws);
    expect(lines, isNotEmpty);
    final first = lines.first;
    final before = first.packs;
    await owner.updateShopping(ws, first.key, packs: before + 2, bought: true);
    final saved = (await db.doc('households/h1/shopping/2026-10-03').get()).data()!['lines'] as Map;
    expect((saved[first.key] as Map)['packs'], before + 2);
    expect((saved[first.key] as Map)['bought'], true);
  });

  test('تعديل وجبة يغيّر الخطة المحفوظة', () async {
    final (db, lib) = await setup();
    final owner = await FirestoreStore.open(db, lib, 'h1', canManage: true);
    final plan = await owner.week(ws);
    final slot = plan.days[1].keys.first;
    final prog = await owner.program();
    final other = prog.slots.firstWhere((s) => s.id == slot).options.map((o) => o.id).firstWhere((id) => id != plan.days[1][slot]);
    await owner.setOption(ws, 1, slot, other);
    final days = (await db.doc('households/h1/weeks/2026-10-03').get()).data()!['days'] as List;
    expect((days[1] as Map)[slot], other);
  });
}
