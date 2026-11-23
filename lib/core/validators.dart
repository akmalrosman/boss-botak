class Validators {
  Validators._();

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _myPhone = RegExp(r'^(\+?6?01)[0-9]-?[0-9]{7,8}$');

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    return _email.hasMatch(v.trim()) ? null : 'Enter a valid email address';
  }

  /// Strong-ish password for new accounts: 8+ chars with letters and digits.
  static String? newPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Use a mix of letters and numbers';
    }
    return null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final cleaned = v.replaceAll(RegExp(r'[\s()]'), '');
    return _myPhone.hasMatch(cleaned)
        ? null
        : 'Enter a Malaysian mobile number, e.g. 012-3456789';
  }

  static String? money(String? v, {bool allowZero = false}) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter an amount';
    if (n < 0 || (!allowZero && n == 0)) return 'Amount must be more than 0';
    return null;
  }

  static String? wholeNumber(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 0) return 'Enter a whole number (0 or more)';
    return null;
  }
}
