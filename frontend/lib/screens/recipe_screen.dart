import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  List<dynamic> _recipes = [];
  bool _isLoading = false;
  int? _expandedIndex;

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    final recipes = await ApiService.getRecipes();
    setState(() {
      _recipes = recipes;
      _isLoading = false;
      _expandedIndex = null;
    });
  }

  Future<void> _openYoutube(String recipeName) async {
    final query = Uri.encodeComponent('$recipeName 레시피');
    final url = Uri.parse('https://www.youtube.com/results?search_query=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case '쉬움': return '🟢';
      case '보통': return '🟡';
      case '어려움': return '🔴';
      default: return '⚪';
    }
  }

  String _getRecipeEmoji(String name) {
    if (name.contains('국') || name.contains('찌개') || name.contains('탕')) return '🍲';
    if (name.contains('볶음') || name.contains('炒')) return '🥘';
    if (name.contains('구이') || name.contains('구운')) return '🍖';
    if (name.contains('튀김')) return '🍟';
    if (name.contains('샐러드')) return '🥗';
    if (name.contains('밥')) return '🍚';
    if (name.contains('면') || name.contains('파스타')) return '🍝';
    if (name.contains('빵') || name.contains('토스트')) return '🍞';
    if (name.contains('계란') || name.contains('달걀')) return '🍳';
    if (name.contains('김치')) return '🥬';
    return '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🍳', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('레시피 추천',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🍳', style: TextStyle(fontSize: 80)),
                      const SizedBox(height: 16),
                      const Text(
                        '냉장고 재료로 만들 수 있는\n요리를 추천해드려요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadRecipes,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('AI 추천 받기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _recipes[index];
                    final isExpanded = _expandedIndex == index;
                    final emoji = _getRecipeEmoji(recipe['name']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // 헤더
                          GestureDetector(
                            onTap: () => setState(() =>
                                _expandedIndex = isExpanded ? null : index),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? const Color(0xFFF0F7FF)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isExpanded ? 0 : 16),
                                  bottomRight: Radius.circular(isExpanded ? 0 : 16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // 이모지 아이콘
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFA8D8EA).withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(emoji,
                                          style: const TextStyle(fontSize: 28)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          recipe['name'],
                                          style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '${_getDifficultyColor(recipe['difficulty'])} ${recipe['difficulty']}',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.timer,
                                                size: 14, color: Colors.grey),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${recipe['cooking_time']}분',
                                              style: const TextStyle(
                                                  fontSize: 13, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: const Color(0xFF4A90D9),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 펼쳐지는 내용
                          if (isExpanded)
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),

                                  // 필요 재료
                                  const Text('🛒 필요 재료',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: (recipe['ingredients_needed'] as List<dynamic>)
                                        .map((i) => Chip(
                                              label: Text(i,
                                                  style: const TextStyle(fontSize: 12)),
                                              backgroundColor:
                                                  const Color(0xFFA8D8EA).withOpacity(0.3),
                                              padding: EdgeInsets.zero,
                                            ))
                                        .toList(),
                                  ),

                                  // 없는 재료
                                  if ((recipe['missing_ingredients'] as List<dynamic>)
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Text('❌ 없는 재료',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: (recipe['missing_ingredients']
                                              as List<dynamic>)
                                          .map((i) => Chip(
                                                label: Text(i,
                                                    style: const TextStyle(fontSize: 12)),
                                                backgroundColor:
                                                    Colors.red.withOpacity(0.1),
                                                padding: EdgeInsets.zero,
                                              ))
                                          .toList(),
                                    ),
                                  ],

                                  // 조리 단계
                                  if (recipe['steps'] != null) ...[
                                    const SizedBox(height: 12),
                                    const Text('👨‍🍳 조리 방법',
                                        style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    ...(recipe['steps'] as List<dynamic>)
                                        .map((step) => Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF4A90D9),
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '${(recipe['steps'] as List).indexOf(step) + 1}',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      step.toString().replaceAll(
                                                          RegExp(r'^\d+\.\s*'), ''),
                                                      style: const TextStyle(fontSize: 14),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )),
                                  ],

                                  const SizedBox(height: 12),

                                  // 유튜브 버튼
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _openYoutube(recipe['name']),
                                      icon: const Text('▶️'),
                                      label: Text('${recipe['name']} 유튜브 레시피 보기'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF0000),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: _recipes.isNotEmpty
          ? FloatingActionButton(
              onPressed: _loadRecipes,
              backgroundColor: const Color(0xFF4A90D9),
              child: const Icon(Icons.refresh, color: Colors.white),
            )
          : null,
    );
  }
}