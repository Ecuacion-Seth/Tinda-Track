import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import 'monthly_report_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;

  int _totalItems = 0;
  int _lowStockItems = 0;
  double _todaysRevenue = 0.0;

  List<double> _chartData = List.filled(10, 0.0);
  List<String> _chartDays = [];
  double _maxChartValue = 0.0;

  List<Map<String, dynamic>> _smartInsights = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    _totalItems = await db.getTotalItemsCount();
    _lowStockItems = await db.getLowStockCount();
    _todaysRevenue = await db.getTodaysRevenue();

    final rawSales = await db.getSalesLast7Days();
    final now = DateTime.now();

    _chartDays = List.generate(10, (index) {
      if (index < 7) {
        return DateFormat('E').format(now.subtract(Duration(days: 6 - index)));
      } else {
        return DateFormat('E').format(now.add(Duration(days: index - 6)));
      }
    });

    _chartData = List.filled(10, 0.0);
    for (var sale in rawSales) {
      final saleDate = DateTime.parse(sale['sold_at'] as String);
      final difference = DateTime(now.year, now.month, now.day)
          .difference(DateTime(saleDate.year, saleDate.month, saleDate.day))
          .inDays;
      if (difference >= 0 && difference <= 6) {
        _chartData[6 - difference] += (sale['total_price'] as num).toDouble();
      }
    }

    if (_chartData.length >= 7) {
      double d1 = (_chartData[4] + _chartData[5] + _chartData[6]) / 3;
      double d2 = (_chartData[5] + _chartData[6] + d1) / 3;
      double d3 = (_chartData[6] + d1 + d2) / 3;
      _chartData[7] = d1;
      _chartData[8] = d2;
      _chartData[9] = d3;
    }

    _maxChartValue = _chartData.reduce(
      (curr, next) => curr > next ? curr : next,
    );
    _maxChartValue = _maxChartValue == 0 ? 100 : _maxChartValue * 1.2;

    _smartInsights.clear();

    // A. Seasonal Recommendations
    final currentMonth = now.month;
    final seasons = await db.getSeasonalRecommendations(currentMonth);
    for (var season in seasons) {
      int urgency = season['urgency'] as int;
      int tier = urgency == 3 ? 1 : (urgency == 2 ? 2 : 3);
      Color color = urgency == 3
          ? Colors.red.shade600
          : (urgency == 2 ? Colors.orange.shade500 : Colors.blue.shade500);

      _smartInsights.add({
        'tier': tier,
        'icon': Icons.event_available,
        'color': color,
        'title': 'Prepare for ${season['event_name']}',
        'subtitle':
            'Stock up on ${season['product_name']}. ${season['reason']}',
      });
    }

    // B. Trajectory Modeling (Week-over-Week)
    final weeklyRaw = await db.getSalesLast28Days();
    Map<String, Map<int, int>> itemWeeklySales = {};
    Map<String, String> itemNames = {};

    for (var row in weeklyRaw) {
      String itemId = row['item_id'];
      String name = row['name'];
      int qty = (row['quantity_sold'] as num).toInt();
      itemNames[itemId] = name;

      final saleDate = DateTime.parse(row['sold_at'] as String);
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(saleDate.year, saleDate.month, saleDate.day))
          .inDays;

      int weekIndex = diff ~/ 7;

      itemWeeklySales.putIfAbsent(itemId, () => {0: 0, 1: 0, 2: 0, 3: 0});
      itemWeeklySales[itemId]![weekIndex] =
          (itemWeeklySales[itemId]![weekIndex] ?? 0) + qty;
    }

    itemWeeklySales.forEach((id, weeks) {
      int w0 = weeks[0] ?? 0;
      int w1 = weeks[1] ?? 0;

      if (w1 > 0) {
        double pctChange = ((w0 - w1) / w1) * 100;
        if (pctChange >= 30 && w0 > 5) {
          _smartInsights.add({
            'tier': 3,
            'icon': Icons.auto_graph,
            'color': Colors.blue.shade500,
            'title': '${itemNames[id]} trajectory rising',
            'subtitle':
                'Sales up ${pctChange.toStringAsFixed(0)}% week-over-week. Projected demand increase next 7 days.',
          });
        } else if (pctChange <= -40 && w1 > 10) {
          _smartInsights.add({
            'tier': 2,
            'icon': Icons.trending_down,
            'color': Colors.orange.shade500,
            'title': '${itemNames[id]} trajectory slowing',
            'subtitle':
                'Velocity dropped by ${pctChange.abs().toStringAsFixed(0)}%. Avoid overstocking.',
          });
        }
      }
    });

    // C. Depletion Engine (Velocity)
    final velocityData = await db.getItemVelocity();
    for (var item in velocityData) {
      final int qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final int weeklySales = (item['weekly_sales'] as num?)?.toInt() ?? 0;

      if (weeklySales > 0) {
        double dailyBurnRate = weeklySales / 7.0;
        double daysLeft = qty / dailyBurnRate;
        if (daysLeft <= 3.0 && qty > 0) {
          _smartInsights.add({
            'tier': 1,
            'icon': Icons.hourglass_bottom,
            'color': Colors.red.shade600,
            'title': '${item['name']} depleting fast',
            'subtitle':
                'At current burn rate, stock runs out in ${daysLeft.toStringAsFixed(1)} days.',
          });
        }
      } else if (qty == 0) {
        _smartInsights.add({
          'tier': 1,
          'icon': Icons.error_outline,
          'color': Colors.red.shade700,
          'title': '${item['name']} out of stock',
          'subtitle': 'You are losing potential sales. Restock immediately.',
        });
      }
    }

    _smartInsights.sort(
      (a, b) => (a['tier'] as int).compareTo(b['tier'] as int),
    );

    if (_smartInsights.length > 6) {
      _smartInsights = _smartInsights.sublist(0, 6);
    }

    setState(() => _isLoading = false);
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insert_chart_outlined),
            tooltip: 'Monthly Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MonthlyReportScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildSummaryCard(
                    'Total Items',
                    _totalItems.toString(),
                    Icons.inventory_2,
                    Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  _buildSummaryCard(
                    'Low Stock',
                    _lowStockItems.toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildSummaryCard(
                    "Today",
                    '₱${_todaysRevenue.toStringAsFixed(0)}',
                    Icons.payments,
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Revenue Forecast',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Past',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 12,
                        height: 12,
                        color: Colors.teal.shade200,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Projected',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _maxChartValue,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= _chartDays.length)
                              return const SizedBox.shrink();

                            final isFuture = index > 6;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _chartDays[index],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isFuture
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isFuture
                                      ? Colors.teal
                                      : Colors.grey.shade700,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(10, (index) {
                      final isFuture = index > 6;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: _chartData[index],
                            color: isFuture
                                ? Colors.teal.shade200
                                : Colors.amber.shade700,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Smart Insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_smartInsights.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Data normalizing. Check back tomorrow for trends.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _smartInsights.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final insight = _smartInsights[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (insight['color'] as Color)
                              .withOpacity(0.1),
                          child: Icon(
                            insight['icon'] as IconData,
                            color: insight['color'] as Color,
                          ),
                        ),
                        title: Text(
                          insight['title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(insight['subtitle']),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
