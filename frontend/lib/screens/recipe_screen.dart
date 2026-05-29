import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../api_service.dart';
import 'package:iconsax/iconsax.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _recipes = [];
  bool _isLoading = false;
  int? _expandedIndex;
  late TabController _tabController;

  // 채팅
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  bool _isChatLoading = false;
  final ScrollController _scrollController = ScrollController();

  // 네이버 검색
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearchLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getRecipes();
    if (result['error'] == 'premium') {
      setState(() => _isLoading = false);
      _showPremiumDialog();
      return;
    }
    setState(() {
      _recipes = result['recipes'] ?? [];
      _isLoading = false;
      _expandedIndex = null;
    });
  }

  Future<void> _searchRecipes() async {
    if (_searchController.text.isEmpty) return;
    setState(() => _isSearchLoading = true);
    final results = await ApiService.searchRecipes(_searchController.text);
    setState(() {
      _searchResults = results;
      _isSearchLoading = false;
    });
  }

  void _openWebView(BuildContext context, String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _WebViewScreen(url: url, title: title),
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Iconsax.star, color: Color(0xFF4A90D9), size: 20),
            SizedBox(width: 8),
            Text('프리미엄 기능'),
          ],
        ),
        content: const Text(
          'AI 레시피 추천은 프리미엄 구독자만 사용할 수 있어요!\n\n월 3,000원으로 업그레이드하면 AI 레시피 추천, 대화형 채팅을 모두 사용할 수 있어요 😄',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90D9),
              foregroundColor: Colors.white,
            ),
            child: const Text('업그레이드'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_chatController.text.isEmpty) return;
    final message = _chatController.text;
    _chatController.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': message, 'recipes': []});
      _isChatLoading = true;
    });

    _scrollToBottom();

    final result = await ApiService.recipeChat(message);

    if (result['error'] == 'premium') {
      setState(() {
        _messages.removeLast();
        _isChatLoading = false;
      });
      _showPremiumDialog();
      return;
    }

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': result['response'] ?? '',
        'recipes': result['recipes'] ?? [],
      });
      _isChatLoading = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openYoutube(String recipeName) async {
    final query = Uri.encodeComponent('$recipeName 레시피');
    final url = Uri.parse(
      'https://www.youtube.com/results?search_query=$query',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case '쉬움':
        return '🟢';
      case '보통':
        return '🟡';
      case '어려움':
        return '🔴';
      default:
        return '⚪';
    }
  }

  String _getRecipeEmoji(String name) {
    if (name.contains('국') || name.contains('찌개') || name.contains('탕'))
      return '🍲';
    if (name.contains('볶음')) return '🥘';
    if (name.contains('구이')) return '🍖';
    if (name.contains('튀김')) return '🍟';
    if (name.contains('샐러드')) return '🥗';
    if (name.contains('밥')) return '🍚';
    if (name.contains('면') || name.contains('파스타')) return '🍝';
    if (name.contains('계란') || name.contains('달걀')) return '🍳';
    if (name.contains('김치')) return '🥬';
    return '🍽️';
  }

  Widget _buildRecipeCard(dynamic recipe, int index, bool isExpanded) {
    final emoji = _getRecipeEmoji(recipe['name']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _expandedIndex = isExpanded ? null : index),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isExpanded ? const Color(0xFFF0F7FF) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isExpanded ? 0 : 16),
                  bottomRight: Radius.circular(isExpanded ? 0 : 16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA8D8EA).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${_getDifficultyColor(recipe['difficulty'])} ${recipe['difficulty']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.timer, size: 14, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text(
                              '${recipe['cooking_time']}분',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF4A90D9),
                  ),
                ],
              ),
            ),
          ),
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
                  Row(
                    children: const [
                      Icon(Iconsax.shopping_cart, size: 16, color: Color(0xFF4A90D9)),
                      SizedBox(width: 6),
                      Text('필요 재료', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (recipe['ingredients_needed'] as List<dynamic>)
                        .map(
                          (i) => Chip(
                            label: Text(i, style: const TextStyle(fontSize: 12)),
                            backgroundColor: const Color(0xFFA8D8EA).withOpacity(0.3),
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                  if ((recipe['missing_ingredients'] as List<dynamic>).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Iconsax.close_circle, size: 16, color: Colors.red),
                        SizedBox(width: 6),
                        Text('없는 재료', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: (recipe['missing_ingredients'] as List<dynamic>)
                          .map(
                            (i) => Chip(
                              label: Text(i, style: const TextStyle(fontSize: 12)),
                              backgroundColor: Colors.red.withOpacity(0.1),
                              padding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (recipe['steps'] != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(Iconsax.note_text, size: 16, color: Color(0xFF4A90D9)),
                        SizedBox(width: 6),
                        Text('조리 방법', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...(recipe['steps'] as List<dynamic>).map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A90D9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${(recipe['steps'] as List).indexOf(step) + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                step.toString().replaceAll(RegExp(r'^\d+\.\s*'), ''),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openYoutube(recipe['name']),
                      icon: const Icon(Icons.play_circle_outline),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Iconsax.search_favorite, color: Color(0xFF4A90D9), size: 24),
            SizedBox(width: 8),
            Text('레시피', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90D9),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF4A90D9),
          tabs: const [
            Tab(icon: Icon(Iconsax.search_normal, size: 18), text: '레시피 찾기'),
            Tab(icon: Icon(Iconsax.magic_star, size: 18), text: 'AI 자동 추천'),
            Tab(icon: Icon(Iconsax.message, size: 18), text: '대화형 추천'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 레시피 찾기 탭
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '재료나 요리 이름으로 검색해보세요!',
                          prefixIcon: const Icon(Iconsax.search_normal, color: Color(0xFF4A90D9)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        onSubmitted: (_) => _searchRecipes(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _searchRecipes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90D9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('검색'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isSearchLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Iconsax.search_normal, color: Colors.grey, size: 60),
                            SizedBox(height: 16),
                            Text(
                              '검색어를 입력하면\n블로그 레시피를 찾아드려요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4A90D9).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Iconsax.note_text, color: Color(0xFF4A90D9), size: 20),
                              ),
                              title: Text(
                                item['title'],
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    item['description'],
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['bloggername'],
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF4A90D9)),
                                  ),
                                ],
                              ),
                              onTap: () => _openWebView(context, item['link'], item['title']),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // AI 자동 추천 탭
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.magicpen, color: Colors.grey, size: 80),
                      const SizedBox(height: 16),
                      const Text(
                        '냉장고 재료로 만들 수 있는\n요리를 추천해드려요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadRecipes,
                        icon: const Icon(Iconsax.magic_star),
                        label: const Text('AI 추천 받기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    return _buildRecipeCard(_recipes[index], index, _expandedIndex == index);
                  },
                ),

          // 대화형 추천 탭
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Iconsax.message, color: Colors.grey, size: 60),
                            SizedBox(height: 16),
                            Text(
                              '원하는 요리를 말해보세요!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '"감자랑 계란 들어가는 요리 추천해줘"\n"매운거 먹고싶어"\n"10분 안에 만들 수 있는거"',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isChatLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  CircularProgressIndicator(strokeWidth: 2),
                                  SizedBox(width: 8),
                                  Text('AI가 생각중이에요...'),
                                ],
                              ),
                            );
                          }
                          final msg = _messages[index];
                          final isUser = msg['role'] == 'user';
                          return Column(
                            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser ? const Color(0xFF4A90D9) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  msg['content'],
                                  style: TextStyle(color: isUser ? Colors.white : Colors.black),
                                ),
                              ),
                              if (!isUser && (msg['recipes'] as List).isNotEmpty)
                                ...((msg['recipes'] as List<dynamic>).asMap().entries.map(
                                  (entry) => _buildRecipeCard(
                                    entry.value,
                                    1000 + index * 100 + entry.key,
                                    _expandedIndex == 1000 + index * 100 + entry.key,
                                  ),
                                )),
                            ],
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          hintText: '요리 관련 질문을 해보세요!',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90D9),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _recipes.isNotEmpty && _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _loadRecipes,
              backgroundColor: const Color(0xFF4A90D9),
              child: const Icon(Icons.refresh, color: Colors.white),
            )
          : null,
    );
  }
}

class _WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const _WebViewScreen({required this.url, required this.title});

  @override
  State<_WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<_WebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.export),
            onPressed: () async {
              final uri = Uri.parse(widget.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}