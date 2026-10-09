import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/auth_service.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/data/firestore_links.dart';

import 'fake_auth.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

Future<(FirestoreLinkService, FakeAuthService)> user(FakeFirebaseFirestore db, String uid) async {
  final auth = FakeAuthService(uid: uid);
  await db.doc('users/$uid').set({'isDoctor': false, 'name': uid});
  final links = FirestoreLinkService(db, auth);
  await auth.signIn(SignInMethod.google);
  await settle();
  return (links, auth);
}

void main() {
  test('صاحب البيت ينشئ بيتاً ثم يدعو الطاهي فينضم برمز يعمل مرة واحدة', () async {
    final db = FakeFirebaseFirestore();
    final (owner, _) = await user(db, 'u-owner');
    expect(owner.ready, isTrue);
    expect(owner.memberships, isEmpty);

    await owner.createHousehold('بيت أبو عبدالله', 'kidney_salama', 2);
    await settle();
    expect(owner.hasHousehold, isTrue);
    expect(owner.label, 'بيت أبو عبدالله');

    final inv = await owner.createInvite(Role.cook);
    await settle();
    expect(inv.code.length, 6);
    expect(owner.inviteFor(Role.cook)?.code, inv.code);

    final (cook, _) = await user(db, 'u-cook');
    expect(await cook.redeem('${inv.code.toLowerCase()} ', Role.doctor), contains('مخصّص'), reason: 'الدور يجب أن يطابق');
    expect(await cook.redeem('ZZZZZZ', Role.cook), contains('غير صحيح'));
    expect(await cook.redeem(inv.code, Role.cook, who: 'ماريا'), isNull);
    await settle();
    expect(cook.membershipOf(Role.cook)?.householdLabel, 'بيت أبو عبدالله');
    expect(owner.joinedBy(Role.cook)?.usedBy, 'ماريا', reason: 'صاحب البيت يرى من انضم');
    expect(owner.inviteFor(Role.cook), isNull);

    final (late, _) = await user(db, 'u-late');
    expect(await late.redeem(inv.code, Role.cook), contains('استُخدم'));
  });

  test('الطبيب لا يُفعَّل بالاختيار: طلب ثم تفعيل المدير', () async {
    final db = FakeFirebaseFirestore();
    final (doc, _) = await user(db, 'u-doc');
    expect(doc.isDoctor, isFalse);
    await doc.requestDoctor();
    await settle();
    expect(doc.doctorRequested, isTrue);
    expect(doc.isDoctor, isFalse);
    await db.doc('users/u-doc').update({'isDoctor': true, 'doctorRequested': false}); // المدير
    await settle();
    expect(doc.isDoctor, isTrue);
  });

  test('الدور المقترح من الارتباطات: صاحب بيت ثم طبيب ثم طاهٍ', () async {
    final db = FakeFirebaseFirestore();
    final (u, _) = await user(db, 'u-owner');
    expect(u.suggestedRole, isNull);
    await u.createHousehold('بيتي', 'keto_general', 1);
    await settle();
    expect(u.suggestedRole, Role.owner);
  });

  test('حذف البيانات يمسح البيت وخططه ودعواته ويخرج العضو من بيوت الآخرين', () async {
    final db = FakeFirebaseFirestore();
    final (owner, _) = await user(db, 'u-owner');
    await owner.createHousehold('بيت', 'keto_general', 1);
    await settle();
    final hid = owner.membershipOf(Role.owner)!.householdId;
    await db.doc('households/$hid/weeks/2026-10-03').set({'days': [], 'prepared': []});
    final inv = await owner.createInvite(Role.cook);
    final (cook, _) = await user(db, 'u-cook');
    await cook.redeem(inv.code, Role.cook);
    await settle();

    await cook.deleteMyData();
    await settle();
    expect(((await db.doc('households/$hid').get()).data()!['members'] as Map).containsKey('u-cook'), isFalse);

    await owner.deleteMyData();
    await settle();
    expect((await db.doc('households/$hid').get()).exists, isFalse);
    expect((await db.collection('households/$hid/weeks').get()).docs, isEmpty);
    expect((await db.doc('invites/${inv.code}').get()).exists, isFalse);
  });
}
