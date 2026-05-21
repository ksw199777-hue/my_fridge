import 'package:flutter/material.dart';
import '../api_service.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  bool _isEstimating = false;
  Map<String, dynamic> _estimate = {};
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await ApiService.getShoppingList();
    setState(() {
      _items = items;
      _isLoading = false;
      _estimate = {};
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

  Future<void> _estimatePrice() async {
    setState(() => _isEstimating = true);
    final result = await ApiService.estimateShoppingPrice();
    setState(() {
      _estimate = result;
      _isEstimating = false;
    });
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('전체 삭제'),
        content: const Text('장보기 목록을 전부 삭제할까요?'),
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
      for (final item in _items) {
        await ApiService.deleteShoppingItem(item['id']);
      }
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🛒', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('장보기 목록',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _deleteAll,
              child: const Text('전체삭제',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4A90D9)),
            onPressed: _loadItems,
          ),
        ],
      ),
      body: Column(
        children: [
          // 입력창
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '재료 이름',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.shopping_basket,
                              color: Color(0xFF4A90D9)),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
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
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90D9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('추가'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 재료 이름은 구체적으로, 수량은 단위를 붙여주세요!',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4A90D9),
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '예) 삼겹살 / 600g,  대파 / 1단,  계란 / 30개묶음,  양파 / 1망',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🛒', style: TextStyle(fontSize: 80)),
                            SizedBox(height: 16),
                            Text('장보기 목록이 비어있어요!',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            // 예상 가격 버튼
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isEstimating ? null : _estimatePrice,
                                  icon: _isEstimating
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Icon(Icons.calculate),
                                  label: Text(_isEstimating
                                      ? 'AI가 계산중...'
                                      : '💰 총 장보기 예상 금액 계산'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7BC67E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ),

                            // 예상 가격 결과
                            if (_estimate.isNotEmpty &&
                                _estimate['items'] != null) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                child: Card(
                                  color: const Color(0xFFF0FFF4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      side: const BorderSide(
                                          color: Color(0xFF7BC67E))),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('💰 예상 장보기 비용',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        const SizedBox(height: 12),
                                        ...(_estimate['items']
                                                as List<dynamic>)
                                            .map((item) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                          '${item['name']} ${item['quantity']}'),
                                                      Text(
                                                          '약 ${item['total_price']}원',
                                                          style: const TextStyle(
                                                              color: Color(
                                                                  0xFF4A90D9))),
                                                    ],
                                                  ),
                                                )),
                                        const Divider(),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('총 예상 금액',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(
                                              '약 ${_estimate['total']}원',
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF7BC67E)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // 쇼핑 목록
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(16)),
                                  child: ListTile(
                                    leading: IconButton(
                                      icon: const Icon(
                                          Icons.check_circle_outline,
                                          color: Color(0xFF4A90D9)),
                                      onPressed: () async {
                                        await ApiService.markPurchased(
                                            item['id']);
                                        _loadItems();
                                      },
                                    ),
                                    title: Text(item['name'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text('${item['quantity']}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () async {
                                        await ApiService.deleteShoppingItem(
                                            item['id']);
                                        _loadItems();
                                      },
                                    ),
                                  ),
                                );
                              },
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