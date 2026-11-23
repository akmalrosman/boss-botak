import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/features.dart';
import '../../../core/analytics.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/finance_controller.dart';
import '../../../state/orders_controller.dart';
import '../../../state/session_controller.dart';
import '../../widgets/adaptive_nav.dart';
import '../../widgets/common.dart';
import 'admin_shell.dart';

/// Screen 8 - Financial dashboard (sales, expenses, profit/loss, analytics,
/// low-stock alerts).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ReportPeriod _period = ReportPeriod.month;

  Future<void> _refresh() async {
    final userId = context.read<SessionController>().user!.id;
    await Future.wait([
      context.read<OrdersController>().load(userId),
      if (Features.expenses) context.read<FinanceController>().load(),
      context.read<CatalogController>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersController>();
    final finance = context.watch<FinanceController>();
    final catalog = context.watch<CatalogController>();
    final user = context.watch<SessionController>().user;
    final now = DateTime.now();
    final from = _period.start(now);

    final summary = Analytics.summarise(
        orders: orders.orders,
        expenses: Features.expenses ? finance.expenses : const [],
        from: from);
    final series = Analytics.salesSeries(orders.orders, _period, now);
    final top = Analytics.topProducts(orders.orders, from: from);
    final lowStock = catalog.lowStock;
    final theme = Theme.of(context);
    final loading = orders.loading || finance.loading;

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      floatingActionButton: !Features.recordSale
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-dashboard',
              onPressed: () => openNewSale(context),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Record sale'),
            ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            ContentWidth(
              maxWidth: 1100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OfflineBanner(visible: orders.offline, onRetry: _refresh),
                  Text('Selamat datang, ${(user?.fullName ?? 'Boss').split(' ').first}!',
                      style: theme.textTheme.headlineSmall),
                  Text('Here is how the business is doing.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  SegmentedButton<ReportPeriod>(
                    segments: [
                      for (final p in ReportPeriod.values)
                        ButtonSegment(value: p, label: Text(p.label)),
                    ],
                    selected: {_period},
                    onSelectionChanged: (s) => setState(() => _period = s.first),
                  ),
                  const SizedBox(height: 16),
                  _KpiGrid(summary: summary),
                  if (orders.pendingCount > 0) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: theme.colorScheme.tertiaryContainer,
                      child: ListTile(
                        leading: Icon(Icons.notifications_active_outlined,
                            color: theme.colorScheme.onTertiaryContainer),
                        title: Text('${orders.pendingCount} new order(s) waiting for confirmation',
                            style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
                        trailing: Icon(Icons.chevron_right,
                            color: theme.colorScheme.onTertiaryContainer),
                        onTap: () => context.read<ShellNavigator>().go(AdminTabs.orders),
                      ),
                    ),
                  ],
                  const SectionTitle('Sales trend'),
                  _SalesChart(points: series),
                  LayoutBuilder(builder: (context, c) {
                    final cards = [
                      _ProfitBreakdown(summary: summary),
                      _TopProducts(items: top),
                    ];
                    if (c.maxWidth < 760) {
                      return Column(children: [
                        for (final w in cards) ...[const SizedBox(height: 16), w],
                      ]);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 16),
                            Expanded(child: cards[1]),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SectionTitle('Low-stock alerts'),
                  if (lowStock.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('All products have enough stock'),
                      ),
                    )
                  else
                    Card(
                      child: Column(children: [
                        for (final p in lowStock)
                          ListTile(
                            leading: Icon(
                              p.isOutOfStock ? Icons.error_outline : Icons.warning_amber_rounded,
                              color: p.isOutOfStock ? theme.colorScheme.error : BrandColors.warning,
                            ),
                            title: Text(p.name),
                            subtitle: Text(p.isOutOfStock
                                ? 'Out of stock'
                                : '${p.stock} left (alert at ${p.lowStockThreshold})'),
                            trailing: TextButton(
                              onPressed: () => context.read<ShellNavigator>().go(AdminTabs.inventory),
                              child: const Text('Restock'),
                            ),
                          ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.summary});
  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profitPositive = summary.netProfit >= 0;
    final tiles = [
      _Kpi('Sales', rm(summary.revenue), Icons.payments_outlined,
          '${summary.itemsSold} packs sold', scheme.primaryContainer, scheme.onPrimaryContainer),
      _Kpi(
          // Without the Expenses module only gross profit can be calculated.
          Features.expenses ? 'Net profit' : 'Gross profit',
          rm(summary.netProfit),
          profitPositive ? Icons.trending_up : Icons.trending_down,
          '${(summary.profitMargin * 100).toStringAsFixed(0)}% margin',
          profitPositive ? scheme.secondaryContainer : scheme.errorContainer,
          profitPositive ? scheme.onSecondaryContainer : scheme.onErrorContainer),
      _Kpi('Orders', '${summary.orderCount}', Icons.receipt_long_outlined,
          'Avg ${rm(summary.averageOrderValue)}', scheme.surfaceContainerHighest, scheme.onSurface),
      if (Features.expenses)
        _Kpi('Expenses', rm(summary.expenses), Icons.account_balance_wallet_outlined,
            'Unpaid sales ${rm(summary.unpaidAmount)}', scheme.tertiaryContainer,
            scheme.onTertiaryContainer)
      else
        _Kpi('Awaiting payment', rm(summary.unpaidAmount), Icons.hourglass_bottom,
            'Not yet paid or verified', scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ];
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 760 ? 4 : 2;
      final width = (c.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final t in tiles) SizedBox(width: width, child: t)],
      );
    });
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, this.caption, this.bg, this.fg);
  final String label;
  final String value;
  final IconData icon;
  final String caption;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label $value, $caption',
      child: ExcludeSemantics(
        child: Card(
          color: bg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, color: fg, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: fg))),
                ]),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 2),
                Text(caption,
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.points});
  final List<SalesPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = points.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    final total = points.fold<double>(0, (s, p) => s + p.value);
    final labelEvery = points.length > 12 ? (points.length / 6).ceil() : 1;
    final best = points.isEmpty
        ? null
        : points.reduce((a, b) => b.value > a.value ? b : a);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        child: Semantics(
          label: 'Sales chart. Total ${rm(total)}.'
              '${best != null && best.value > 0 ? ' Best: ${best.label} with ${rm(best.value)}.' : ''}',
          child: ExcludeSemantics(
            child: SizedBox(
              height: 220,
              child: maxY == 0
                  ? const Center(child: Text('No sales in this period yet'))
                  : BarChart(
                      BarChartData(
                        maxY: maxY * 1.15,
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: scheme.outlineVariant, strokeWidth: 0.6),
                        ),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => scheme.inverseSurface,
                            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                              '${points[group.x].label}\n${rm(rod.toY)}',
                              TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (v, meta) => v == meta.max
                                  ? const SizedBox.shrink()
                                  : SideTitleWidget(
                                      meta: meta,
                                      child: Text(_axisLabel(v), style: const TextStyle(fontSize: 10)),
                                    ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i % labelEvery != 0 || i >= points.length) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(points[i].label, style: const TextStyle(fontSize: 10)),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < points.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                toY: points[i].value,
                                width: points.length > 12 ? 6 : 16,
                                color: scheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ]),
                        ],
                      ),
                      duration: const Duration(milliseconds: 400),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _axisLabel(double v) =>
    v >= 1000 ? 'RM${(v / 1000).toStringAsFixed(1)}k' : 'RM${v.round()}';

