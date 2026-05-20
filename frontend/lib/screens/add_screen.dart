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
  String? _message;

  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _consumeController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedLocation = '냉장';

  Future<void> _pickAndRecognize(ImageSource source, String type) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isLoading = true);
    final bytes = await image.readAsBytes();

    Map<String, dynamic> result = {};
    if (type == 'ingredient') {
      result = await ApiService.recognizeIngredientWithMessage(bytes);
    } else if (type == 'receipt') {
      result = await ApiService.recognizeReceiptWithMessage(bytes);
    } else if (type == 'screenshot') {
      result = await ApiService.recognizeScreenshotWithMessage(bytes);
    }

    setState(() {
      _isLoading = false;
      _message = result['message'];
    });

    final ingredients = result['ingredients'] as List<dynamic>? ?? [];

    if (ingredients.isNotEmpty && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('인식된 재료'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_message != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9C4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _message!,
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: ingredients.length,
                  itemBuilder: (context, index) {
                    final item = ingredients[index];
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(item['name']),
                      subtitle: Text(
                        item['expiry_date'] != null
                            ? '유통기한: ${item['expiry_date']} / 소비기한: ${item['consume_date']}'
                            : '소비기한: ${item['consume_date']}',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _addManually() async {
    if (_nameController.text.isEmpty || _consumeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 소비기한을 입력해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await ApiService.createIngredient(
      _nameController.text,
      _expiryController.text.isNotEmpty ? int.parse(_expiryController.text) : null,
      int.parse(_consumeController.text),
      int.tryParse(_priceController.text) ?? 0,
      _selectedLocation,
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      _nameController.clear();
      _expiryController.clear();
      _consumeController.clear();
      _priceController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재료가 추가됐어요! 😄')),
      );
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
            Text('재료 추가',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
                  const Text('📸 사진으로 추가',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AddButton(
                          icon: Icons.camera_alt,
                          label: '카메라',
                          color: const Color(0xFF4A90D9),
                          onTap: () => _pickAndRecognize(ImageSource.camera, 'ingredient'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AddButton(
                          icon: Icons.receipt_long,
                          label: '영수증',
                          color: const Color(0xFF7BC67E),
                          onTap: () => _pickAndRecognize(ImageSource.gallery, 'receipt'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _AddButton(
                          icon: Icons.screenshot,
                          label: '스크린샷',
                          color: const Color(0xFFFFB347),
                          onTap: () => _pickAndRecognize(ImageSource.gallery, 'screenshot'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('✏️ 직접 입력',
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
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: '재료 이름',
                              prefixIcon: Icon(Icons.food_bank, color: Color(0xFF4A90D9)),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _expiryController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '유통기한 (일, 없으면 비워두세요)',
                              prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF7BC67E)),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _consumeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '소비기한 (일)',
                              prefixIcon: Icon(Icons.calendar_month, color: Color(0xFFFFB347)),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '가격 (원)',
                              prefixIcon: Icon(Icons.attach_money, color: Color(0xFFFF6B6B)),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedLocation,
                            decoration: const InputDecoration(
                              labelText: '보관 위치',
                              prefixIcon: Icon(Icons.location_on, color: Color(0xFFDDA0DD)),
                              border: OutlineInputBorder(),
                            ),
                            items: ['냉장', '냉동', '실온'].map((location) {
                              return DropdownMenuItem(
                                value: location,
                                child: Text(location),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedLocation = value!),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _addManually,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A90D9),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('추가하기',
                                  style: TextStyle(fontSize: 16)),
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
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}