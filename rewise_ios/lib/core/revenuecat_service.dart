import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RevenueCatService {
  static const String _appleApiKey = 'test_QvlpIcZBvkEGZskAFSXXdvJiNuO';
  static const String _googleApiKey = 'test_QvlpIcZBvkEGZskAFSXXdvJiNuO'; // Using same API key as requested, replace with real Google key later if different
  static const String entitlementId = 'Rewise Pro';

  static Future<void> initialize() async {
    if (kIsWeb) return; // RevenueCat does not support Web yet

    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (Platform.isIOS || Platform.isMacOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      
      // Set Supabase ID if already logged in initially
      final initialUserId = Supabase.instance.client.auth.currentUser?.id;
      if (initialUserId != null) {
        await logIn(initialUserId);
      }
    }
  }

  /// Syncs the Supabase User ID to RevenueCat
  static Future<void> logIn(String appUserId) async {
    if (kIsWeb) return;
    try {
      await Purchases.logIn(appUserId);
    } catch (e) {
      debugPrint('Error linking RevenueCat user: \$e');
    }
  }

  /// Logs the user out of RevenueCat (resets appUserID)
  static Future<void> logOut() async {
    if (kIsWeb) return;
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint('Error logging out of RevenueCat: \$e');
    }
  }

  /// Checks if the user has the Rewise Pro entitlement active
  static bool hasProEntitlement(CustomerInfo info) {
    if (info.entitlements.all[entitlementId] != null && 
        info.entitlements.all[entitlementId]!.isActive) {
      return true;
    }
    return false;
  }

  /// Presents the Paywall UI and returns true if purchase was successful
  static Future<bool> presentPaywall() async {
    if (kIsWeb) return false;
    try {
      final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(entitlementId);
      if (paywallResult == PaywallResult.purchased || 
          paywallResult == PaywallResult.restored) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error presenting paywall: \$e');
      return false;
    }
  }

  /// Presents the Customer Center for managing subscriptions
  static Future<void> presentCustomerCenter() async {
    if (kIsWeb) return;
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint('Error presenting Customer Center: \$e');
    }
  }
}
