import 'package:flutter/material.dart';
import '../api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _tempPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _sendTempPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await ApiService.forgotPassword(_emailController.text);
    setState(() => _isLoading = false);

    if (result['message'] != null) {
      setState(() => _emailSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('임시 비밀번호를 이메일로 발송했어요! 📧')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['detail'] ?? '오류가 발생했어요')),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_tempPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요')),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새 비밀번호가 일치하지 않아요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await ApiService.resetPassword(
      email: _emailController.text,
      tempPassword: _tempPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    setState(() => _isLoading = false);

    if (result['message'] != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 변경됐어요! 다시 로그인해주세요 😄')),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['detail'] ?? '오류가 발생했어요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('아이디/비밀번호 찾기',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📧 이메일로 임시 비밀번호 받기',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    '가입 시 사용한 이메일로 임시 비밀번호를 보내드려요',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_emailSent,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      prefixIcon: Icon(Icons.email, color: Color(0xFF4A90D9)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!_emailSent)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _sendTempPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('임시 비밀번호 받기'),
                      ),
                    ),

                  if (_emailSent) ...[
                    const SizedBox(height: 32),
                    const Text('🔐 비밀번호 재설정',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tempPasswordController,
                      decoration: const InputDecoration(
                        labelText: '임시 비밀번호 (이메일 확인)',
                        prefixIcon:
                            Icon(Icons.lock_open, color: Color(0xFF4A90D9)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '새 비밀번호',
                        prefixIcon:
                            Icon(Icons.lock, color: Color(0xFF4A90D9)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '새 비밀번호 확인',
                        prefixIcon:
                            Icon(Icons.lock, color: Color(0xFF4A90D9)),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90D9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('비밀번호 변경하기'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}