class _ProfitBreakdown extends StatelessWidget {
  const _ProfitBreakdown({required this.summary});
  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget row(String label, double value, {bool strong = false, bool minus = false}) {
      final style = strong ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: style)),
          Text(minus ? '- ${rm(value)}' : rm(value),
              style: style?.copyWith(
                  color: strong ? (value >= 0 ? scheme.primary : scheme.error) : null)),
        ]),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profit & loss', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            row('Sales', summary.revenue),
            row('Cost of goods sold', summary.costOfGoods, minus: true),
            const Divider(),
            row('Gross profit', summary.grossProfit, strong: true),
            if (Features.expenses) ...[
              row('Operating expenses', summary.expenses, minus: true),
              const Divider(),
              row(summary.netProfit >= 0 ? 'Net profit' : 'Net loss', summary.netProfit,
                  strong: true),
            ] else
              Text('Before operating expenses', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.items});
  final List<ProductSales> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = items.isEmpty ? 1.0 : items.first.revenue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Best sellers', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty) const Text('No sales yet in this period.'),
            for (final (i, p) in items.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('${i + 1}. ', style: theme.textTheme.titleSmall),
                      Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                      Text(rm(p.revenue), style: theme.textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 4),
                    Semantics(
                      label: '${p.quantity} packs sold',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: p.revenue / max, minHeight: 6),
                      ),
                    ),
                    Text('${p.quantity} packs', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
