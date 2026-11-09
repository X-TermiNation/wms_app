import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/routes/app_routes.dart';

class AuthenticationController extends GetxController {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordVisible = false.obs;
  final isLoading = false.obs;

  void login() {
    if (usernameController.text.trim().isEmpty || passwordController.text.isEmpty) {
      Get.snackbar('Data belum lengkap', 'Masukkan username dan password terlebih dahulu.', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF252B35), colorText: Colors.white);
      return;
    }
    // Simulasi login. Autentikasi API akan ditambahkan pada tahap backend.
    Get.offAllNamed(AppRoutes.dashboard);
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
