import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _selectThemeMode(ThemeMode mode) {
    final ThemeProvider themeProvider =
        context.read<ThemeProvider>();

    if (themeProvider.themeMode == mode) {
      return;
    }

    themeProvider.setThemeMode(mode);

    _showMessage(
      '${_themeModeLabel(mode)} theme selected.',
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.settings_suggest_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final ThemeProvider themeProvider =
        context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            BuildContext context,
            BoxConstraints constraints,
          ) {
            final bool isWide =
                constraints.maxWidth >= 800;

            return SingleChildScrollView(
              padding: EdgeInsets.all(
                isWide ? 28 : 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 900,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(
                        theme,
                        colors,
                      ),
                      const SizedBox(height: 20),
                      _buildAppearanceSection(
                        theme,
                        colors,
                        themeProvider,
                      ),
                      const SizedBox(height: 20),
                      _buildBusinessPreferencesSection(
                        theme,
                        colors,
                      ),
                      const SizedBox(height: 20),
                      _buildApplicationSection(
                        theme,
                        colors,
                      ),
                      const SizedBox(height: 20),
                      _buildAboutSection(
                        theme,
                        colors,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: AppColors.primary,
                size: 29,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Settings',
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Manage your application preferences.',
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(
    ThemeData theme,
    ColorScheme colors,
    ThemeProvider themeProvider,
  ) {
    return _SettingsSectionCard(
      title: 'Appearance',
      subtitle:
          'Customize how the application looks.',
      icon: Icons.palette_outlined,
      children: [
        Text(
          'Theme',
          style:
              theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose whether the app follows your device theme or uses a fixed theme.',
          style:
              theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        RadioGroup<ThemeMode>(
          groupValue:
              themeProvider.themeMode,
          onChanged: (ThemeMode? value) {
            if (value != null) {
              _selectThemeMode(value);
            }
          },
          child: Column(
            children: [
              _buildThemeOption(
                theme,
                colors,
                themeProvider,
                ThemeMode.system,
              ),
              const SizedBox(height: 10),
              _buildThemeOption(
                theme,
                colors,
                themeProvider,
                ThemeMode.light,
              ),
              const SizedBox(height: 10),
              _buildThemeOption(
                theme,
                colors,
                themeProvider,
                ThemeMode.dark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    ThemeData theme,
    ColorScheme colors,
    ThemeProvider themeProvider,
    ThemeMode mode,
  ) {
    final bool selected =
        themeProvider.themeMode == mode;

    return InkWell(
      onTap: () {
        _selectThemeMode(mode);
      },
      borderRadius:
          BorderRadius.circular(14),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(
                  alpha: 0.08,
                )
              : colors.surface,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                        .withValues(alpha: 0.12)
                    : colors
                        .surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                _themeModeIcon(mode),
                color: selected
                    ? AppColors.primary
                    : colors.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _themeModeLabel(mode),
                    style: theme
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _themeModeDescription(mode),
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Radio<ThemeMode>(
              value: mode,
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeDescription(
    ThemeMode mode,
  ) {
    switch (mode) {
      case ThemeMode.system:
        return 'Automatically follow your device theme.';
      case ThemeMode.light:
        return 'Always use the light appearance.';
      case ThemeMode.dark:
        return 'Always use the dark appearance.';
    }
  }

  Widget _buildBusinessPreferencesSection(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return _SettingsSectionCard(
      title: 'Business Preferences',
      subtitle:
          'Preferences that affect daily business operations.',
      icon: Icons.business_center_outlined,
      children: [
        _buildPreferenceTile(
          theme: theme,
          colors: colors,
          icon: Icons.currency_rupee_rounded,
          title: 'Currency',
          subtitle:
              'Currency used throughout the application.',
          value: 'Indian Rupee (₹)',
          onTap: () {
            _showMessage(
              'Currency settings will be connected to business configuration.',
            );
          },
        ),
        const Divider(height: 24),
        _buildPreferenceTile(
          theme: theme,
          colors: colors,
          icon: Icons.receipt_long_outlined,
          title: 'Invoice Settings',
          subtitle:
              'Manage invoice numbering and invoice preferences.',
          value: 'Manage',
          onTap: () {
            _showMessage(
              'Invoice settings will be connected here.',
            );
          },
        ),
        const Divider(height: 24),
        _buildPreferenceTile(
          theme: theme,
          colors: colors,
          icon: Icons.percent_rounded,
          title: 'Tax / GST',
          subtitle:
              'Configure tax and GST preferences for sales.',
          value: 'Manage',
          onTap: () {
            _showMessage(
              'Tax and GST settings will be connected here.',
            );
          },
        ),
      ],
    );
  }

  Widget _buildApplicationSection(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return _SettingsSectionCard(
      title: 'Application',
      subtitle:
          'General application preferences.',
      icon: Icons.tune_rounded,
      children: [
        _buildPreferenceTile(
          theme: theme,
          colors: colors,
          icon:
              Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle:
              'Manage application notification preferences.',
          value: 'Manage',
          onTap: () {
            _showMessage(
              'Notification settings will be connected here.',
            );
          },
        ),
        const Divider(height: 24),
        _buildPreferenceTile(
          theme: theme,
          colors: colors,
          icon: Icons.language_rounded,
          title: 'Language',
          subtitle:
              'Choose the language used by the application.',
          value: 'English',
          onTap: () {
            _showMessage(
              'Language selection will be connected here.',
            );
          },
        ),
        const Divider(height: 24),
        _buildPreferenceTile(
          theme: theme,
          colors: colors,
          icon: Icons.backup_outlined,
          title: 'Backup & Restore',
          subtitle:
              'Manage business data backup and restore options.',
          value: 'Manage',
          onTap: () {
            _showMessage(
              'Backup and restore will be connected here.',
            );
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return _SettingsSectionCard(
      title: 'About',
      subtitle:
          'Application information.',
      icon: Icons.info_outline_rounded,
      children: [
        _buildInfoRow(
          theme,
          colors,
          'Application',
          'Business Management App',
        ),
        const SizedBox(height: 14),
        _buildInfoRow(
          theme,
          colors,
          'Version',
          '1.0.0',
        ),
        const SizedBox(height: 14),
        _buildInfoRow(
          theme,
          colors,
          'Platform',
          'Flutter',
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    ColorScheme colors,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style:
                theme.textTheme.bodyMedium?.copyWith(
              color:
                  colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style:
                theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile({
    required ThemeData theme,
    required ColorScheme colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              textAlign: TextAlign.end,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: AppColors.primary,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color:
                  colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionCard
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color:
                        AppColors.secondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color:
                              colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
