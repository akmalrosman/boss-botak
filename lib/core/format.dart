import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.currency(symbol: 'RM', decimalDigits: 2);
final NumberFormat _compactMoney = NumberFormat.compactCurrency(symbol: 'RM', decimalDigits: 1);

String rm(num value) => _money.format(value);

String rmCompact(num value) =>
    value.abs() < 1000 ? rm(value) : _compactMoney.format(value);

String formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d.toLocal());

String formatDateTime(DateTime d) =>
    DateFormat('d MMM yyyy, h:mm a').format(d.toLocal());

String formatShortDate(DateTime d) => DateFormat('d/M').format(d.toLocal());

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// Normalises a Malaysian phone number to international format (60XXXXXXXXX).
String normalisePhone(String phone) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) digits = '6$digits';
  if (!digits.startsWith('60') && digits.isNotEmpty) digits = '60$digits';
  return digits;
}
