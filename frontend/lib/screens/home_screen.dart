import 'package:flutter/material.dart';
import '../api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _ingredients = [];
  bool _isLoading = true;
  String _selectedLocation = '전체';

  final List<Color> _avatarColors = [
    const Color(0xFF4A90D9),
    const Color(0xFF7BC67E),
    const Color(0xFFFF8C69),
    const Color(0xFFFFB347),
    const Color(0xFFDDA0DD),
    const Color(0xFF87CEEB),
    const Color(0xFFFF6B6B),
    const Color(0xFF98D8C8),
  ];

  Color _getAvatarColor(String name) {
    int hash = name.codeUnits.fold(0, (prev, curr) => prev + curr);
    return _avatarColors[hash % _avatarColors.length];
  }

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    setState(() => _isLoading = true);
    final ingredients = await ApiService.getIngredients();
    setState(() {
      _ingredients = ingredients;
      _isLoading = false;
    });
  }

  List<dynamic> get _filteredIngredients {
    List<dynamic> filtered = _selectedLocation == '전체'
        ? List.from(_ingredients)
        : _ingredients.where((i) => i['location'] == _selectedLocation).toList();

    filtered.sort((a, b) {
      int dDayA = a['d_day'] as int;
      int dDayB = b['d_day'] as int;

      if (dDayA < 0 && dDayB >= 0) return -1;
      if (dDayA >= 0 && dDayB < 0) return 1;
      if (dDayA <= 3 && dDayB > 3) return -1;
      if (dDayA > 3 && dDayB <= 3) return 1;

      return (b['id'] as int).compareTo(a['id'] as int);
    });

    return filtered;
  }

  Color _getDdayColor(int dDay) {
    if (dDay < 0) return Colors.red;
    if (dDay <= 3) return Colors.orange;
    if (dDay <= 7) return Colors.yellow.shade700;
    return const Color(0xFF7BC67E);
  }

  Color _getCardColor(int dDay) {
    if (dDay < 0) return const Color(0xFFFFEBEB);
    if (dDay <= 3) return const Color(0xFFFFFDE7);
    return Colors.white;
  }

  String _getDdayText(int dDay) {
    if (dDay < 0) return '만료됨';
    if (dDay == 0) return 'D-Day';
    return 'D-$dDay';
  }

  String _getLocationEmoji(String location) {
    switch (location) {
      case '냉장': return '🧊';
      case '냉동': return '❄️';
      case '실온': return '🌡️';
      default: return '📦';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🧊', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('나만의 냉장고',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4A90D9)),
            onPressed: _loadIngredients,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90D9), Color(0xFFA8D8EA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryItem(emoji: '🥗', count: _ingredients.length, label: '전체'),
                      _SummaryItem(
                        emoji: '⚠️',
                        count: _ingredients.where((i) => i['d_day'] >= 0 && i['d_day'] <= 3).length,
                        label: '임박',
                      ),
                      _SummaryItem(
                        emoji: '❌',
                        count: _ingredients.where((i) => i['d_day'] < 0).length,
                        label: '만료',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['전체', '냉장', '냉동', '실온'].map((location) {
                      final isSelected = _selectedLocation == location;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedLocation = location),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF4A90D9) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              location,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _filteredIngredients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🧊', style: TextStyle(fontSize: 60)),
                              const SizedBox(height: 16),
                              Text(
                                '$_selectedLocation 재료가 없어요!',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadIngredients,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredIngredients.length,
                            itemBuilder: (context, index) {
                              final item = _filteredIngredients[index];
                              final dDay = item['d_day'] as int;
                              final avatarColor = _getAvatarColor(item['name']);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                color: _getCardColor(dDay),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: avatarColor.withOpacity(0.2),
                                    child: Text(
                                      item['name'][0],
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: avatarColor,
                                          fontSize: 18),
                                    ),
                                  ),
                                  title: Text(
                                    item['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('${_getLocationEmoji(item['location'])} ${item['location']}'),
                                      if (item['expiry_date'] != null)
                                        Text('📦 유통기한: ${item['expiry_date']}'),
                                      Text('🗓 소비기한: ${item['consume_date']}'),
                                      if (item['has_expiry_label'] == 0)
                                        const Text(
                                          '⚠️ 오늘 기준 산출 (수정 가능)',
                                          style: TextStyle(fontSize: 11, color: Colors.orange),
                                        ),
                                      if (item['price'] > 0)
                                        Text('💰 ${item['price']}원'),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getDdayColor(dDay).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: _getDdayColor(dDay)),
                                    ),
                                    child: Text(
                                      _getDdayText(dDay),
                                      style: TextStyle(
                                        color: _getDdayColor(dDay),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  onLongPress: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                        title: const Text('재료 삭제'),
                                        content: Text('${item['name']}을(를) 삭제할까요?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('취소'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('삭제',
                                                style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ApiService.deleteIngredient(item['id']);
                                      _loadIngredients();
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String emoji;
  final int count;
  final String label;

  const _SummaryItem({
    required this.emoji,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text('$count',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}