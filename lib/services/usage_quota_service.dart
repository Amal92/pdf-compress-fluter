import 'package:get/get.dart';
import '../models/models.dart';
import 'api_service.dart';

/// Free-tier cap on lifetime pages compressed (until API exposes a dedicated field).
const int kFreeMaxCompressedPages = 20;

class UsageQuotaService extends GetxService {
  final _api = Get.find<ApiService>();

  final Rx<UsageResponse?> usage = Rx<UsageResponse?>(null);

  int get pagesCompressedTotal => usage.value?.totalPagesCompressed ?? 0;

  Future<void> fetchUsage() async {
    try {
      final u = await _api.getUsage();
      usage.value = u;
    } catch (_) {
      // Silently ignore — server errors for usage are non-fatal; usage state
      // stays at whatever was last known.
    }
  }

  /// Refreshes usage counts from the server for free-tier users only.
  /// Pro vs free is determined by RevenueCat ([isUserPro]), not the usage API.
  Future<void> refreshUsageIfFreeTier(bool isUserPro) async {
    if (isUserPro) return;
    await fetchUsage();
  }
}
