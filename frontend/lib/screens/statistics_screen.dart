import 'package:flutter/material.dart';
import '../api_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, dynamic> _monthlyExpenses = {};
  Map<String, dynamic> _expenseHistory = {};
  Map<String, dynamic> _budget = {};
  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  final _budgetController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isEditingBudget = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final expenses = await ApiService.getMonthlyExpenses(_selectedYear, _selectedMonth);
    final history = await ApiService.getExpenseHistory();
    final budget = await ApiService.getBudget(_selectedYear, _selectedMonth);
    setState(() {
      _monthlyExpenses = expenses;
      _expenseHistory = history;
      _budget = budget;
      _budgetController.text = budget['budget'].toString() == '0' ? '' : budget['budget'].toString();
      _memoController.text = budget['memo'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveBudget() async {
    final budget = int.tryParse(_budgetController.text) ?? 0;
    await ApiService.setBudget(
      _selectedYear,
      _selectedMonth,
      budget,
      _memoController.text,
    );
    setState(() => _isEditingBudget = false);
    _loadData();
  }

  String _getMonthName(int month) {
    const months = ['1월', '2월', '3월', '4월', '5월', '6월',
                    '7월', '8월', '9월', '10월', '11월', '12월'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final history = (_expenseHistory['history'] as List<dynamic>?) ?? [];
    final thisMonthTotal = _monthlyExpenses['total_expense'] ?? 0;
    final budgetAmount = _budget['budget'] ?? 0;
    final diff = thisMonthTotal - budgetAmount;
    final lastMonthDiff = _expenseHistory['diff_from_last_month'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('📒', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('식재료 가계부',
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
                  // 월 선택
                  Row(
                    children: [
                      const Text('📅 조회 월',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: _selectedYear,
                        items: [2024, 2025, 2026].map((y) =>
                            DropdownMenuItem(
                                value: y, child: Text('$y년'))).toList(),
                        onChanged: (val) {
                          setState(() => _selectedYear = val!);
                          _loadData();
                        },
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _selectedMonth,
                        items: List.generate(12, (i) => i + 1).map((m) =>
                            DropdownMenuItem(
                                value: m,
                                child: Text(_getMonthName(m)))).toList(),
                        onChanged: (val) {
                          setState(() => _selectedMonth = val!);
                          _loadData();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 이번달 지출 현황
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A90D9), Color(0xFF357ABD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedYear}년 ${_getMonthName(_selectedMonth)} 식재료비',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${thisMonthTotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (lastMonthDiff != 0)
                          Text(
                            lastMonthDiff > 0
                                ? '지난달보다 ${lastMonthDiff.abs().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원 더 썼어요 📈'
                                : '지난달보다 ${lastMonthDiff.abs().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원 절약했어요 📉',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 예산 관리
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('💰 이번달 예산',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              TextButton(
                                onPressed: () => setState(
                                    () => _isEditingBudget = !_isEditingBudget),
                                child: Text(_isEditingBudget ? '취소' : '편집'),
                              ),
                            ],
                          ),
                          if (_isEditingBudget) ...[
                            TextField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '예산 (원)',
                                border: OutlineInputBorder(),
                                suffixText: '원',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _memoController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: '메모 (계획, 다이어리 등)',
                                hintText: '이번달 장보기 계획을 자유롭게 적어보세요!\n예) 고기 위주로 구매, 과일 줄이기...',
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _saveBudget,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A90D9),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('저장'),
                              ),
                            ),
                          ] else ...[
                            if (budgetAmount > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('예산'),
                                  Text(
                                    '${budgetAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('실지출'),
                                  Text(
                                    '${thisMonthTotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: diff > 0
                                          ? Colors.red
                                          : const Color(0xFF4A90D9),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: budgetAmount > 0
                                    ? (thisMonthTotal / budgetAmount)
                                        .clamp(0.0, 1.0)
                                    : 0,
                                backgroundColor: Colors.grey.shade200,
                                color: diff > 0
                                    ? Colors.red
                                    : const Color(0xFF4A90D9),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                diff > 0
                                    ? '예산 초과 ${diff.abs().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원 ⚠️'
                                    : '예산 ${(budgetAmount - thisMonthTotal).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원 남았어요 ✅',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: diff > 0 ? Colors.red : Colors.green,
                                ),
                              ),
                            ] else
                              const Text('예산을 설정해보세요!',
                                  style: TextStyle(color: Colors.grey)),
                            if (_memoController.text.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text('📝 메모',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_memoController.text,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 월별 식재료비
                  const Text('📊 월별 식재료비',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (history.isEmpty)
                    const Center(
                      child: Text('아직 구매 이력이 없어요',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final amount = item['total'] ?? 0;
                        final maxAmount = history
                            .map((h) => (h['total'] as num).toDouble())
                            .reduce((a, b) => a > b ? a : b);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  '${item['month']}월',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: item['month'] == _selectedMonth &&
                                            item['year'] == _selectedYear
                                        ? const Color(0xFF4A90D9)
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: maxAmount > 0
                                          ? (amount / maxAmount).clamp(0.0, 1.0)
                                          : 0,
                                      child: Container(
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: item['month'] ==
                                                      _selectedMonth &&
                                                  item['year'] == _selectedYear
                                              ? const Color(0xFF4A90D9)
                                              : const Color(0xFF4A90D9)
                                                  .withOpacity(0.4),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}