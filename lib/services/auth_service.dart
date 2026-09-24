import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../data/local/local_storage_service.dart';
import '../data/remote/api_client.dart';
import '../models/user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    _currentUser = LocalStorageService().loadUser();
  }

  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  User? _currentUser;
  String? _verificationId;
  fb.ConfirmationResult? _webConfirmationResult;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> sendOtp(String phone) async {
    if (kIsWeb) {
      _webConfirmationResult = await _firebaseAuth.signInWithPhoneNumber(phone);
      return;
    }

    final completer = Completer<void>();
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(e.message ?? 'Échec de vérification.'));
        }
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  Future<User> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    fb.UserCredential credential;

    if (kIsWeb) {
      if (_webConfirmationResult == null) {
        throw Exception('Aucun code envoyé pour ce numéro.');
      }
      credential = await _webConfirmationResult!.confirm(otp);
    } else {
      if (_verificationId == null) {
        throw Exception('Aucun code envoyé pour ce numéro.');
      }
      final phoneCredential = fb.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      credential = await _firebaseAuth.signInWithCredential(phoneCredential);
    }

    final idToken = await credential.user!.getIdToken();
    final response = await ApiClient().post('/auth/firebase-verify', {
      'idToken': idToken,
      'phone': phone,
    });

    final user = User.fromJson(response['user'] as Map<String, dynamic>);
    final token = response['access_token'] as String;

    await LocalStorageService().saveToken(token);
    _currentUser = user;
    await LocalStorageService().saveUser(user);
    return user;
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    _currentUser = null;
    await LocalStorageService().clearSession();
  }
}
