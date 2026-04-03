import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String url) async {
  final Uri url0 = Uri.parse(url);
  if (!await launchUrl(url0)) {
    showSnackBar('could_not_launch_url'.trParams({'url': url}));
  }
}

void showSnackBar(
  String message, {
  Duration duration = const Duration(seconds: 3),
  SnackPosition snackPosition = SnackPosition.BOTTOM,
}) {
  Get.snackbar(
    '',
    '',
    backgroundColor: Colors.transparent,
    snackPosition: snackPosition,
    duration: duration,
    titleText: const SizedBox.shrink(),
    messageText: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.black87,
        ),
        child: Text(message, style: TextStyle(color: Colors.white)),
      ),
    ),
    margin: const EdgeInsets.all(30),
  );
}

Future<bool?> getSubscriptionStatus() async {
  bool isActive = false;
  try {
    CustomerInfo customerInfo = await Purchases.getCustomerInfo();
    print(customerInfo);
    final entitlement = customerInfo.entitlements.all["Pro"];
    print(customerInfo);
    if (entitlement?.isActive ?? false) {
      // Unlock that great "pro" content
      isActive = true;
    } else {
      isActive = false;
    }
    return isActive;
  } on PlatformException catch (e) {
    // Error fetching customer info
    return null;
  }
}
