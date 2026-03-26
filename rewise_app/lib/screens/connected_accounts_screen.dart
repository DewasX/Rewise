import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/design_system.dart';

class ConnectedAccountsScreen extends StatelessWidget {
  const ConnectedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final provider = user?.appMetadata['provider'] as String? ?? 'email';
    final identities = user?.identities ?? [];

    final hasEmail = identities.any((id) => id.provider == 'email') || provider == 'email';
    final hasGoogle = identities.any((id) => id.provider == 'google') || provider == 'google';
    final hasApple = identities.any((id) => id.provider == 'apple') || provider == 'apple';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Connected Accounts',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'These are the login methods connected to your account.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _providerTile(
              icon: Icons.email_outlined,
              label: 'Email',
              detail: user?.email ?? '',
              connected: hasEmail,
            ),
            const SizedBox(height: 12),
            _providerTile(
              icon: Icons.g_mobiledata_rounded,
              label: 'Google',
              detail: hasGoogle ? 'Connected' : 'Not connected',
              connected: hasGoogle,
              iconColor: hasGoogle ? const Color(0xFF4285F4) : AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            _providerTile(
              icon: Icons.apple,
              label: 'Apple',
              detail: hasApple ? 'Connected' : 'Not connected',
              connected: hasApple,
              iconColor: hasApple ? Colors.white : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerTile({
    required IconData icon,
    required String label,
    required String detail,
    required bool connected,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.strong.withValues(alpha: 0.1)
                  : AppColors.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              connected ? 'Connected' : 'Not linked',
              style: TextStyle(
                color: connected ? AppColors.strong : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
