import 'package:flutter/material.dart';
import '../api_service.dart';
import '../main.dart';
import 'package:flutter/services.dart';
import 'fridge_detail_screen.dart';

class FridgeSelectScreen extends StatefulWidget {
  const FridgeSelectScreen({super.key});

  @override
  State<FridgeSelectScreen> createState() => _FridgeSelectScreenState();
}

class _FridgeSelectScreenState extends State<FridgeSelectScreen> {
  List<dynamic> _fridges = [];
  bool _isLoading = true;
  final _fridgeNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFridges();
  }

  Future<void> _loadFridges() async {
    setState(() => _isLoading = true);
    final fridges = await ApiService.getFridges();
    setState(() {
      _fridges = fridges;
      _isLoading = false;
    });
  }

  Future<void> _createFridge() async {
    if (_fridgeNameController.text.isEmpty) return;
    final result = await ApiService.createFridge(_fridgeNameController.text);
    if (result['id'] != null) {
      _fridgeNameController.clear();
      _loadFridges();
    }
  }

  Future<void> _joinFridge() async {
    if (_inviteCodeController.text.isEmpty) return;
    final result = await ApiService.joinFridge(_inviteCodeController.text);
    if (result['message'] != null) {
      _inviteCodeController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['message'])));
      _loadFridges();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result['detail'] ?? '오류가 발생했어요')));
    }
  }

  Future<void> _selectFridge(int fridgeId) async {
    await ApiService.saveFridgeId(fridgeId);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '냉장고 선택',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await ApiService.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
            child: const Text('로그아웃', style: TextStyle(color: Colors.grey)),
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
                  // 내 냉장고 목록
                  const Text(
                    '🧊 내 냉장고',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_fridges.isEmpty)
                    const Center(
                      child: Text(
                        '냉장고가 없어요! 아래에서 만들어보세요',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._fridges.map(
                      (fridge) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          onTap: () {
                            // ← 추가
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FridgeDetailScreen(
                                  fridgeId: fridge['id'],
                                  fridgeName: fridge['name'],
                                ),
                              ),
                            );
                          },
                          leading: const Text(
                            '🧊',
                            style: TextStyle(fontSize: 28),
                          ),
                          title: Text(
                            fridge['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: fridge['is_owner']
                              ? Row(
                                  children: [
                                    Text(
                                      '초대코드: ${fridge['invite_code']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: fridge['invite_code'],
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('초대코드가 복사됐어요!'),
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.copy,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  '공유 냉장고',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => _selectFridge(fridge['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4A90D9),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('선택'),
                              ),
                              if (fridge['is_owner']) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Text('냉장고 삭제'),
                                        content: Text(
                                          '${fridge['name']}을(를) 삭제할까요?\n냉장고 안 재료도 모두 삭제돼요!',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('취소'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              '삭제',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ApiService.deleteFridge(
                                        fridge['id'],
                                      );
                                      _loadFridges();
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // 새 냉장고 만들기
                  const Text(
                    '➕ 새 냉장고 만들기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fridgeNameController,
                          decoration: const InputDecoration(
                            labelText: '냉장고 이름 (예: 우리집, 회사)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.kitchen,
                              color: Color(0xFF4A90D9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _createFridge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('만들기'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 초대 코드로 참여
                  const Text(
                    '🔗 초대 코드로 참여',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inviteCodeController,
                          decoration: const InputDecoration(
                            labelText: '초대 코드 입력',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.link,
                              color: Color(0xFF7BC67E),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _joinFridge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7BC67E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('참여'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
