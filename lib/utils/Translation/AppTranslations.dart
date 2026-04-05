import 'package:get/get_navigation/src/root/internacionalization.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      // Paywall Dialog
      'paywall_unlimited_access': 'Unlimited Access',
      'paywall_per_year': '@price per year',
      'paywall_annual_per_month_hint': '(@price/month)',
      'paywall_save_percentage': 'SAVE @percentage',
      'paywall_monthly_plan': 'Monthly Plan',
      'paywall_per_month': '@price per month',
      'paywall_weekly_plan': 'Weekly Plan',
      'paywall_trial_period': '@trialPeriod Trial',
      'paywall_per_week': '@price per week',
      'paywall_then_per_week': 'then @price per week',
      'paywall_free': 'FREE',
      'paywall_trial_enabled': 'Free Trial Enabled',
      'paywall_unlock_now': 'Unlock Now',
      'paywall_try_free': 'Try for Free',
      'paywall_restore': 'Restore',
      'paywall_terms': 'Terms',
      'paywall_privacy_policy': 'Privacy Policy',
      'paywall_please_wait': 'Please wait...',
      'paywall_no_subscription': 'You do not have an existing subscription to restore.',
      'paywall_ok': 'OK',
    },
  };
}