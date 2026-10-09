// الدخول الحقيقي: Google على أندرويد وآيفون، وApple على آيفون (Apple إلزامية عند وجود Google).
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../firebase_options.dart';
import 'auth_service.dart';

class FirebaseAuthService extends AuthService {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  AppUser? _user;
  bool _googleReady = false;

  FirebaseAuthService({fb.FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance {
    // الجلسة تُستعاد تلقائياً عند فتح التطبيق، وتتحدّث عند تغيّر الدخول/الخروج
    _auth.authStateChanges().listen((u) async {
      _user = u == null ? null : await _load(u);
      notifyListeners();
    });
  }

  @override
  AppUser? get user => _user;

  @override
  bool isAvailable(SignInMethod m) => switch (m) {
        SignInMethod.google => true,
        SignInMethod.apple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      };

  /// المدير = claim باسم admin يضعه السيرفر لإيميل المدير فقط؛ الطبيب = users/{uid}.isDoctor يمنحه المدير.
  Future<AppUser> _load(fb.User u) async {
    final claims = (await u.getIdTokenResult()).claims ?? {};
    var isDoctor = false;
    try {
      isDoctor = (await _db.collection('users').doc(u.uid).get()).data()?['isDoctor'] == true;
    } catch (_) {}
    return AppUser(
      uid: u.uid,
      name: u.displayName ?? '',
      email: u.email ?? '',
      isAdmin: claims['admin'] == true,
      isDoctor: isDoctor,
    );
  }

  @override
  Future<void> signIn(SignInMethod m) async {
    final cred = switch (m) {
      SignInMethod.google => await _google(),
      SignInMethod.apple => await _apple(),
    };
    await _afterSignIn(cred.user!);
  }

  @override
  bool get supportsPassword => true;

  @override
  Future<void> signInWithPassword(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    await _afterSignIn(cred.user!);
  }

  Future<void> _afterSignIn(fb.User u) async {
    // أول دخول: سجلّ المستخدم. isDoctor يبقى false (القواعد تمنع المستخدم من منح نفسه)
    final ref = _db.collection('users').doc(u.uid);
    if (!(await ref.get()).exists) {
      await ref.set({
        'name': u.displayName ?? '',
        'email': u.email ?? '',
        'isDoctor': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    _user = await _load(u);
    notifyListeners();
  }

  Future<fb.UserCredential> _google() async {
    if (kIsWeb) {
      // الويب: نافذة Google المنبثقة عبر معالج Firebase (النطاق مضاف في Authorized domains)
      try {
        return await _auth.signInWithPopup(fb.GoogleAuthProvider());
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') throw const SignInCancelled();
        rethrow;
      }
    }
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(serverClientId: SufratiFirebase.googleServerClientId);
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('Google لم يُرجع idToken');
      return await _auth.signInWithCredential(fb.GoogleAuthProvider.credential(idToken: idToken));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const SignInCancelled();
      rethrow;
    }
  }

  Future<fb.UserCredential> _apple() async {
    // nonce عشوائي: نرسل hash له لـApple ونعطي Firebase الأصل ليتحقق أن الرمز لم يُعَد استخدامه
    final raw = _nonce();
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(raw)).toString(),
      );
      final cred = await _auth.signInWithCredential(fb.OAuthProvider('apple.com').credential(
        idToken: apple.identityToken, rawNonce: raw, accessToken: apple.authorizationCode));
      // Apple تعطي الاسم في أول دخول فقط — نحفظه
      final name = [apple.givenName, apple.familyName].whereType<String>().join(' ').trim();
      if (name.isNotEmpty && (cred.user?.displayName ?? '').isEmpty) await cred.user!.updateDisplayName(name);
      return cred;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw const SignInCancelled();
      rethrow;
    }
  }

  String _nonce([int n = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// حذف الحساب: سجلّ المستخدم ثم حساب Firebase. قد يطلب Firebase إعادة دخول حديثة (requires-recent-login).
  @override
  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).delete();
    await u.delete();
    await signOut();
  }
}
