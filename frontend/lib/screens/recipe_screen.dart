import 'package:flutter/material.dart';
import '../api_service.dart';

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key});

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  List<dynamic> _recipes = [];
  bool _isLoading = false;

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    final recipes = await ApiService.getRecipes();
    setState(() {
      _recipes = recipes;
      _isLoading = false;
    });
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  recipe['name'],
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA8D8EA).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    recipe['difficulty'],
                                    style: const TextStyle(
                                        color: Color(0xFF4A90D9)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.timer, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${recipe['cooking_time']}분',
                                    style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('필요 재료',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: (recipe['ingredients_needed'] as List<dynamic>)
                                  .map((i) => Chip(
                                        label: Text(i),
                                        backgroundColor:
                                            const Color(0xFFA8D8EA).withOpacity(0.3),
                                      ))
                                  .toList(),
                            ),
                            if ((recipe['missing_ingredients'] as List<dynamic>).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('없는 재료',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: (recipe['missing_ingredients'] as List<dynamic>)
                                    .map((i) => Chip(
                                          label: Text(i),
                                          backgroundColor: Colors.red.withOpacity(0.1),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
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
