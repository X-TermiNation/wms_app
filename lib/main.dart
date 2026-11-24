import 'package:flutter/widgets.dart';
import 'application/config/app.dart';
import 'services/auth/auth_service.dart';
import 'services/storage/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionStorage.instance.init();
  AuthService.instance.init();
  runApp(const WmsApp());
}
