class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.spentOn,
    this.note = '',
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime spentOn;
  final String note;

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        title: m['title'] as String,
        category: (m['category'] as String?) ?? 'Other',
        amount: (m['amount'] as num).toDouble(),
        spentOn: DateTime.parse(m['spent_on'] as String),
        note: (m['note'] as String?) ?? '',
      );

  Map<String, dynamic> toWriteMap() => {
        'title': title,
        'category': category,
        'amount': amount,
        'spent_on': spentOn.toIso8601String().substring(0, 10),
        'note': note,
      };

  Map<String, dynamic> toMap() => {'id': id, ...toWriteMap()};
}
