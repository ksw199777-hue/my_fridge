import 'package:flutter/material.dart';
import '../api_service.dart';
import 'package:iconsax/iconsax.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic> _userInfo = {};
  bool _isLoading = true;
  int _extraMembers = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final info = await ApiService.getMe();
    setState(() {
      _userInfo = info;
      _extraMembers = info['extra_members'] ?? 0;
      _isLoading = false;
    });
  }

  Future<void> _subscribe(String planType) async {
    setState(() => _isLoading = true);
    final success = await ApiService.updateSubscription(
      subscriptionType: planType,
      extraMembers: planType == 'team' ? _extraMembers : 0,
    );
    setState(() => _isLoading = false);

    if (success && mounted) {
      await _loadUserInfo();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$planType 플랜으로 변경됐어요! 🎉')),
      );
    }
  }

  String _getPlanName(String type) {
    switch (type) {
      case 'premium':
        return '프리미엄';
      case 'team':
        return '팀';
      case 'vip':
        return 'VIP';
      default:
        return '무료';
    }
  }

  int _getTeamPrice() => 5000 + (_extraMembers * 1000);

  @override
  Widget build(BuildContext context) {
    final currentPlan = _userInfo['subscription_type'] ?? 'free';
    final expires = _userInfo['subscription_expires'];
    final trialUsed = _userInfo['trial_used'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '구독 플랜',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4A90D9).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '현재 플랜',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getPlanName(currentPlan),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (expires != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '만료일: $expires',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (trialUsed == 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Iconsax.gift, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  '첫 결제 시 1개월 무료!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _PlanCard(
                    icon: Iconsax.slash,
                    title: '무료',
                    price: '무료',
                    features: const [
                      '재료 인식 / 수동 등록',
                      '냉장고 관리',
                      '레시피 검색',
                      '쇼핑 목록',
                      '가계부',
                      '냉장고 1대',
                      '혼자 사용',
                    ],
                    isCurrentPlan: currentPlan == 'free',
                    color: Colors.grey,
                    onTap: currentPlan != 'free' ? () => _subscribe('free') : null,
                  ),
                  const SizedBox(height: 12),

                  _PlanCard(
                    icon: Iconsax.star,
                    title: '프리미엄',
                    price: '월 3,000원',
                    features: const [
                      'AI 레시피 추천',
                      'AI 대화형 채팅',
                      '냉장고 2대',
                      '2명 공유',
                      '구독자만 AI 사용 가능',
                    ],
                    isCurrentPlan: currentPlan == 'premium',
                    color: const Color(0xFF4A90D9),
                    badge: trialUsed == 0 ? '1개월 무료' : null,
                    onTap: currentPlan != 'premium' ? () => _subscribe('premium') : null,
                  ),
                  const SizedBox(height: 12),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: currentPlan == 'team'
                            ? const Color(0xFF7BC67E)
                            : Colors.grey.withOpacity(0.3),
                        width: currentPlan == 'team' ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Iconsax.people, color: Color(0xFF7BC67E), size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    '팀 플랜',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (trialUsed == 0)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        '1개월 무료',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '월 ${_getTeamPrice().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7BC67E),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text('• 프리미엄 기능 전부'),
                          const Text('• 냉장고 3대'),
                          const Text('• 기본 4명 공유'),
                          const Text('• 구독자만 AI 사용 가능'),
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              Text('추가 인원: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('(1명당 +1,000원, 최대 2명 추가)'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _extraMembers > 0
                                    ? () => setState(() => _extraMembers--)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                color: const Color(0xFF7BC67E),
                              ),
                              Text(
                                '$_extraMembers명',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: _extraMembers < 2
                                    ? () => setState(() => _extraMembers++)
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                                color: const Color(0xFF7BC67E),
                              ),
                              Text(
                                '(총 ${4 + _extraMembers}명)',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (currentPlan != 'team')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _subscribe('team'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7BC67E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('구독하기'),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7BC67E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text(
                                  '현재 이용 중',
                                  style: TextStyle(
                                    color: Color(0xFF7BC67E),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _PlanCard(
                    icon: Iconsax.crown,
                    title: 'VIP',
                    price: '월 15,000원',
                    features: const [
                      '모든 기능 사용 가능',
                      '냉장고 무제한',
                      '공유 인원 무제한',
                      '멤버 전원 AI 사용 가능',
                    ],
                    isCurrentPlan: currentPlan == 'vip',
                    color: const Color(0xFFFFB347),
                    badge: trialUsed == 0 ? '1개월 무료' : null,
                    onTap: currentPlan != 'vip' ? () => _subscribe('vip') : null,
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Iconsax.info_circle, color: Color(0xFF4A90D9), size: 18),
                            SizedBox(width: 6),
                            Text('안내', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('• 첫 결제 시 1개월 무료 체험 제공', style: TextStyle(fontSize: 13)),
                        const Text('• 구독은 언제든지 변경/해지 가능', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String price;
  final List<String> features;
  final bool isCurrentPlan;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.icon,
    required this.title,
    required this.price,
    required this.features,
    required this.isCurrentPlan,
    required this.color,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCurrentPlan ? color : Colors.grey.withOpacity(0.3),
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (badge != null)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...features.map((f) => Text('• $f', style: const TextStyle(fontSize: 13))),
            const SizedBox(height: 12),
            if (!isCurrentPlan && onTap != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('구독하기'),
                ),
              )
            else if (isCurrentPlan)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '현재 이용 중',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}