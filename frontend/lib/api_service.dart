import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'https://myfridge-production-8a71.up.railway.app';

class ApiService {
  static String? _token;
  static int? _currentFridgeId;
  static String _subscriptionType = 'free';

  static String get subscriptionType => _subscriptionType;

  static Future<void> setSubscriptionType(String type) async {
    _subscriptionType = type;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _currentFridgeId = prefs.getInt('current_fridge_id');
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> saveFridgeId(int fridgeId) async {
    _currentFridgeId = fridgeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_fridge_id', fridgeId);
  }

  static Future<void> logout() async {
    _token = null;
    _currentFridgeId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static bool get isLoggedIn => _token != null;
  static int? get currentFridgeId => _currentFridgeId;

  // 회원가입
  static Future<Map<String, dynamic>> register(
    String email,
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // 로그인
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // 내 정보
  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // 구독 플랜 변경
  static Future<bool> updateSubscription({
    required String subscriptionType,
    int extraMembers = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/subscription'),
      headers: _headers,
      body: jsonEncode({
        'subscription_type': subscriptionType,
        'extra_members': extraMembers,
      }),
    );
    if (response.statusCode == 200) {
      _subscriptionType = subscriptionType;
      return true;
    }
    return false;
  }

  // 냉장고 목록
  static Future<List<dynamic>> getFridges() async {
    final response = await http.get(
      Uri.parse('$baseUrl/fridges'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))['fridges'];
    }
    return [];
  }

  // 냉장고 생성
  static Future<Map<String, dynamic>> createFridge(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/fridges'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // 냉장고 참여
  static Future<Map<String, dynamic>> joinFridge(String inviteCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/fridges/join?invite_code=$inviteCode'),
      headers: _headers,
    );
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // 재료 목록
  static Future<List<dynamic>> getIngredients() async {
    if (_currentFridgeId == null) return [];
    final response = await http.get(
      Uri.parse('$baseUrl/ingredients?fridge_id=$_currentFridgeId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))['ingredients'];
    }
    return [];
  }

  // 재료 추가
  static Future<bool> addIngredient({
    required String name,
    int? expiryDays,
    int consumeDays = 7,
    int price = 0,
    String location = '냉장',
    String storageType = '냉장',
    bool hasExpiryLabel = false,
  }) async {
    if (_currentFridgeId == null) return false;
    final response = await http.post(
      Uri.parse('$baseUrl/ingredients?fridge_id=$_currentFridgeId'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'expiry_days': expiryDays,
        'consume_days': consumeDays,
        'price': price,
        'location': location,
        'storage_type': storageType,
        'has_expiry_label': hasExpiryLabel,
      }),
    );
    return response.statusCode == 200;
  }

  // 재료 인식
  static Future<Map<String, dynamic>> recognizeIngredients(
    List<int> imageBytes,
  ) async {
    if (_currentFridgeId == null) return {};
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/recognize?fridge_id=$_currentFridgeId'),
    );
    request.headers.addAll({'Authorization': 'Bearer $_token'});
    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'),
    );
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return jsonDecode(body);
  }

  // 영수증 인식
  static Future<Map<String, dynamic>> recognizeReceipt(
    List<int> imageBytes,
  ) async {
    if (_currentFridgeId == null) return {};
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/recognize/receipt?fridge_id=$_currentFridgeId'),
    );
    request.headers.addAll({'Authorization': 'Bearer $_token'});
    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'),
    );
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return jsonDecode(body);
  }

  // 스크린샷 인식
  static Future<Map<String, dynamic>> recognizeScreenshot(
    List<int> imageBytes,
  ) async {
    if (_currentFridgeId == null) return {};
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/recognize/screenshot?fridge_id=$_currentFridgeId'),
    );
    request.headers.addAll({'Authorization': 'Bearer $_token'});
    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'),
    );
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return jsonDecode(body);
  }

  // 재료 수정
  static Future<bool> updateIngredient(
    int id, {
    String? name,
    int? consumeDays,
    int? price,
    String? location,
    String? storageType,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/ingredients/$id'),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (consumeDays != null) 'consume_days': consumeDays,
        if (price != null) 'price': price,
        if (location != null) 'location': location,
      }),
    );
    return response.statusCode == 200;
  }

  // 재료 삭제
  static Future<bool> deleteIngredient(
    int id, {
    bool deleteHistory = false,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/ingredients/$id?delete_history=$deleteHistory'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

  // 임박 재료
  static Future<Map<String, dynamic>> getExpiringIngredients() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ingredients/expiring'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {};
  }

  // 레시피 추천
  static Future<Map<String, dynamic>> getRecipes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/recipes'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 403) {
      return {'error': 'premium', 'recipes': []};
    }
    return {'recipes': []};
  }

  // 레시피 채팅
  static Future<Map<String, dynamic>> recipeChat(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipe/chat'),
      headers: _headers,
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 403) {
      return {'error': 'premium', 'response': '', 'recipes': []};
    }
    return {'response': '오류가 발생했어요', 'recipes': []};
  }

  // 쇼핑 목록
  static Future<List<dynamic>> getShoppingList() async {
    if (_currentFridgeId == null) return [];
    final response = await http.get(
      Uri.parse('$baseUrl/shopping?fridge_id=$_currentFridgeId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))['shopping_list'];
    }
    return [];
  }

  // 쇼핑 아이템 추가
  static Future<bool> addShoppingItem(String name, String quantity) async {
    if (_currentFridgeId == null) return false;
    final response = await http.post(
      Uri.parse('$baseUrl/shopping?fridge_id=$_currentFridgeId'),
      headers: _headers,
      body: jsonEncode({'name': name, 'quantity': quantity}),
    );
    return response.statusCode == 200;
  }

  // 쇼핑 구매 완료
  static Future<bool> markPurchased(int id) async {
    final response = await http.put(
      Uri.parse('$baseUrl/shopping/$id/purchased'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

  // 쇼핑 아이템 삭제
  static Future<bool> deleteShoppingItem(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/shopping/$id'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

  // 쇼핑 예상 가격
  static Future<Map<String, dynamic>> estimateShoppingPrice() async {
    final response = await http.get(
      Uri.parse('$baseUrl/shopping/estimate'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 403) {
      return {'error': 'premium', 'items': [], 'total': 0};
    }
    return {'items': [], 'total': 0};
  }

  // 월별 가계부
  static Future<Map<String, dynamic>> getMonthlyExpenses(
    int year,
    int month,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/expenses/monthly?year=$year&month=$month'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {};
  }

  // 월별 가계부 히스토리
  static Future<Map<String, dynamic>> getExpenseHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/expenses/history'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {};
  }

  // 통계
  static Future<Map<String, dynamic>> getStatistics() async {
    final response = await http.get(
      Uri.parse('$baseUrl/statistics'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {};
  }

  // 냉장고 삭제
  static Future<bool> deleteFridge(int fridgeId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/fridges/$fridgeId'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

  // FCM 토큰 저장
  static Future<void> updateFcmToken(String token) async {
    await http.post(
      Uri.parse('$baseUrl/auth/fcm-token'),
      headers: _headers,
      body: jsonEncode({'fcm_token': token}),
    );
  }

  // 소비기한 계산
  static Future<int> calculateConsumeDays({
    required String name,
    required String storageType,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ingredients/calculate-consume-days'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'storage_type': storageType,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['consume_days'] ?? 7;
    }
    return 7;
  }

  // 냉장고 멤버 조회
  static Future<Map<String, dynamic>> getFridgeMembers(int fridgeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/fridges/$fridgeId/members'),
      headers: _headers,
    );
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  // 멤버 내보내기
  static Future<bool> removeFridgeMember(int fridgeId, int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/fridges/$fridgeId/members/$userId'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

// 예산 조회
static Future<Map<String, dynamic>> getBudget(int year, int month) async {
  final response = await http.get(
    Uri.parse('$baseUrl/budget?year=$year&month=$month'),
    headers: _headers,
  );
  if (response.statusCode == 200) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
  return {'budget': 0, 'memo': ''};
}

// 예산 저장
static Future<bool> setBudget(int year, int month, int budget, String memo) async {
  final response = await http.post(
    Uri.parse('$baseUrl/budget'),
    headers: _headers,
    body: jsonEncode({
      'year': year,
      'month': month,
      'budget': budget,
      'memo': memo,
    }),
  );
  return response.statusCode == 200;
}
}