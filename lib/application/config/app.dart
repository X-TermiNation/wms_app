import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    initialRoute: AppRoutes.login,
    getPages: AppPages.pages,
  );
}
