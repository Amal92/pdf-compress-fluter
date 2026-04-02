import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';
import '../services/usage_quota_service.dart';

class AuthController extends GetxController {
  final _api = Get.find<ApiService>();
  final _tokenStorage = TokenStorage();
  final _firebaseAuth = FirebaseAuth.instance;

  final RxBool isLoading = true.obs;
  final RxBool isAuthenticated = false.obs;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    isLoading.value = true;
    try {
      // If we already have a stored backend token, try to validate it first.
      final existing = await _tokenStorage.getAccessToken();
      if (existing != null) {
        // Token exists — assume session is valid (ApiService will refresh on 401).
        isAuthenticated.value = true;
        isLoading.value = false;
        Get.find<UsageQuotaService>().fetchUsage();
        return;
      }

      // No stored token — sign in anonymously with Firebase, then exchange.
      await _signInAndExchange();
    } catch (_) {
      await _tokenStorage.clearAll();
      isAuthenticated.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _signInAndExchange() async {
    // Reuse existing Firebase anonymous session if available.
    final firebaseUser = _firebaseAuth.currentUser ??
        (await _firebaseAuth.signInAnonymously()).user;

    if (firebaseUser == null) return;

    final idToken = await firebaseUser.getIdToken();
    if (idToken == null) return;

    final response = await _api.authenticate(idToken);

    await _tokenStorage.saveTokens(
      accessToken: response['access_token'] as String,
      refreshToken: response['refresh_token'] as String,
    );

    isAuthenticated.value = true;
    Get.find<UsageQuotaService>().fetchUsage();
  }
}
