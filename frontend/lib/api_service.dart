import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

const String baseUrl = 'https://myfridge-production-8a71.up.railway.app';

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
  static Future<Map<String, dynamic>> recognizeIngredientWithMessage(Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/recognize'));
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body);
    }
    return {'ingredients': [], 'message': null};
  }

  // 재료 삭제
  static Future<bool> deleteIngredient(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/ingredients/$id'));
    return response.statusCode == 200;
  }

  // 재료 수정
  static Future<bool> updateIngredient(
    int id, {
    String? name,
    int? consumeDays,
    int? price,
    String? location,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (consumeDays != null) body['consume_days'] = consumeDays;
    if (price != null) body['price'] = price;
    if (location != null) body['location'] = location;

    final response = await http.put(
      Uri.parse('$baseUrl/ingredients/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
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
  static Future<bool> createIngredient(
    String name,
    int? expiryDays,
    int consumeDays,
    int price,
    String location,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ingredients'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'expiry_days': expiryDays,
        'consume_days': consumeDays,
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

  // 쇼핑리스트 조회
  static Future<List<dynamic>> getShoppingList() async {
    final response = await http.get(Uri.parse('$baseUrl/shopping'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['shopping_list'];
    }
    return [];
  }

  // 쇼핑 아이템 추가
  static Future<bool> addShoppingItem(String name, int quantity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shopping'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'quantity': quantity}),
    );
    return response.statusCode == 200;
  }

  // 구매 완료
  static Future<bool> markPurchased(int id) async {
    final response = await http.put(Uri.parse('$baseUrl/shopping/$id/purchased'));
    return response.statusCode == 200;
  }

  // 쇼핑 아이템 삭제
  static Future<bool> deleteShoppingItem(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/shopping/$id'));
    return response.statusCode == 200;
  }

  // 영수증 인식
  static Future<Map<String, dynamic>> recognizeReceiptWithMessage(Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/recognize/receipt'));
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body);
    }
    return {'ingredients': [], 'message': null};
  }

  // 스크린샷 인식
  static Future<Map<String, dynamic>> recognizeScreenshotWithMessage(Uint8List imageBytes) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/recognize/screenshot'));
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body);
    }
    return {'ingredients': [], 'message': null};
  }

    // 레시피 채팅
  static Future<Map<String, dynamic>> recipeChat(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipe/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {'response': '오류가 발생했어요', 'recipes': []};
  }
}