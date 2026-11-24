abstract final class AppConfig {
  static const appName = 'WMS SUNMI';
  static const appVersion = '1.0.0';

  /// URL default backend (folder `warehouse_management_backend`) untuk akses
  /// lokal: IP Wi-Fi komputer server 192.168.110.116, port 3000.
  /// Dipakai oleh perangkat SUNMI / HP fisik maupun emulator di jaringan yang sama.
  /// Jika IP komputer berubah, override saat build:
  ///   flutter run --dart-define=API_BASE_URL=http://IP-BARU:3000/api
  /// atau ubah dari menu "Pengaturan Server" di halaman login.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.148:3000/api',
  );

  static const apiTimeout = Duration(seconds: 20);
}
