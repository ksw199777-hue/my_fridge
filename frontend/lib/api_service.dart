import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://127.0.0.1:8000';

class ApiService {
  // 재료 목록 조회
  static Future<List<dynamic>> getIngredients() async {
    final response = await http.get(Uri.parse('$baseUrl/ingredients'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['ingredients'];
    }
    return [];
  }

  // 재료 인식 (사진)
  static Future<List<dynamic>> recognizeIngredient(Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/recognize'));
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final data = jsonDecode(body);
      return data['ingredients'];
    }
    return [];
  }

  // 재료 삭제
  static Future<bool> deleteIngredient(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/ingredients/$id'));
    return response.statusCode == 200;
  }

  // 유통기한 임박 재료
  static Future<Map<String, dynamic>> getExpiringIngredients() async {
    final response = await http.get(Uri.parse('$baseUrl/ingredients/expiring?days=7'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {};
  }

  // 레시피 추천
  static Future<List<dynamic>> getRecipes() async {
    final response = await http.get(Uri.parse('$baseUrl/recipes'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['recipes'];
    }
    return [];
  }

  // 수동 재료 등록
  static Future<bool> createIngredient(String name, int expiryDays, int price, String location) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ingredients'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'expiry_days': expiryDays,
        'price': price,
        'location': location,
      }),
    );
    return response.statusCode == 200;
  }

  // 월별 가계부
  static Future<Map<String, dynamic>> getMonthlyExpenses(int year, int month) async {
    final response = await http.get(Uri.parse('$baseUrl/expenses/monthly?year=$year&month=$month'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {};
  }

  // 통계
  static Future<Map<String, dynamic>> getStatistics() async {
    final response = await http.get(Uri.parse('$baseUrl/statistics'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {};
  }
}