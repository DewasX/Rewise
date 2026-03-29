import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/design_system.dart';
import '../core/providers.dart';
import '../core/offline_sync_service.dart';
import 'profile_settings_screen.dart';
import 'change_password_screen.dart';
import 'export_data_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_preferences_screen.dart';
import 'delete_account_screen.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final userName = userProfile.value?['name'] ?? 'Account';
    final userEmail = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Account & Settings',
            style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Profile card ──────────────────────────────────────────────────
          _buildProfileCard(context, userName, userEmail),
          const SizedBox(height: 24),

          // ── Account section ───────────────────────────────────────────────
          _sectionLabel(context, 'Account'),
          _tile(context, Icons.person_outline, 'Profile',
              'Update your name and details',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()))),
          _tile(context, Icons.lock_outline, 'Change Password',
              'Update your login password',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),

          const SizedBox(height: 24),

          // ── Preferences ───────────────────────────────────────────────────
          _sectionLabel(context, 'Preferences'),
          _tile(context, Icons.tune, 'App Preferences',
              'Theme',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AppPreferencesScreen()))),
          _tile(context, Icons.feedback_outlined, 'Send Feedback',
              'Report a bug or share your thoughts',
              () async {
                final uri = Uri.parse('https://dewasx.github.io/rewise-landing/#feedback');
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  debugPrint('Could not launch \$uri');
                }
              }),

          const SizedBox(height: 24),

          // ── Danger zone ───────────────────────────────────────────────────
          _sectionLabel(context, 'Danger Zone'),
          _tile(context, Icons.delete_forever_outlined, 'Delete Account',
              'Permanently remove all your data',
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
              color: AppColors.urgent),
          _tile(context, Icons.logout, 'Sign Out', 'Sign out of your account',
              () => _signOut(context, ref),
              color: AppColors.urgent),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, String name, String email) {
    final userMeta = Supabase.instance.client.auth.currentUser?.userMetadata;
    final avatarUrl = userMeta?['avatar_url'] ?? userMeta?['picture'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl != null && avatarUrl.isNotEmpty 
              ? const SizedBox.shrink()
              : Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 2),
                Text(email,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Theme.of(context).dividerTheme.color),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle,
      VoidCallback onTap,
      {Color? color}) {
    final tileColor = color ?? Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tileColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: tileColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).dividerTheme.color, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await OfflineSyncService().syncPendingReviews();
    } catch (_) {}
    // Clear local cached data to prevent data leaking between accounts
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_todays_topics');
    await prefs.remove('offline_pending_reviews');
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}
