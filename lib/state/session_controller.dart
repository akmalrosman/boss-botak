import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../models/app_user.dart';

enum AuthStatus { loading, signedOut, signedIn }

class SessionController extends ChangeNotifier {
  SessionController(this.backend);

  final Backend backend;

  AuthStatus _status = AuthStatus.loading;
  AppUser? _user;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isAdmin => _user?.isAdmin ?? false;

  Future<void> restore() async {
    _user = await backend.restoreSession();
    _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _user = await backend.signIn(email: email, password: password);
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signUp({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    _user = await backend.signUp(
        fullName: fullName, phone: phone, email: email, password: password);
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) => backend.sendPasswordReset(email);

  Future<void> updateProfile(AppUser updated) async {
    _user = await backend.updateProfile(updated);
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await backend.signOut();
    } finally {
      _user = null;
      _status = AuthStatus.signedOut;
      notifyListeners();
    }
  }
}
