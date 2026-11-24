import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/api/api_client.dart';

/// Tampilkan pesan error dari API / jaringan sebagai snackbar.
void showApiError(Object error, {String title = 'Tidak dapat diproses'}) {
  // 401 sudah ditangani AuthService (redirect ke login).
  if (error is ApiException && error.isUnauthorized) return;
  final message = error is ApiException ? error.message : 'Terjadi kesalahan: $error';
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: const Color(0xFF252B35),
    colorText: Colors.white,
    duration: const Duration(seconds: 4),
  );
}

void showSuccess(String title, String message) {
  Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
}

/// Jalankan [action]; tampilkan snackbar jika gagal. Mengembalikan true jika sukses.
Future<bool> runApi(Future<void> Function() action, {String errorTitle = 'Tidak dapat diproses'}) async {
  try {
    await action();
    return true;
  } catch (e) {
    showApiError(e, title: errorTitle);
    return false;
  }
}
