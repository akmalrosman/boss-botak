import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../config/shop_config.dart';
import '../../../core/analytics.dart';
import '../../../core/format.dart';
import '../../../core/validators.dart';
import '../../../data/backend.dart';
import '../../../models/expense.dart';
import '../../../state/finance_controller.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

/// Screen 11 - Expense tracking.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  static const _icons = <String, IconData>{
    'Ingredients': Icons.set_meal_outlined,
    'Packaging': Icons.inventory_2_outlined,
    'Transport': Icons.local_gas_station_outlined,
    'Utilities': Icons.bolt_outlined,
    'Marketing': Icons.campaign_outlined,
    'Equipment': Icons.kitchen_outlined,
  };

  static IconData iconFor(String category) => _icons[category] ?? Icons.receipt_outlined;

  Future<void> _add(BuildContext context) async {
    final expense = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExpenseForm(),
    );
    if (expense == null || !context.mounted) return;
    await runWithFeedback(context, () => context.read<FinanceController>().add(expense),
        success: 'Expense added');
  }

  Future<void> _delete(BuildContext context, Expense e) async {
    final finance = context.read<FinanceController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await finance.delete(e);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Deleted "${e.title}"'),
          persist: false,
          action: SnackBarAction(label: 'Undo', onPressed: () => finance.add(e)),
        ));
    } on AppException catch (err) {
      if (context.mounted) showSnack(context, err.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceController>();
    final theme = Theme.of(context);
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(now.year, now.month - 1);
    double sumFrom(DateTime from, [DateTime? to]) => finance.expenses
        .where((e) => !e.spentOn.isBefore(from) && (to == null || e.spentOn.isBefore(to)))
        .fold(0.0, (s, e) => s + e.amount);
    final monthTotal = sumFrom(thisMonth);
    final lastTotal = sumFrom(lastMonth, thisMonth);
    final byCategory = Analytics.expensesByCategory(finance.expenses,
        from: now.subtract(const Duration(days: 30)));

    // Group list by month.
    final groups = <String, List<Expense>>{};
    for (final e in finance.expenses) {
      groups.putIfAbsent(DateFormat('MMMM yyyy').format(e.spentOn), () => []).add(e);
    }

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: finance.loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-expenses',
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: RefreshIndicator(
        onRefresh: finance.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (finance.error != null)
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: ListTile(
                        title: Text(finance.error!,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('This month', style: theme.textTheme.labelLarge),
                              Text(rm(monthTotal), style: theme.textTheme.headlineMedium),
                              Text('Last month: ${rm(lastTotal)}', style: theme.textTheme.bodySmall),
                            ],
                          ),
                          if (byCategory.isNotEmpty) _CategoryPie(data: byCategory),
                        ],
                      ),
                    ),
                  ),
                  if (finance.expenses.isEmpty && !finance.loading)
                    const SizedBox(
                      height: 300,
                      child: EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No expenses yet',
                        message: 'Record ingredients, packaging and petrol to see your real profit.',
                      ),
                    ),
                  for (final g in groups.entries) ...[
                    SectionTitle(g.key,
                        trailing: Text(rm(g.value.fold(0.0, (s, e) => s + e.amount)),
                            style: theme.textTheme.titleSmall)),
                    for (final e in g.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.delete_outline,
                                color: theme.colorScheme.onErrorContainer),
                          ),
                          onDismissed: (_) => _delete(context, e),
                          child: Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Icon(iconFor(e.category))),
                              title: Text(e.title),
                              subtitle: Text('${e.category} · ${formatDate(e.spentOn)}'
                                  '${e.note.isNotEmpty ? '\n${e.note}' : ''}'),
                              isThreeLine: e.note.isNotEmpty,
                              trailing: Text(rm(e.amount), style: theme.textTheme.titleMedium),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPie extends StatelessWidget {
  const _CategoryPie({required this.data});
  final Map<String, double> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.error,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
      scheme.outline,
    ];
    final total = data.values.fold(0.0, (s, v) => s + v);
    final entries = data.entries.toList();
    return Semantics(
      label: 'Expenses by category, last 30 days: '
          '${entries.map((e) => '${e.key} ${rm(e.value)}').join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 110,
              child: PieChart(PieChartData(
                centerSpaceRadius: 26,
                sectionsSpace: 2,
                sections: [
                  for (final (i, e) in entries.indexed)
                    PieChartSectionData(
                      value: e.value,
                      color: colors[i % colors.length],
                      radius: 26,
                      showTitle: false,
                    ),
                ],
              )),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Last 30 days', style: Theme.of(context).textTheme.labelMedium),
                for (final (i, e) in entries.take(5).indexed)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10, color: colors[i % colors.length]),
                    const SizedBox(width: 6),
                    Text('${e.key} ${(e.value / total * 100).round()}%',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = ShopConfig.expenseCategories.first;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New expense', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'What did you pay for?', hintText: 'e.g. Fish paste 10kg'),
                validator: (v) => Validators.required(v, 'Description'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (RM)'),
                    validator: Validators.money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in ShopConfig.expenseCategories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Date'),
                subtitle: Text(formatDate(_date)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    Expense(
                      id: '',
                      title: _title.text.trim(),
                      category: _category,
                      amount: double.parse(_amount.text.trim()),
                      spentOn: _date,
                      note: _note.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Save expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
