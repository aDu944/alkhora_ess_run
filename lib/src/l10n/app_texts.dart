import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appLocaleProvider = StateProvider<Locale?>((ref) => null);

class AppTexts {
  AppTexts(this.locale);

  final Locale locale;

  bool get isAr => locale.languageCode.toLowerCase() == 'ar';

  String get appTitle => isAr ? 'الخُورا - الخدمة الذاتية' : 'ALKHORA ESS';

  String get loginTitle => isAr ? 'تسجيل الدخول' : 'Sign in';
  String get emailOrUsername => isAr ? 'البريد/اسم المستخدم' : 'Email / Username';
  String get password => isAr ? 'كلمة المرور' : 'Password';
  String get signIn => isAr ? 'دخول' : 'Sign in';
  String get logout => isAr ? 'تسجيل الخروج' : 'Sign out';

  String get checkIn => isAr ? 'تسجيل دخول' : 'Check-in';
  String get checkOut => isAr ? 'تسجيل خروج' : 'Check-out';
  String get syncing => isAr ? 'جاري المزامنة…' : 'Syncing…';
  String get syncNow => isAr ? 'مزامنة الآن' : 'Sync now';
  String get offlineQueued => isAr ? 'تم الحفظ بدون إنترنت وسيتم الإرسال لاحقاً' : 'Saved offline and will sync later';

  String get home => isAr ? 'الرئيسية' : 'Home';
  String get leave => isAr ? 'الإجازات' : 'Leave';
  String get attendance => isAr ? 'الحضور' : 'Attendance';
  String get payslips => isAr ? 'الرواتب' : 'Payslips';
  String get expenses => isAr ? 'المصاريف' : 'Expenses';
  String get announcements => isAr ? 'الإعلانات' : 'Announcements';
  String get profile => isAr ? 'الملف الشخصي' : 'Profile';
  String get holidays => isAr ? 'العطلات' : 'Holidays';
  String get documents => isAr ? 'الوثائق' : 'Documents';
  String get approvals => isAr ? 'الموافقات' : 'Approvals';
  String get settings => isAr ? 'الإعدادات' : 'Settings';

  String get locationPermissionRequired =>
      isAr ? 'نحتاج إذن الموقع لتسجيل الحضور' : 'Location permission is required to mark attendance';
  String get biometricPrompt => isAr ? 'تحقق بالبصمة/الوجه' : 'Authenticate with biometrics';
  String get invalidLogin => isAr ? 'بيانات الدخول غير صحيحة' : 'Invalid credentials';
}

extension AppTextsX on BuildContext {
  AppTexts texts(WidgetRef ref) {
    final overrideLocale = ref.read(appLocaleProvider);
    final locale = overrideLocale ?? Localizations.localeOf(this);
    return AppTexts(locale);
  }
}

