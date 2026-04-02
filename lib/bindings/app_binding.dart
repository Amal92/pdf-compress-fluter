import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/usage_quota_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/compression_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ApiService>(ApiService(), permanent: true);
    Get.put<UsageQuotaService>(UsageQuotaService(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<CompressionController>(CompressionController(), permanent: true);
  }
}
