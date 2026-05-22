import 'package:flutter/material.dart';
import '../api_service.dart';
import 'fridge_select_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _ingredients = [];
  bool _isLoading = true;
  String _selectedLocation = '전체';
  bool _isSelectionMode = false;
  Set<int> _selectedIds = {};

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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredIngredients.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _filteredIngredients.map((i) => i['id'] as int).toSet();
      }
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('재료 삭제'),
        content: Text('선택한 ${_selectedIds.length}개 재료를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final id in _selectedIds) {
        await ApiService.deleteIngredient(id);
      }
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      _loadIngredients();
    }
  }

void _showIngredientDetail(dynamic item) {
    final dDay = item['d_day'] as int;
    final isExpired = dDay < 0;
    final nameController = TextEditingController(text: item['name']);
    final consumeController = TextEditingController();
    final priceController = TextEditingController(text: '${item['price']}');
    String selectedLocation = item['location'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isExpired)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '소비기한이 지났어요!\n재료 상태 확인 후 폐기 완료하면 삭제해주세요 🗑️',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isExpired) const SizedBox(height: 12),
                Text(item['name'],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  item['expiry_date'] != null
                      ? '유통기한: ${item['expiry_date']} / 소비기한: ${item['consume_date']}'
                      : '소비기한: ${item['consume_date']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('✏️ 수정하기',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '재료 이름',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.food_bank, color: Color(0xFF4A90D9)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: consumeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '소비기한 (오늘부터 며칠?)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month, color: Color(0xFFFFB347)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '가격 (원)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money, color: Color(0xFFFF6B6B)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedLocation,
                  decoration: const InputDecoration(
                    labelText: '보관 위치',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on, color: Color(0xFFDDA0DD)),
                  ),
                  items: ['냉장', '냉동', '실온'].map((loc) =>
                      DropdownMenuItem(value: loc, child: Text(loc))).toList(),
                  onChanged: (val) => setModalState(() => selectedLocation = val!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ApiService.updateIngredient(
                        item['id'],
                        name: nameController.text,
                        consumeDays: consumeController.text.isNotEmpty
                            ? int.parse(consumeController.text)
                            : null,
                        price: int.tryParse(priceController.text),
                        location: selectedLocation,
                      );
                      Navigator.pop(context);
                      _loadIngredients();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('수정 완료', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      bool deleteHistory = false;
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => StatefulBuilder(
                          builder: (context, setDialogState) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('재료 삭제'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${item['name']}을(를) 삭제할까요?'),
                                const SizedBox(height: 16),
                                RadioListTile<bool>(
                                  title: const Text('식재료비 유지'),
                                  subtitle: const Text('가계부 금액은 그대로 남아요'),
                                  value: false,
                                  groupValue: deleteHistory,
                                  onChanged: (val) => setDialogState(() => deleteHistory = val!),
                                  activeColor: const Color(0xFF4A90D9),
                                ),
                                RadioListTile<bool>(
                                  title: const Text('식재료비도 함께 삭제'),
                                  subtitle: const Text('가계부에서 금액도 제거돼요'),
                                  value: true,
                                  groupValue: deleteHistory,
                                  onChanged: (val) => setDialogState(() => deleteHistory = val!),
                                  activeColor: Colors.red,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (confirm == true) {
                        await ApiService.deleteIngredient(item['id'], deleteHistory: deleteHistory);
                        Navigator.pop(context);
                        _loadIngredients();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isExpired ? '🗑️ 폐기 완료 - 삭제하기' : '삭제하기',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length}개 선택됨',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))
            : const Row(
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
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: _selectAll,
              child: Text(
                _selectedIds.length == _filteredIngredients.length ? '전체 해제' : '전체 선택',
                style: const TextStyle(color: Color(0xFF4A90D9)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSelectionMode,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.kitchen, color: Color(0xFF4A90D9)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FridgeSelectScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.checklist, color: Color(0xFF4A90D9)),
              onPressed: _toggleSelectionMode,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF4A90D9)),
              onPressed: _loadIngredients,
            ),
          ],
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
                              final isSelected = _selectedIds.contains(item['id'] as int);
                              return GestureDetector(
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleSelect(item['id'] as int);
                                  } else {
                                    _showIngredientDetail(item);
                                  }
                                },
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    _toggleSelectionMode();
                                    _toggleSelect(item['id'] as int);
                                  }
                                },
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  color: isSelected
                                      ? const Color(0xFFE3F0FF)
                                      : _getCardColor(dDay),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: isSelected
                                        ? const BorderSide(color: Color(0xFF4A90D9), width: 2)
                                        : BorderSide.none,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    leading: _isSelectionMode
                                        ? Checkbox(
                                            value: isSelected,
                                            onChanged: (_) => _toggleSelect(item['id'] as int),
                                            activeColor: const Color(0xFF4A90D9),
                                          )
                                        : CircleAvatar(
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
                                            '⚠️ 오늘 기준 산출 (탭해서 수정 가능)',
                                            style: TextStyle(fontSize: 11, color: Colors.orange),
                                          ),
                                        if (item['price'] > 0)
                                          Text('💰 ${item['price']}원'),
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
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
                                  ),
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