import 'package:flutter_test/flutter_test.dart';
import 'package:sufrati/auth/auth_service.dart';
import 'package:sufrati/auth/roles.dart';
import 'package:sufrati/auth/session.dart';

void main() {
  test('الدخول أولاً ثم الدور، والخروج ينسى الدور', () async {
    final auth = FakeAuthService();
    final s = Session(auth);
    expect(s.signedIn, isFalse);
    expect(s.needsRole, isFalse, reason: 'بلا دخول لا يُسأل عن الدور');

    await auth.signIn(SignInMethod.google);
    expect(s.signedIn, isTrue);
    expect(s.needsRole, isTrue, reason: 'بعد الدخول يظهر اختيار الدور');

    s.chooseRole(Role.cook);
    expect(s.needsRole, isFalse);
    expect(s.role, Role.cook);

    await auth.signOut();
    expect(s.role, isNull);
    await auth.signIn(SignInMethod.apple);
    expect(s.needsRole, isTrue, reason: 'دخول جديد ← يُسأل عن الدور من جديد');
  });

  test('Apple غير متاح على أندرويد فيظهر Google فقط', () {
    final a = FakeAuthService(apple: false);
    expect(a.isAvailable(SignInMethod.google), isTrue);
    expect(a.isAvailable(SignInMethod.apple), isFalse);
  });
}
