import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  double _totalRevenue = 0.0;
  int _unitsSold = 0;
  int _transactionCount = 0;
  String _topItemName = 'N/A';
  int _topItemQty = 0;

  List<double> _dailyData = [];
  double _maxDaily = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final int year = _selectedDate.year;
    final int month = _selectedDate.month;

    final summary = await db.getMonthlySalesSummary(year, month);
    _totalRevenue = (summary['revenue'] as num?)?.toDouble() ?? 0.0;
    _unitsSold = (summary['units'] as num?)?.toInt() ?? 0;
    _transactionCount = (summary['trans_count'] as num?)?.toInt() ?? 0;

    final topItem = await db.getTopItemForMonth(year, month);
    if (topItem != null) {
      _topItemName = topItem['name'] as String;
      _topItemQty = (topItem['total_qty'] as num).toInt();
    } else {
      _topItemName = 'No Sales';
      _topItemQty = 0;
    }

    final int daysInMonth = DateUtils.getDaysInMonth(year, month);
    _dailyData = List.filled(daysInMonth, 0.0);

    final dailyRaw = await db.getDailySalesForMonth(year, month);
    for (var row in dailyRaw) {
      int dayIndex = (int.tryParse(row['day'] as String? ?? '0') ?? 1) - 1;
      if (dayIndex >= 0 && dayIndex < _dailyData.length) {
        _dailyData[dayIndex] = (row['daily_total'] as num).toDouble();
      }
    }

    _maxDaily = _dailyData.isEmpty
        ? 100
        : _dailyData.reduce((a, b) => a > b ? a : b) * 1.2;
    if (_maxDaily == 0) _maxDaily = 100;

    setState(() => _isLoading = false);
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + offset,
        1,
      );
    });
    _loadMonthData();
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Report')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      _selectedDate.month == DateTime.now().month &&
                          _selectedDate.year == DateTime.now().year
                      ? null
                      : () => _changeMonth(1),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.5,
                      children: [
                        _buildSummaryCard(
                          'Revenue',
                          '₱${_totalRevenue.toStringAsFixed(0)}',
                          Icons.payments,
                          Colors.green,
                        ),
                        _buildSummaryCard(
                          'Units Sold',
                          _unitsSold.toString(),
                          Icons.shopping_bag,
                          Colors.blue,
                        ),
                        _buildSummaryCard(
                          'Transactions',
                          _transactionCount.toString(),
                          Icons.receipt,
                          Colors.purple,
                        ),
                        _buildSummaryCard(
                          'Top Item',
                          '$_topItemName\n($_topItemQty)',
                          Icons.star,
                          Colors.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Daily Revenue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 250,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _maxDaily,
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget:
                                    (double value, TitleMeta meta) {
                                      if (value % 5 != 0)
                                        return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          '${value.toInt() + 1}',
                                          style: const TextStyle(fontSize: 10),
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
                          barGroups: List.generate(_dailyData.length, (index) {
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: _dailyData[index],
                                  color: Colors.amber.shade600,
                                  width: 8,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
