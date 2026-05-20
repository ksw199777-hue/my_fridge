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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats = await ApiService.getStatistics();
    final expenses = await ApiService.getMonthlyExpenses(
        DateTime.now().year, DateTime.now().month);
    setState(() {
      _statistics = stats;
      _monthlyExpenses = expenses;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('📊', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('통계',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                  const Text('💰 이번달 식재료비',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('총 지출',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                '${_monthlyExpenses['total_expense'] ?? 0}원',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4A90D9)),
                              ),
                            ],
                          ),
                          const Divider(),
                          if (_monthlyExpenses['by_location'] != null)
                            ...(_monthlyExpenses['by_location'] as Map<String, dynamic>)
                                .entries
                                .map((e) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(e.key),
                                          Text('${e.value}원'),
                                        ],
                                      ),
                                    )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  if ((_statistics['expiring_soon']?['count'] ?? 0) > 0) ...[
                    const Text('⚠️ 소비기한 임박',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...(_statistics['expiring_soon']['ingredients'] as List<dynamic>)
                        .map((item) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: const Color(0xFFFFFDE7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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