import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/config/app_config.dart';
import '../../../application/routes/app_routes.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/storage/session_storage.dart';

class AuthenticationController extends GetxController {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordVisible = false.obs;
  final isLoading = false.obs;

  Future<void> login() async {
    if (isLoading.value) return;
    if (usernameController.text.trim().isEmpty || passwordController.text.isEmpty) {
      Get.snackbar('Data belum lengkap', 'Masukkan username dan password terlebih dahulu.', snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF252B35), colorText: Colors.white);
      return;
    }
    isLoading.value = true;
    try {
      await AuthService.instance.login(usernameController.text.trim(), passwordController.text);
      passwordController.clear();
      Get.offAllNamed(AppRoutes.dashboard);
    } catch (e) {
      showApiError(e, title: 'Login gagal');
    } finally {
      isLoading.value = false;
    }
  }

  /// Dialog untuk mengubah URL backend (berguna untuk perangkat SUNMI).
  void openServerSettings() {
    final field = TextEditingController(text: SessionStorage.instance.baseUrl);
    final testing = false.obs;
    Get.dialog(AlertDialog(
      title: const Text('Pengaturan Server'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: field,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'URL API', hintText: AppConfig.apiBaseUrl, border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        const Text('Default lokal: ${AppConfig.apiBaseUrl}\nKosongkan lalu Simpan untuk kembali ke default.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      ]),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Batal')),
        Obx(() => TextButton(
          onPressed: testing.value ? null : () async {
            testing.value = true;
            try {
              await ApiClient.instance.ping(field.text);
              showSuccess('Terhubung', 'Server dapat diakses.');
            } catch (e) {
              showApiError(e, title: 'Koneksi gagal');
            } finally {
              testing.value = false;
            }
          },
          child: Text(testing.value ? 'Menguji...' : 'Tes Koneksi'),
        )),
        FilledButton(
          onPressed: () async {
            await SessionStorage.instance.saveBaseUrl(field.text);
            Get.back();
            showSuccess('Tersimpan', 'URL server: ${SessionStorage.instance.baseUrl}');
          },
          child: const Text('Simpan'),
        ),
      ],
    ));
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
