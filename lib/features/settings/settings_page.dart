import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../data/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Settings — app-side of the web /settings page. Appearance (theme + text
/// size, device-local) and the signed-in account prefs (display name, email
/// digest) that live in Supabase. Push is deferred (native FCM/APNs).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name = TextEditingController();
  bool _loading = true;
  bool _savingProfile = false;
  bool _savingDigest = false;
  bool _digestOn = false;
  String _frequency = 'daily';

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final db = ref.read(supabaseProvider);
    try {
      final profile = await db
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      final sub = await db
          .from('email_subscriptions')
          .select('frequency, is_active')
          .eq('user_id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _name.text = (profile?['full_name'] as String?) ?? '';
        _digestOn = (sub?['is_active'] as bool?) ?? false;
        _frequency = (sub?['frequency'] as String?) ?? 'daily';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _savingProfile = true);
    try {
      await ref.read(supabaseProvider).from('profiles').upsert(
        {'id': user.id, 'full_name': _name.text.trim()},
      );
      _toast('Profile saved');
    } catch (e) {
      _toast("Couldn't save profile");
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveDigest() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _savingDigest = true);
    final db = ref.read(supabaseProvider);
    try {
      if (_digestOn) {
        await db.from('email_subscriptions').upsert({
          'user_id': user.id,
          'email': user.email,
          'frequency': _frequency,
          'is_active': true,
        }, onConflict: 'user_id');
      } else {
        await db
            .from('email_subscriptions')
            .update({'is_active': false}).eq('user_id', user.id);
      }
      _toast('Email preferences saved');
    } catch (e) {
      _toast("Couldn't save email preferences");
    } finally {
      if (mounted) setState(() => _savingDigest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Settings', style: AppText.title.copyWith(color: c.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.x3),
        children: [
          // ── Appearance (device-local) ──
          _Section(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            children: [
              Text('Theme', style: AppText.bodyStrong.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.sm),
              _ChoiceRow(
                options: const {
                  ThemeMode.system: 'System',
                  ThemeMode.light: 'Light',
                  ThemeMode.dark: 'Dark',
                },
                selected: settings.themeMode,
                onSelect: ctrl.setThemeMode,
              ),
              const SizedBox(height: AppSpace.lg),
              Text('Text size', style: AppText.bodyStrong.copyWith(color: c.text)),
              const SizedBox(height: AppSpace.sm),
              _ChoiceRow<double>(
                // non-const: double can't be a const map key (overrides ==)
                // Owner ladder 2026-08-16: exact 5% steps, Large = the
                // design's base size, everything else reads compact.
                options: {0.9: 'Small', 0.95: 'Default', 1.0: 'Large'},
                selected: settings.textScale,
                onSelect: ctrl.setTextScale,
              ),
            ],
          ),

          if (user == null)
            _Section(
              icon: Icons.person_outline,
              title: 'Account',
              children: [
                Text('Sign in to manage your profile and email digest.',
                    style: AppText.body.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpace.md),
                FilledButton(
                  onPressed: () => context.push('/sign-in'),
                  style: FilledButton.styleFrom(
                      backgroundColor: c.brand,
                      shape: const RoundedRectangleBorder()),
                  child: const Text('Sign in'),
                ),
              ],
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpace.x2),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else ...[
            // ── Profile (Supabase) ──
            _Section(
              icon: Icons.person_outline,
              title: 'Profile',
              children: [
                Text('Display name shows on comments and watchlists.',
                    style: AppText.caption.copyWith(color: c.textFaint)),
                const SizedBox(height: AppSpace.sm),
                TextField(
                  controller: _name,
                  style: AppText.body.copyWith(color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Your name',
                    filled: true,
                    fillColor: c.bgInset,
                    border: const OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                _SaveButton(
                  label: 'Save profile',
                  busy: _savingProfile,
                  onTap: _saveProfile,
                ),
              ],
            ),

            // ── Preferences (re-run the setup wizard, prefilled) ──
            _Section(
              icon: Icons.tune,
              title: 'Preferences',
              children: [
                Text(
                    'Interests, favorite sources, news region, and alerts. '
                    'Walk through the setup again any time.',
                    style: AppText.body.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpace.md),
                FilledButton.icon(
                  onPressed: () => context.push('/setup?edit=1'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.brand,
                    minimumSize: const Size.fromHeight(46),
                    shape: const RoundedRectangleBorder(),
                  ),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Edit preferences'),
                ),
              ],
            ),

            // ── Email digest (Supabase) ──
            _Section(
              icon: Icons.mail_outline,
              title: 'Email digest',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeColor: c.brand,
                  value: _digestOn,
                  onChanged: (v) => setState(() => _digestOn = v),
                  title: Text('Daily AI-curated digest',
                      style: AppText.body.copyWith(color: c.text)),
                  subtitle: Text('A short summary of the top stories',
                      style: AppText.caption.copyWith(color: c.textFaint)),
                ),
                if (_digestOn) ...[
                  const SizedBox(height: AppSpace.sm),
                  _ChoiceRow(
                    options: const {'daily': 'Daily', 'weekly': 'Weekly'},
                    selected: _frequency,
                    onSelect: (v) => setState(() => _frequency = v),
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                _SaveButton(
                  label: 'Save preferences',
                  busy: _savingDigest,
                  onTap: _saveDigest,
                ),
              ],
            ),
          ],

          // ── About ──
          _Section(
            icon: Icons.info_outline,
            title: 'About',
            children: [
              Text('Cluster News links out to original publishers and never '
                  'reproduces article text. Signals (impact, trust, clusters) '
                  'are generated by AI over public news sources.',
                  style: AppText.body.copyWith(color: c.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: c.brand),
            const SizedBox(width: AppSpace.sm),
            Text(title, style: AppText.headline.copyWith(color: c.text, fontSize: 16)),
          ]),
          const SizedBox(height: AppSpace.md),
          ...children,
        ],
      ),
    );
  }
}

/// A horizontal row of selectable chips (square, on-brand when selected).
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow(
      {required this.options, required this.selected, required this.onSelect});
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: options.entries.map((e) {
        final on = e.key == selected;
        return Material(
          color: on ? c.brand : c.bgInset,
          child: InkWell(
            onTap: () => onSelect(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg, vertical: AppSpace.sm),
              decoration: BoxDecoration(border: Border.all(color: c.border)),
              child: Text(e.value,
                  style: AppText.callout.copyWith(
                      color: on ? c.onBrand : c.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton(
      {required this.label, required this.busy, required this.onTap});
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FilledButton(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: c.brand,
        minimumSize: const Size.fromHeight(46),
        shape: const RoundedRectangleBorder(),
      ),
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label),
    );
  }
}
