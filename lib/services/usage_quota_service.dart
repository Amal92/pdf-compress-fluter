import 'package:get/get.dart';
import '../models/models.dart';
import 'api_service.dart';

/// Free-tier cap on lifetime pages compressed (until API exposes a dedicated field).
const int kFreeMaxCompressedPages = 20;

class UsageQuotaService extends GetxService {
  final _api = Get.find<ApiService>();

  final Rx<UsageResponse?> usage = Rx<UsageResponse?>(null);
  final RxBool quotaExceeded = false.obs;
  final RxBool unlimited = false.obs;

  int get pagesCompressedTotal => usage.value?.totalPagesCompressed ?? 0;

  Future<void> fetchUsage() async {
    try {
      final u = await _api.getUsage();
      _applyUsage(u);
    } catch (_) {
      // Silently ignore — server errors for usage are non-fatal; quota state
      // stays at whatever was last known (or default: not exceeded).
    }
  }

  /// Call after a successful compress job. Skips the network call when the
  /// user is already on an unlimited plan — no quota to track there.
  Future<void> refreshIfFree() async {
    if (unlimited.value) return;
    await fetchUsage();
  }

  void _applyUsage(UsageResponse u) {
    usage.value = u;
    unlimited.value = u.unlimited;
    quotaExceeded.value =
        !u.unlimited && u.totalPagesCompressed >= kFreeMaxCompressedPages;
  }
}
