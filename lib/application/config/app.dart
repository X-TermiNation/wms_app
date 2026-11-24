import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/storage/session_storage.dart';
import '../routes/app_pages.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

class WmsApp extends StatelessWidget {
  const WmsApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'WMS App',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    // Jika token tersimpan, langsung ke dashboard. Token yang sudah tidak
    // valid akan dialihkan ke login otomatis saat API membalas 401.
    initialRoute: SessionStorage.instance.hasToken ? AppRoutes.dashboard : AppRoutes.login,
    getPages: AppPages.pages,
  );
}
