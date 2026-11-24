import 'package:get/get.dart';
import '../../../application/routes/app_routes.dart';
import '../../../common/helpers/api_feedback.dart';
import '../../../services/api/api_client.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/auth/warehouse_context.dart';

/// Ringkasan operasional gudang aktif (GET /api/dashboard/operational).
class OperationalSummary {
  const OperationalSummary(this.data);
  final Map<String, dynamic> data;

  int _batches(String key) => ((data[key] as Map?)?['batches'] as num?)?.toInt() ?? 0;
  int _qty(String key) => ((data[key] as Map?)?['quantity'] as num?)?.toInt() ?? 0;
  int _doc(String key) => ((data['openDocuments'] as Map?)?[key] as num?)?.toInt() ?? 0;

  int get putawayBatches => _batches('putawayPending');
  int get qcPendingBatches => _batches('qcPending');
  int get qcHoldBatches => _batches('qcHold');
  int get qcPassedBatches => _batches('qcPassedAwaitingRelease');
  int get qcRejectedBatches => _batches('qcRejected');
  int get availableQty => _qty('available');
  int get qcQty => _qty('qcPending') + _qty('qcHold') + _qty('qcPassedAwaitingRelease') + _qty('qcRejected');
  int get inTransitQty => _qty('inTransitInbound');
  int get expiringBatches => _batches('expiringIn30Days');
  int get lowStock => (data['lowStockProducts'] as num?)?.toInt() ?? 0;
  int get openReceivings => _doc('receivings');
  int get openIssuings => _doc('issuings');
  int get inboundTransfers => _doc('transfersInbound');
  int get draftOpnames => _doc('stockOpnames');
  /// PO / SO dari ERP yang belum selesai diproses gudang.
  int get openInboundDocuments => _doc('inboundDocuments');
  int get openOutboundDocuments => _doc('outboundDocuments');
  /// Pengiriman: issuing siap packing, packing siap dimuat, shipment sedang dimuat / dalam perjalanan.
  int get packingQueue => _doc('packingQueue');
  int get packedReady => _doc('packedReady');
  int get shipmentsLoading => _doc('shipmentsLoading');
  int get shipmentsInTransit => _doc('shipmentsInTransit');
}

class DashboardController extends GetxController {
  final ctx = WarehouseContext.instance;
  final summary = Rxn<OperationalSummary>();
  final isLoading = false.obs;

  String get userName => ctx.userName.value.isEmpty ? AuthService.instance.displayName : ctx.userName.value;

  @override
  void onInit() {
    super.onInit();
    ever(ctx.activeId, (_) => loadSummary());
    refreshAll();
  }

  /// Sinkronkan hak akses gudang dari server lalu muat ringkasan.
  Future<void> refreshAll() async {
    try {
      await ctx.refresh();
    } catch (e) {
      showApiError(e, title: 'Gagal memuat hak akses gudang');
    }
    await loadSummary();
  }

  Future<void> loadSummary() async {
    if (ctx.activeId.value.isEmpty) {
      summary.value = null;
      return;
    }
    isLoading.value = true;
    try {
      final data = await ApiClient.instance.get('/dashboard/operational', query: {'warehouseId': ctx.activeId.value});
      summary.value = OperationalSummary(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      showApiError(e, title: 'Gagal memuat ringkasan');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> open(String route) async {
    if (!ctx.hasActive) {
      Get.snackbar('Gudang belum tersedia', 'Akun Anda belum memiliki akses gudang. Hubungi administrator.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    await Get.toNamed(route);
    await loadSummary();
  }

  /// Kompatibilitas: drawer lama memanggil openModule dengan judul menu.
  void openModule(String title) {
    const routes = {
      'Gudang & Lokasi': AppRoutes.warehouse,
      'Penerimaan Barang': AppRoutes.receiving,
      'Pengeluaran Barang': AppRoutes.issuing,
      'Transfer Barang': AppRoutes.transfers,
      'Stock Opname': AppRoutes.stockOpname,
      'Produk & Kategori': AppRoutes.products,
      'Riwayat Aktivitas': AppRoutes.history,
    };
    final route = routes[title];
    if (route != null) {
      open(route);
    } else {
      Get.toNamed(AppRoutes.module, arguments: title);
    }
  }

  void logout() => AuthService.instance.logout();
  void showNotifications() => Get.snackbar('Notifikasi', 'Belum ada notifikasi baru.');
}
