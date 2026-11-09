import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../application/constants/app_colors.dart';
import '../../../application/constants/app_strings.dart';
import '../../../common/widgets/app_primary_button.dart';
import '../controllers/authentication_controller.dart';

class LoginView extends GetView<AuthenticationController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: Column(children: [
        _LoginHero(),
        Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Masuk ke Aplikasi', textAlign: TextAlign.center, style: TextStyle(color: AppColors.charcoal, fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Silakan gunakan akun Anda untuk login', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 28),
          TextField(controller: controller.usernameController, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 14),
          Obx(() => TextField(controller: controller.passwordController, obscureText: !controller.passwordVisible.value, onSubmitted: (_) => controller.login(), decoration: InputDecoration(hintText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: controller.passwordVisible.toggle, icon: Icon(controller.passwordVisible.value ? Icons.visibility_outlined : Icons.visibility_off_outlined))))),
          const SizedBox(height: 24),
          AppPrimaryButton(label: AppStrings.login, icon: Icons.login_rounded, onPressed: controller.login),
          const SizedBox(height: 28),
          const Divider(color: AppColors.border),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.settings_outlined, color: AppColors.charcoal), title: const Text('Pengaturan Server', style: TextStyle(fontSize: 13)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Get.snackbar('Pengaturan Server', 'Konfigurasi URL API akan tersedia saat integrasi backend.')),
          const Divider(color: AppColors.border),
          const SizedBox(height: 10),
          const Text('${AppStrings.appName} • ${AppStrings.version}', textAlign: TextAlign.center, style: TextStyle(color: Colors.black45, fontSize: 11)),
        ])),
      ])),
    ))),
  );
}

class _LoginHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, height: 205, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.darkOrange, AppColors.primary, Color(0xFFFFA34D)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(34))), child: Stack(children: [
    const Positioned(right: -35, top: -55, child: _CircleDecoration(size: 190)),
    const Positioned(left: -50, bottom: -105, child: _CircleDecoration(size: 190)),
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.warehouse_rounded, size: 42, color: AppColors.primary)), const SizedBox(height: 10), const Text('WMS', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 2)), const Text('Warehouse Management System', style: TextStyle(color: Colors.white, fontSize: 12))])),
  ]));
}

class _CircleDecoration extends StatelessWidget {
  const _CircleDecoration({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .13), width: 22)));
}
