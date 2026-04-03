import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf_compress_mobile/utils/utils.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Pro plan bullet benefits (paywall and upsell dialogs).
class PaywallProBenefitsList extends StatelessWidget {
  const PaywallProBenefitsList({super.key});

  static const Color _checkColor = Color(0xFFFF3680);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: _checkColor, size: 24.0),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Compress Unlimited PDFs',
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 16.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: _checkColor, size: 24.0),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Compress PDFs with file sizes up to 50MB',
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 16.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: _checkColor, size: 24.0),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'Batch Compress Multiple PDFs at Once',
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 16.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PaywallDialog extends StatefulWidget {
  final bool fromOnboarding;

  // Constructor
  PaywallDialog({required this.fromOnboarding});

  @override
  State<PaywallDialog> createState() => PaywallDialogState();
}

class PaywallDialogState extends State<PaywallDialog> {
  int currentSelected = 1;
  Package? weeklyPackage;
  Package? annualPackage;

  String annualPrice = "";
  String weeklyPrice = "";
  String freeTrialPeriod = "";
  String savePercentage = "";

  var subscriptionOnGoing = false;

  @override
  void initState() {
    getOfferings();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', width: 60),
                const SizedBox(height: 16.0),
                Text(
                  'paywall_unlimited_access'.tr,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26.0),
                ),
                const SizedBox(height: 18.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 35.0),
                  child: PaywallProBenefitsList(),
                ),
                const SizedBox(height: 24.0),

                const SizedBox(height: 24.0),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      currentSelected = 0;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: currentSelected == 0
                            ? Color(0xFFFF3680)
                            : Colors.black26, // Border color
                        width: 1, // Border width
                      ),
                      borderRadius: BorderRadius.circular(
                        8,
                      ), // Rounded corners (optional)
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yearly Plan',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18.0,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'paywall_per_year'.trParams({
                                'price': annualPrice,
                              }),
                              style: TextStyle(fontSize: 16.0),
                            ),
                          ],
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // Rounded corners (optional)
                          ),
                          child: Text(
                            'paywall_save_percentage'.trParams({
                              'percentage': '$savePercentage%',
                            }),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        currentSelected == 0
                            ? Icon(
                                Icons.radio_button_checked,
                                color: Color(0xFFFF3680),
                              )
                            : Icon(Icons.radio_button_off, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      currentSelected = 1;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: currentSelected == 1
                            ? Color(0xFFFF3680)
                            : Colors.black26, // Border color
                        width: 1, // Border width
                      ),
                      borderRadius: BorderRadius.circular(
                        8,
                      ), // Rounded corners (optional)
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              freeTrialPeriod.isEmpty
                                  ? 'paywall_weekly_plan'.tr
                                  : 'paywall_trial_period'.trParams({
                                      'trialPeriod': freeTrialPeriod,
                                    }),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18.0,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              freeTrialPeriod.isEmpty
                                  ? 'paywall_per_week'.trParams({
                                      'price': weeklyPrice,
                                    })
                                  : 'paywall_then_per_week'.trParams({
                                      'price': weeklyPrice,
                                    }),
                              style: TextStyle(fontSize: 16.0),
                            ),
                          ],
                        ),
                        Spacer(),
                        currentSelected == 1
                            ? Icon(
                                Icons.radio_button_checked,
                                color: Color(0xFFFF3680),
                              )
                            : Icon(Icons.radio_button_off, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                Visibility(
                  visible: freeTrialPeriod.isNotEmpty,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(
                        8,
                      ), // Rounded corners (optional)
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'paywall_trial_enabled'.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18.0,
                          ),
                        ),
                        Spacer(),
                        Switch(
                          value: currentSelected == 1,
                          activeColor: Color(0xFFFF3680),
                          onChanged: (bool value) {
                            if (value) {
                              setState(() {
                                currentSelected = 1;
                              });
                            } else {
                              setState(() {
                                currentSelected = 0;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (currentSelected == 0) {
                        subscribe(annualPackage);
                      } else if (currentSelected == 1) {
                        subscribe(weeklyPackage);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: subscriptionOnGoing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : Column(
                              children: [
                                Text(
                                  getCtaButtonText(),
                                  style: TextStyle(
                                    fontSize: 20.0,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  getCtaButtonSubText(),
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF3680),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // <-- Radius
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        restorePurchase();
                      },
                      child: Text(
                        'paywall_restore'.tr,
                        style: TextStyle(
                          color: Colors.grey[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        openUrl(
                          'https://basastudios.com/videotomp3/terms-of-service/',
                        );
                      },
                      child: Text(
                        'paywall_terms'.tr,
                        style: TextStyle(
                          color: Colors.grey[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        openUrl('https://basastudios.com/videotomp3/privacy/');
                      },
                      child: Text(
                        'paywall_privacy_policy'.tr,
                        style: TextStyle(
                          color: Colors.grey[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String getCtaButtonText() {
    if (currentSelected == 0 || currentSelected == 2) {
      return 'Unlock Now';
    } else {
      if (freeTrialPeriod.isEmpty) {
        return 'Unlock Now';
      } else {
        return 'Start $freeTrialPeriod Free Trial';
      }
    }
  }

  String getCtaButtonSubText() {
    if (currentSelected == 0) {
      return '$annualPrice/year. Cancel anytime';
    } else if (currentSelected == 1) {
      if (freeTrialPeriod.isEmpty) {
        return '$weeklyPrice/week. Cancel anytime';
      } else {
        return 'then $weeklyPrice/week. Cancel anytime';
      }
    } else {
      return "Buy once. Own for life.";
    }
  }

  Future<void> getOfferings() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        // Display packages for sale
        weeklyPackage = offerings.current?.weekly;
        annualPackage = offerings.current?.annual;

        annualPrice = annualPackage?.storeProduct.priceString ?? '';
        weeklyPrice = weeklyPackage?.storeProduct.priceString ?? '';

        if (weeklyPackage != null &&
            weeklyPackage!.storeProduct.introductoryPrice != null) {
          if (Platform.isIOS) {
            final eligibilityMap =
                await Purchases.checkTrialOrIntroductoryPriceEligibility([
                  weeklyPackage!.storeProduct.identifier,
                ]);

            final weeklyEligibility =
                eligibilityMap[weeklyPackage!.storeProduct.identifier];

            if (weeklyEligibility?.status ==
                IntroEligibilityStatus.introEligibilityStatusEligible) {
              var trialUnit =
                  weeklyPackage!
                      .storeProduct
                      .introductoryPrice
                      ?.periodNumberOfUnits ??
                  '';
              var trialPeriod =
                  weeklyPackage!
                      .storeProduct
                      .introductoryPrice
                      ?.periodUnit
                      .name ??
                  '';
              freeTrialPeriod = "$trialUnit ${trialPeriod.capitalize}";
            } else {
              freeTrialPeriod = '';
            }
          } else {
            // Android: safe to display directly
            var trialUnit =
                weeklyPackage
                    ?.storeProduct
                    .introductoryPrice
                    ?.periodNumberOfUnits ??
                '';
            var trialPeriod =
                weeklyPackage
                    ?.storeProduct
                    .introductoryPrice
                    ?.periodUnit
                    .name ??
                '';
            freeTrialPeriod = "$trialUnit ${trialPeriod.capitalize}";
          }
        } else {
          freeTrialPeriod = '';
        }

        calculateSavePercentage();

        setState(() {});

        print('Store product details:  ${offerings.current}');
        //print(offerings.current?.availablePackages.toString());
      }
    } on PlatformException catch (e) {
      // optional error handling
    }
  }

  void calculateSavePercentage() {
    final annualPrice = annualPackage?.storeProduct.price;
    final weekPrice = weeklyPackage?.storeProduct.price;

    if (annualPrice != null && weekPrice != null) {
      final totalWeekly = weekPrice * 52;
      final localPercentSaved =
          ((totalWeekly - annualPrice) / totalWeekly) * 100;

      savePercentage = localPercentSaved.round().toString();
    } else {
      print("Pricing data is incomplete.");
    }
  }

  Future<void> subscribe(Package? package) async {
    try {
      setState(() {
        subscriptionOnGoing = true;
      });
      if (package != null) {
        final purchaseParams = PurchaseParams.package(package);
        PurchaseResult result = await Purchases.purchase(purchaseParams);

        setState(() {
          subscriptionOnGoing = false;
        });

        //print(customerInfo.entitlements.toString());
        if (result.customerInfo.entitlements.all["Pro"]?.isActive ?? false) {
          // Unlock that great "pro" content
          Get.back(result: 'success');
        }
      }
    } on PlatformException catch (e) {
      setState(() {
        subscriptionOnGoing = false;
      });
      /* var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        //showError(e);
      }*/
    }
  }

  Future<void> restorePurchase() async {
    try {
      Get.dialog(
        AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 16),
              Text('paywall_please_wait'.tr),
            ],
          ),
        ),
        barrierDismissible: true,
      );
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      Get.back();
      // ... check restored purchaserInfo to see if entitlement is now active
      print(customerInfo);
      if (customerInfo.entitlements.all["Pro"]?.isActive ?? false) {
        // Unlock that great "pro" content
        Get.back(result: 'success');
      } else {
        // no subscription available to restore
        Get.dialog(
          AlertDialog(
            content: Text('paywall_no_subscription'.tr),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(); // This will close the dialog
                },
                child: Text('paywall_ok'.tr),
              ),
            ],
          ),
          barrierDismissible: true,
        );
      }
    } on PlatformException catch (e) {
      // Error restoring purchases
      Get.back();
    }
  }
}
