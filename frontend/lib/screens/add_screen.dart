import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api_service.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // 임시 재료 리스트
  List<Map<String, dynamic>> _pendingIngredients = [];

  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _consumeController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedLocation = '냉장';
  String _selectedStorageType = '냉장';

  Future<void> _pickAndRecognize(ImageSource source, String type) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isLoading = true);
    final bytes = await image.readAsBytes();

    Map<String, dynamic> result = {};
    if (type == 'ingredient') {
      result = await ApiService.recognizeIngredients(bytes);
    } else if (type == 'receipt') {
      result = await ApiService.recognizeReceipt(bytes);
    } else if (type == 'screenshot') {
      result = await ApiService.recognizeScreenshot(bytes);
    }

    setState(() => _isLoading = false);

    final ingredients = result['ingredients'] as List<dynamic>? ?? [];
    if (ingredients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('재료를 인식하지 못했어요 😢')));
      }
      return;
    }

    // 임시 리스트에 추가 (기본 보관방법 '냉장')
    setState(() {
      for (var item in ingredients) {
        _pendingIngredients.add({...item, 'storage_type': '냉장'});
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ingredients.length}개 재료가 목록에 추가됐어요! 저장 전 보관방법을 확인해주세요 😄',
          ),
        ),
      );
    }
  }

  Future<void> _saveAllIngredients() async {
    if (_pendingIngredients.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장할 재료가 없어요!')));
      return;
    }

    // 보관방법 선택창
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _StorageTypeDialog(
        ingredients: _pendingIngredients,
        onConfirm: (updated) {
          setState(() => _pendingIngredients = updated);
        },
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    int successCount = 0;
    for (var item in _pendingIngredients) {
      // consume_date가 날짜 문자열로 오면 오늘부터 일수로 변환
      int consumeDays = 7;
      if (item['consume_date'] != null) {
        try {
          final consumeDate = DateTime.parse(item['consume_date']);
          final today = DateTime.now();
          consumeDays = consumeDate.difference(today).inDays;
          if (consumeDays < 0) consumeDays = 0;
        } catch (e) {
          consumeDays = item['consume_days'] ?? 7;
        }
      } else {
        consumeDays = item['consume_days'] ?? 7;
      }

      final success = await ApiService.addIngredient(
        name: item['name'],
        consumeDays: consumeDays,
        price: item['price'] ?? 0,
        location: item['storage_type'] ?? '냉장',
        storageType: item['storage_type'] ?? '냉장',
        hasExpiryLabel: item['has_expiry_label'] ?? false,
      );
      if (success) successCount++;
    }

    setState(() {
      _isLoading = false;
      _pendingIngredients = [];
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$successCount개 재료가 저장됐어요! 🎉')));
    }
  }

  Future<void> _addManually() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('재료 이름을 입력해주세요')));
      return;
    }

    setState(() => _isLoading = true);
    final success = await ApiService.addIngredient(
      name: _nameController.text,
      expiryDays: _expiryController.text.isNotEmpty
          ? int.tryParse(_expiryController.text)
          : null,
      consumeDays: _consumeController.text.isNotEmpty
          ? int.tryParse(_consumeController.text) ?? 7
          : 7,
      price: int.tryParse(_priceController.text) ?? 0,
      location: _selectedLocation,
      storageType: _selectedStorageType,
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      _nameController.clear();
      _expiryController.clear();
      _consumeController.clear();
      _priceController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('재료가 추가됐어요! 😄')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('➕', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              '재료 추가',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📸 사진으로 추가',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AddButton(
                          icon: Icons.camera_alt,
                          label: '카메라',
                          color: const Color(0xFF4A90D9),
                          onTap: () => _pickAndRecognize(
                            ImageSource.camera,
                            'ingredient',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AddButton(
                          icon: Icons.receipt_long,
                          label: '영수증',
                          color: const Color(0xFF7BC67E),
                          onTap: () =>
                              _pickAndRecognize(ImageSource.gallery, 'receipt'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AddButton(
                          icon: Icons.screenshot,
                          label: '스크린샷',
                          color: const Color(0xFFFFB347),
                          onTap: () => _pickAndRecognize(
                            ImageSource.gallery,
                            'screenshot',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 임시 재료 리스트
                  if (_pendingIngredients.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📋 저장 대기 중 (${_pendingIngredients.length}개)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _pendingIngredients = []),
                          child: const Text(
                            '전체 삭제',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pendingIngredients.length,
                      itemBuilder: (context, index) {
                        final item = _pendingIngredients[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.food_bank,
                              color: Color(0xFF4A90D9),
                            ),
                            title: Text(item['name']),
                            subtitle: Text(
                              '소비기한: ${item['consume_date'] ?? '자동산출'} · ${item['storage_type']}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => setState(
                                () => _pendingIngredients.removeAt(index),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveAllIngredients,
                        icon: const Icon(Icons.save),
                        label: Text('${_pendingIngredients.length}개 저장하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    '✏️ 직접 입력',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: '재료 이름',
                              prefixIcon: Icon(
                                Icons.food_bank,
                                color: Color(0xFF4A90D9),
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _expiryController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '유통기한 (일, 없으면 비워두세요)',
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: Color(0xFF7BC67E),
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _consumeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '소비기한 (일, 모르면 비워두세요 → 자동 산출해드려요!)',
                              prefixIcon: Icon(
                                Icons.calendar_month,
                                color: Color(0xFFFFB347),
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 12,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '식품위생법 및 식약처 기준을 참고해 산출합니다',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '가격 (원)',
                              prefixIcon: Icon(
                                Icons.attach_money,
                                color: Color(0xFFFF6B6B),
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedStorageType,
                            decoration: const InputDecoration(
                              labelText: '보관 방법',
                              prefixIcon: Icon(
                                Icons.kitchen,
                                color: Color(0xFFDDA0DD),
                              ),
                              border: OutlineInputBorder(),
                            ),
                            items: ['냉장', '냉동', '실온'].map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedStorageType = value!),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _addManually,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A90D9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '추가하기',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// 보관방법 선택 다이얼로그
class _StorageTypeDialog extends StatefulWidget {
  final List<Map<String, dynamic>> ingredients;
  final Function(List<Map<String, dynamic>>) onConfirm;

  const _StorageTypeDialog({
    required this.ingredients,
    required this.onConfirm,
  });

  @override
  State<_StorageTypeDialog> createState() => _StorageTypeDialogState();
}

class _StorageTypeDialogState extends State<_StorageTypeDialog> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.ingredients
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('보관 방법 확인'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '식품위생법 및 식약처 기준을 참고합니다',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: item['storage_type'] ?? '냉장',
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            items: ['냉장', '냉동', '실온'].map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (value) => setState(
                              () => _items[index]['storage_type'] = value!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_items);
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A90D9),
            foregroundColor: Colors.white,
          ),
          child: const Text('저장하기'),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
