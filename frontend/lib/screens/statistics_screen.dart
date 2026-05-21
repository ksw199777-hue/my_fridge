import 'package:flutter/material.dart';
import '../api_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic> _statistics = {};
  Map<String, dynamic> _monthlyExpenses = {};
  Map<String, dynamic> _expenseHistory = {};
  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats = await ApiService.getStatistics();
    final expenses = await ApiService.getMonthlyExpenses(
        _selectedYear, _selectedMonth);
    final history = await ApiService.getExpenseHistory();
    setState(() {
      _statistics = stats;
      _monthlyExpenses = expenses;
      _expenseHistory = history;
      _isLoading = false;
    });
  }

  String _getMonthName(int month) {
    const months = ['1월', '2월', '3월', '4월', '5월', '6월',
                    '7월', '8월', '9월', '10월', '11월', '12월'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final diff = _expenseHistory['diff_from_last_month'] ?? 0;
    final history = (_expenseHistory['history'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('📊', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('통계', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4A90D9)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 월 선택
                  Row(
                    children: [
                      const Text('📅 조회 월',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _selectedYear,
                        items: [2024, 2025, 2026].map((y) =>
                            DropdownMenuItem(value: y, child: Text('$y년'))).toList(),
                        onChanged: (val) {
                          setState(() => _selectedYear = val!);
                          _loadData();
                        },
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _selectedMonth,
                        items: List.generate(12, (i) => i + 1).map((m) =>
                            DropdownMenuItem(value: m, child: Text(_getMonthName(m)))).toList(),
                        onChanged: (val) {
                          setState(() => _selectedMonth = val!);
                          _loadData();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 이번달 가계부 메인
                  Card(
                    color: const Color(0xFF4A90D9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getMonthName(_selectedMonth)} 식재료비',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_monthlyExpenses['total_expense'] ?? 0}원',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (diff != 0)
                            Row(
                              children: [
                                Icon(
                                  diff > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: diff > 0 ? Colors.redAccent : Colors.greenAccent,
                                  size: 16,
                                ),
                                Text(
                                  '지난달보다 ${diff.abs()}원 ${diff > 0 ? '더 썼어요' : '절약했어요'}',
                                  style: TextStyle(
                                    color: diff > 0 ? Colors.redAccent : Colors.greenAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          if (diff == 0)
                            const Text('지난달 데이터가 없어요',
                                style: TextStyle(color: Colors.white70, fontSize: 13)),

                          // 위치별 지출
                          if (_monthlyExpenses['by_location'] != null &&
                              (_monthlyExpenses['by_location'] as Map).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white30),
                            const SizedBox(height: 8),
                            ...(_monthlyExpenses['by_location'] as Map<String, dynamic>)
                                .entries
                                .map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(e.key,
                                              style: const TextStyle(color: Colors.white70)),
                                          Text('${e.value}원',
                                              style: const TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    )),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 월별 히스토리
                  if (history.isNotEmpty) ...[
                    const Text('📅 월별 식재료비',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: history.reversed.take(6).map((item) {
                            final maxTotal = history
                                .map((h) => h['total'] as int)
                                .reduce((a, b) => a > b ? a : b);
                            final ratio = maxTotal > 0
                                ? (item['total'] as int) / maxTotal
                                : 0.0;
                            final isCurrentMonth =
                                item['month'] == _selectedMonth &&
                                    item['year'] == _selectedYear;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      _getMonthName(item['month'] as int),
                                      style: TextStyle(
                                        fontWeight: isCurrentMonth
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isCurrentMonth
                                            ? const Color(0xFF4A90D9)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ratio.toDouble(),
                                        backgroundColor: Colors.grey.shade100,
                                        color: isCurrentMonth
                                            ? const Color(0xFF4A90D9)
                                            : const Color(0xFFA8D8EA),
                                        minHeight: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      '${item['total']}원',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: isCurrentMonth
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 전체 통계
                  const Text('📦 전체 통계',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: '전체 재료',
                          value: '${_statistics['total']?['count'] ?? 0}개',
                          icon: Icons.kitchen,
                          color: const Color(0xFF4A90D9),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: '버린 재료',
                          value: '${_statistics['expired']?['count'] ?? 0}개',
                          icon: Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: '임박 재료',
                          value: '${_statistics['expiring_soon']?['count'] ?? 0}개',
                          icon: Icons.warning_amber,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: '절약 금액',
                          value: '${_statistics['saved_value'] ?? 0}원',
                          icon: Icons.savings,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 소비기한 임박 재료
                  if ((_statistics['expiring_soon']?['count'] ?? 0) > 0) ...[
                    const Text('⚠️ 소비기한 임박',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...(_statistics['expiring_soon']['ingredients'] as List<dynamic>)
                        .map((item) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: const Color(0xFFFFFDE7),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: const Icon(Icons.warning_amber,
                                    color: Colors.orange),
                                title: Text(item['name']),
                                trailing: Text(
                                  'D-${item['d_day']}',
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            )),
                  ],
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}