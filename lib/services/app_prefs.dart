import 'package:shared_preferences/shared_preferences.dart';
class AppPrefs {
  static const _onboarding='onboarding_done',_role='selected_role',_notifications='notifications_enabled',_privacy='privacy_personalization',_language='language',_dark='dark_mode',_themeMode='theme_mode',_activeRide='active_ride',_fontScale='font_scale';
  static Future<bool> onboardingDone() async => (await SharedPreferences.getInstance()).getBool(_onboarding) ?? false;
  static Future<void> setOnboardingDone() async => (await SharedPreferences.getInstance()).setBool(_onboarding,true);
  static Future<String?> role() async => (await SharedPreferences.getInstance()).getString(_role);
  static Future<void> setRole(String role) async => (await SharedPreferences.getInstance()).setString(_role,role);
  static Future<void> clearRole() async => (await SharedPreferences.getInstance()).remove(_role);
  static Future<bool> notifications() async => (await SharedPreferences.getInstance()).getBool(_notifications) ?? true;
  static Future<void> setNotifications(bool value) async => (await SharedPreferences.getInstance()).setBool(_notifications,value);
  static Future<bool> privacy() async => (await SharedPreferences.getInstance()).getBool(_privacy) ?? true;
  static Future<void> setPrivacy(bool value) async => (await SharedPreferences.getInstance()).setBool(_privacy,value);
  static Future<String> language() async => (await SharedPreferences.getInstance()).getString(_language) ?? 'تونسي';
  static Future<void> setLanguage(String value) async => (await SharedPreferences.getInstance()).setString(_language,value);
  /// Theme preference: system, light, or dark. Migrates the older boolean setting.
  static Future<String> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeMode);
    if (saved == 'system' || saved == 'light' || saved == 'dark') return saved!;
    final legacyDark = prefs.getBool(_dark);
    if (legacyDark != null) {
      final migrated = legacyDark ? 'dark' : 'light';
      await prefs.setString(_themeMode, migrated);
      return migrated;
    }
    return 'system';
  }
  static Future<void> setThemeMode(String value) async {
    if (!{'system', 'light', 'dark'}.contains(value)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeMode, value);
    await prefs.remove(_dark);
  }
  /// Backward-compatible helpers for any older callers.
  static Future<bool> darkMode() async => (await themeMode()) == 'dark';
  static Future<void> setDarkMode(bool value) async => setThemeMode(value ? 'dark' : 'light');
  static Future<double> fontScale() async { final value=(await SharedPreferences.getInstance()).getDouble(_fontScale)??1.0; return value.clamp(0.85,1.35).toDouble(); }
  static Future<void> setFontScale(double value) async { if(!value.isFinite)return; await (await SharedPreferences.getInstance()).setDouble(_fontScale,value.clamp(0.85,1.35).toDouble()); }
  static Future<void> setActiveRide(String id) async => (await SharedPreferences.getInstance()).setString(_activeRide,id);
  static Future<void> clearActiveRide() async => (await SharedPreferences.getInstance()).remove(_activeRide);
}
