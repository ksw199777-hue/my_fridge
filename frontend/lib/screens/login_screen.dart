import 'package:flutter/material.dart';
import '../api_service.dart';
import 'fridge_select_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _emailLocalController = TextEditingController();
  final _customDomainController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  String _selectedDomain = 'naver.com';

  String get _fullEmail => _isLogin
      ? _emailController.text
      : _selectedDomain == '직접입력'
          ? '${_emailLocalController.text}@${_customDomainController.text}'
          : '${_emailLocalController.text}@$_selectedDomain';

  Future<void> _submit() async {
    if (_fullEmail.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> result;
      if (_isLogin) {
        result = await ApiService.login(
          _fullEmail,
          _passwordController.text,
        );
      } else {
        if (_usernameController.text.isEmpty) {
          setState(() => _isLoading = false);
          return;
        }
        result = await ApiService.register(
          _fullEmail,
          _usernameController.text,
          _passwordController.text,
        );
      }

      if (result['token'] != null) {
        await ApiService.saveToken(result['token']);
        if (result['user'] != null && result['user']['subscription_type'] != null) {
          await ApiService.setSubscriptionType(result['user']['subscription_type']);
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const FridgeSelectScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['detail'] ?? '오류가 발생했어요')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('네트워크 오류가 발생했어요')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.kitchen, size: 80, color: Color(0xFF4A90D9)),
                    SizedBox(height: 16),
                    Text(
                      '시워냉',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A90D9),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'AI가 관리하는 스마트 냉장고',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Text(
                _isLogin ? '로그인' : '회원가입',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (!_isLogin) ...[
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, color: Color(0xFF4A90D9)),
                  ),
                ),
                const SizedBox(height: 12),
                // 회원가입 시 이메일 도메인 선택
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _emailLocalController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: '이메일 아이디',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email, color: Color(0xFF4A90D9)),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('@', style: TextStyle(fontSize: 18)),
                    ),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedDomain,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          'naver.com',
                          'gmail.com',
                          'kakao.com',
                          'daum.net',
                          'nate.com',
                          'hanmail.net',
                          '직접입력',
                        ].map((domain) => DropdownMenuItem(
                          value: domain,
                          child: Text(domain, style: const TextStyle(fontSize: 13)),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedDomain = value!),
                      ),
                    ),
                  ],
                ),
                if (_selectedDomain == '직접입력') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customDomainController,
                    decoration: const InputDecoration(
                      labelText: '도메인 직접 입력',
                      border: OutlineInputBorder(),
                      prefixText: '@',
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.warning_amber, size: 12, color: Colors.red),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '실제 사용 중인 이메일을 입력해주세요. 비밀번호 찾기에 사용돼요!',
                        style: TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // 로그인 시 이메일 입력
              if (_isLogin)
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email, color: Color(0xFF4A90D9)),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock, color: Color(0xFF4A90D9)),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90D9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isLogin ? '로그인' : '회원가입',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                    style: const TextStyle(color: Color(0xFF4A90D9)),
                  ),
                ),
              ),
              if (_isLogin)
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      '아이디/비밀번호 찾기',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}