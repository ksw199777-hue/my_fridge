import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconsax/iconsax.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  Set<int> _checkedIds = {};
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _memoController = TextEditingController();

  Future<void> _loadMemo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _memoController.text = prefs.getString('shopping_memo') ?? '';
    });
  }

  Future<void> _saveMemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopping_memo', _memoController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메모가 저장됐어요!')));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadMemo();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await ApiService.getShoppingList();
    setState(() {
      _items = items;
      _checkedIds.clear();
      _isLoading = false;
    });
  }

  Future<void> _addItem() async {
    if (_nameController.text.isEmpty) return;
    await ApiService.addShoppingItem(
      _nameController.text,
      _quantityController.text.isEmpty ? '1개' : _quantityController.text,
    );
    _nameController.clear();
    _quantityController.clear();
    _loadItems();
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('전체 삭제'),
        content: const Text('장보기 목록을 전부 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      for (final item in _items) {
        await ApiService.deleteShoppingItem(item['id']);
      }
      _loadItems();
    }
  }

  Future<void> _openCoupang() async {
    const partnerUrl = 'https://link.coupang.com/a/d80FY5XY8O';
    try {
      await launchUrl(
        Uri.parse(partnerUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      await launchUrl(
        Uri.parse(partnerUrl),
        mode: LaunchMode.platformDefault,
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
            Icon(Iconsax.shopping_cart, color: Color(0xFF4A90D9), size: 24),
            SizedBox(width: 8),
            Text('장보기 목록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _deleteAll,
              child: const Text('전체삭제', style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF4A90D9)), onPressed: _loadItems),
        ],
      ),
      body: Column(
        children: [
          // 입력창
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '재료 이름',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_basket, color: Color(0xFF4A90D9)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: '수량/무게',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('추가'),
                ),
              ],
            ),
          ),
          // 목록 + 메모
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _buildEmptyView()
                    : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Iconsax.shopping_cart, color: Colors.grey, size: 80),
          const SizedBox(height: 16),
          const Text('장보기 목록이 비어있어요!', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 40),
          _buildMemoSection(),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 쿠팡 안내
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCC02).withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Iconsax.shopping_bag, color: Color(0xFF856404), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '재료 옆 쿠팡 버튼을 누르면 목록 보면서 쿠팡을 이용할 수 있어요!',
                      style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 고정 높이 목록 (스크롤 가능)
          SizedBox(
            height: 320,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isChecked = _checkedIds.contains(item['id']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: Checkbox(
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _checkedIds.add(item['id']);
                          } else {
                            _checkedIds.remove(item['id']);
                          }
                        });
                      },
                      activeColor: const Color(0xFF4A90D9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    title: Text(
                      item['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isChecked ? Colors.grey.shade400 : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      '${item['quantity']}',
                      style: TextStyle(color: isChecked ? Colors.grey.shade300 : Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _openCoupang,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCC02),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '쿠팡',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            await ApiService.deleteShoppingItem(item['id']);
                            _loadItems();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 메모 섹션
          _buildMemoSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMemoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Iconsax.note, color: Color(0xFF4A90D9), size: 20),
              SizedBox(width: 8),
              Text('메모', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _memoController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '장보기 메모를 자유롭게 적어보세요!\n예) 마트 가는 날: 토요일, 예산: 5만원',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveMemo,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('메모 저장'),
            ),
          ),
        ],
      ),
    );
  }
}
