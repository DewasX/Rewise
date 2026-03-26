import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system.dart';
import '../core/settings_service.dart';
import '../core/providers.dart';

class AppPreferencesScreen extends ConsumerStatefulWidget {
  const AppPreferencesScreen({super.key});

  @override
  ConsumerState<AppPreferencesScreen> createState() => _AppPreferencesScreenState();
}

class _AppPreferencesScreenState extends ConsumerState<AppPreferencesScreen> {
  String _theme = 'system';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SettingsService().getPreferences();
    if (mounted) {
      setState(() {
        _theme = prefs['theme'] ?? 'system';
        _loading = false;
      });
    }
  }

  Future<void> _setTheme(String val) async {
    setState(() => _theme = val);
    await SettingsService().setTheme(val);
    
    final mode = val == 'dark' 
        ? ThemeMode.dark 
        : (val == 'light' ? ThemeMode.light : ThemeMode.system);
    ref.read(themeModeProvider.notifier).state = mode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('App Preferences',
            style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _section(
                  context: context,
                  title: 'Theme',
                  child: _chipRow(context, ['system', 'light', 'dark'], _theme, _setTheme,
                      labels: {'system': 'System', 'light': 'Light', 'dark': 'Dark'}),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Settings are applied immediately and saved locally.',
                          style: TextStyle(color: AppColors.info, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section({required BuildContext context, required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _chipRow(BuildContext context, List<String> values, String current, Function(String) onSelect,
      {Map<String, String>? labels}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: values.map((v) {
        final label = labels?[v] ?? v;
        final selected = current == v;
        return GestureDetector(
          onTap: () => onSelect(v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? AppColors.primary : (Theme.of(context).dividerTheme.color ?? Colors.transparent)),
            ),
            child: Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }
}
