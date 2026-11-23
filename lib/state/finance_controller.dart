import 'package:flutter/foundation.dart';

import '../data/backend.dart';
import '../models/app_user.dart';
import '../models/expense.dart';

/// Owner-only data: expenses and registered customer profiles.
class FinanceController extends ChangeNotifier {
  FinanceController(this.backend);

  final Backend backend;

  List<Expense> _expenses = [];
  List<AppUser> _profiles = [];
  bool _loading = false;
  String? _error;

  List<Expense> get expenses => _expenses;
  List<AppUser> get customerProfiles => _profiles;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        backend.fetchExpenses(),
        backend.fetchCustomerProfiles(),
      ]);
      _expenses = results[0] as List<Expense>;
      _profiles = results[1] as List<AppUser>;
    } on AppException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add(Expense e) async {
    final saved = await backend.addExpense(e);
    _expenses = [saved, ..._expenses]
      ..sort((a, b) => b.spentOn.compareTo(a.spentOn));
    notifyListeners();
  }

  /// Removes immediately for a snappy UI and restores it if the server fails.
  Future<void> delete(Expense e) async {
    _expenses = _expenses.where((x) => x.id != e.id).toList();
    notifyListeners();
    try {
      await backend.deleteExpense(e.id);
    } catch (_) {
      _expenses = [..._expenses, e]..sort((a, b) => b.spentOn.compareTo(a.spentOn));
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _expenses = [];
    _profiles = [];
    notifyListeners();
  }
}
