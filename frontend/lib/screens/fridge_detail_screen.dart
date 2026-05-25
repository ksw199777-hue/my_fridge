import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';

class FridgeDetailScreen extends StatefulWidget {
  final int fridgeId;
  final String fridgeName;

  const FridgeDetailScreen({
    super.key,
    required this.fridgeId,
    required this.fridgeName,
  });

  @override
  State<FridgeDetailScreen> createState() => _FridgeDetailScreenState();
}

class _FridgeDetailScreenState extends State<FridgeDetailScreen> {
  Map<String, dynamic> _fridgeData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getFridgeMembers(widget.fridgeId);
    setState(() {
      _fridgeData = data;
      _isLoading = false;
    });
  }

  Future<void> _removeMember(int userId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('멤버 내보내기'),
        content: Text('$username 님을 냉장고에서 내보낼까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('내보내기'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await ApiService.removeFridgeMember(widget.fridgeId, userId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$username 님을 내보냈어요!')),
      );
      _loadMembers();
    }
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('초대 코드가 복사됐어요! 😄')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _fridgeData['is_owner'] ?? false;
    final members = _fridgeData['members'] as List<dynamic>? ?? [];
    final inviteCode = _fridgeData['invite_code'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.fridgeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
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
                  // 초대 코드 (오너만)
                  if (isOwner && inviteCode != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90D9).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF4A90D9).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🔗 초대 코드',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                inviteCode,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy,
                                    color: Color(0xFF4A90D9)),
                                onPressed: () => _copyInviteCode(inviteCode),
                              ),
                            ],
                          ),
                          const Text(
                            '이 코드를 공유하면 냉장고에 초대할 수 있어요',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 멤버 목록
                  Row(
                    children: [
                      Text(
                        '👥 멤버 (${members.length}명)',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final memberIsOwner = member['is_owner'] ?? false;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: memberIsOwner
                                ? const Color(0xFFFFB347)
                                : const Color(0xFF4A90D9),
                            child: Text(
                              member['username'][0].toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(member['username']),
                          subtitle: Text(member['email']),
                          trailing: memberIsOwner
                              ? const Chip(
                                  label: Text('👑 오너',
                                      style: TextStyle(fontSize: 12)),
                                  backgroundColor: Color(0xFFFFF3CD),
                                )
                              : isOwner
                                  ? IconButton(
                                      icon: const Icon(Icons.person_remove,
                                          color: Colors.red),
                                      onPressed: () => _removeMember(
                                          member['id'], member['username']),
                                    )
                                  : null,
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