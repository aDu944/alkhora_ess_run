import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/secure_kv.dart';

// Load locale from secure storage on initialization
final appLocaleProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final lang = await SecureKv.read(SecureKeys.selectedLanguage);
    if (lang != null && (lang == 'en' || lang == 'ar')) {
      state = Locale(lang);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await SecureKv.write(SecureKeys.selectedLanguage, locale.languageCode);
    await SecureKv.write(SecureKeys.hasSelectedLanguage, '1');
  }

  Future<bool> hasSelectedLanguage() async {
    final hasSelected = await SecureKv.read(SecureKeys.hasSelectedLanguage);
    return hasSelected == '1';
  }
}

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
  String get payments => isAr ? 'رصيد حسابك' : 'Payments';
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
  String get wrongPassword => isAr ? 'كلمة المرور غير صحيحة' : 'Incorrect password';
  String get wrongUsername => isAr ? 'اسم المستخدم أو البريد الإلكتروني غير صحيح' : 'Incorrect username or email';
  String get loginError => isAr ? 'حدث خطأ أثناء تسجيل الدخول. يرجى المحاولة مرة أخرى.' : 'Login error occurred. Please try again.';
  String get networkError => isAr ? 'خطأ في الاتصال. يرجى التحقق من الاتصال بالإنترنت.' : 'Connection error. Please check your internet connection.';

  // Home page strings
  String get currentlyOnClock => isAr ? 'حالياً: في العمل' : 'Currently: On the Clock';
  String get currentlyOffClock => isAr ? 'حالياً: خارج العمل' : 'Currently: Off the Clock';
  String get goodMorning => isAr ? 'صباح الخير' : 'Good morning';
  String get goodAfternoon => isAr ? 'مساء الخير' : 'Good afternoon';
  String get goodEvening => isAr ? 'مساء الخير' : 'Good evening';
  String get locked => isAr ? 'مقفل' : 'Locked';
  String get tapToCheckIn => isAr ? 'اضغط للتسجيل دخول' : 'Tap to Check In';
  String get tapToCheckOut => isAr ? 'اضغط للتسجيل خروج' : 'Tap to Check Out';
  String get mockLocationDetected => isAr ? 'تم اكتشاف موقع مزيف' : 'Mock location detected';
  String get outsideGeofence => isAr ? 'خارج النطاق الجغرافي' : 'Outside geofence';
  String get locationPermissionDenied => isAr ? 'تم رفض إذن الموقع' : 'Location permission denied';
  String get locationServicesDisabled => isAr ? 'خدمات الموقع معطلة' : 'Location services disabled';
  String get geofenceError => isAr ? 'خطأ في النطاق الجغرافي' : 'Geofence error';
  String get verifiedAt => isAr ? 'أنت في: المكتب الرئيسي (مُتحقق)' : 'You are at: Downtown Office (Verified)';
  String get hoursToday => isAr ? 'الساعات اليوم' : 'Hours Today';
  String get weeklyTotal => isAr ? 'الإجمالي الأسبوعي' : 'Weekly Total';
  String get recentActivity => isAr ? 'النشاط الأخير' : 'Recent Activity';
  String get today => isAr ? 'اليوم' : 'Today';
  String get yesterday => isAr ? 'أمس' : 'Yesterday';
  String get thisYear => isAr ? 'هذا العام' : 'This Year';
  String get lastYear => isAr ? 'العام الماضي' : 'Last Year';
  String get checkedIn => isAr ? 'تم تسجيل الدخول' : 'Checked In';
  String get checkedOut => isAr ? 'تم تسجيل الخروج' : 'Checked Out';
  String get quickNote => isAr ? 'ملاحظة سريعة +' : 'Quick Note +';
  String get syncingLater => isAr ? 'جارٍ المزامنة لاحقاً' : 'Syncing Later';
  String get retry => isAr ? 'إعادة المحاولة' : 'Retry';
  String get onTheClock => isAr ? 'في العمل' : 'On the Clock';
  String get offTheClock => isAr ? 'خارج العمل' : 'Off the Clock';
  String get lateEntry => isAr ? 'تأخر في الدخول' : 'Late Entry';
  String get earlyExit => isAr ? 'خروج مبكر' : 'Early Exit';

  // Error messages
  String get apiError => isAr ? 'خطأ في API' : 'API Error';
  String get checkinFailed => isAr ? 'فشل تسجيل الحضور' : 'Check-in failed';
  String get mockLocationDetectedMsg => isAr ? 'تم اكتشاف موقع مزيف. يرجى تعطيل محاكاة GPS للمتابعة.' : 'Mock location detected. Disable GPS spoofing to continue.';
  String get mustBeInGeofence => isAr ? 'يجب أن تكون ضمن النطاق الجغرافي للمكتب.' : 'You must be within the office geofence.';
  String get biometricFailed => isAr ? 'فشل التحقق بالبصمة.' : 'Biometric verification failed.';
  String get timeServiceUnavailable => isAr ? 'غير قادر على الحصول على وقت النظام. يرجى المحاولة مرة أخرى.' : 'Unable to get system time. Please try again.';
  String get userNotAuthenticated => isAr ? 'انتهت صلاحية المستخدم. يرجى تسجيل الدخول مرة أخرى.' : 'User not authenticated. Please log in again.';
  String get alreadyRecorded => isAr ? 'تم تسجيل هذا الحضور بالفعل. يرجى الانتظار قليلاً والمحاولة مرة أخرى.' : 'This check-in was already recorded. Please wait a moment and try again.';
  String get unableToMarkAttendance => isAr ? 'غير قادر على تسجيل الحضور' : 'Unable to mark attendance';
  String get unableToMarkAttendanceRetry => isAr ? 'غير قادر على تسجيل الحضور. يرجى المحاولة مرة أخرى.' : 'Unable to mark attendance. Please try again.';
  String get locationError => isAr ? 'خطأ في الموقع' : 'Location error';
  String get locationTimeout => isAr ? 'انتهت مهلة الموقع. يرجى المحاولة مرة أخرى.' : 'Location timeout. Please try again.';
  String get locationPermissionRequiredTitle => isAr ? 'إذن الموقع مطلوب' : 'Location Permission Required';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get openSettings => isAr ? 'فتح الإعدادات' : 'Open Settings';
  String get unableToOpenSettings => isAr ? 'غير قادر على فتح الإعدادات' : 'Unable to open settings';

  // Settings page
  String get language => isAr ? 'اللغة' : 'Language';
  String get languageEnglish => isAr ? 'الإنجليزية' : 'English';
  String get languageArabic => isAr ? 'العربية' : 'Arabic';
  String get selectLanguage => isAr ? 'اختر اللغة' : 'Select Language';
  String get selectPreferredLanguage => isAr ? 'اختر لغتك المفضلة' : 'Select Your Preferred Language';
  String get continueText => isAr ? 'متابعة' : 'Continue';
  String get modules => isAr ? 'الوحدات' : 'Modules';
  String get rememberMe => isAr ? 'تذكرني' : 'Remember me';
  String get enableBiometric => isAr ? 'تفعيل البصمة/الوجه' : 'Enable Biometric/Face ID';
  String get biometricAuthentication => isAr ? 'التحقق بالبصمة/الوجه' : 'Biometric Authentication';
  String get leaveBalance => isAr ? 'رصيد الإجازات' : 'Leave Balance';
  String get days => isAr ? 'أيام' : 'days';
  String get biometricNotAvailable => isAr ? 'التحقق بالبصمة غير متاح على هذا الجهاز' : 'Biometric authentication is not available on this device';

  // Login page
  String get pleaseEnterEmail => isAr ? 'الرجاء إدخال البريد الإلكتروني أو اسم المستخدم' : 'Please enter your email or username';
  String get pleaseEnterPassword => isAr ? 'الرجاء إدخال كلمة المرور' : 'Please enter your password';

  // Payments page
  String get paymentsSummary => isAr ? 'ملخص المدفوعات' : 'Payments Summary';
  String get receivedIn => isAr ? 'المستلم (داخل)' : 'Received (In)';
  String get paidOut => isAr ? 'المدفوع (خارج)' : 'Paid (Out)';
  String get netAmount => isAr ? 'المبلغ الصافي' : 'Net Amount';
  String get documentId => isAr ? 'رقم المستند' : 'Document ID';
  String get status => isAr ? 'الحالة' : 'Status';
  String get noPaymentsYet => isAr ? 'لا توجد مدفوعات بعد' : 'No payments yet';
  String get noPaymentsMatchFilters => isAr ? 'لا توجد مدفوعات تطابق المرشحات' : 'No payments match the filters';
  String get clearFilters => isAr ? 'مسح المرشحات' : 'Clear Filters';
  String get filterPayments => isAr ? 'تصفية المدفوعات' : 'Filter Payments';
  String get dateRange => isAr ? 'نطاق التاريخ' : 'Date Range';
  String get fromDate => isAr ? 'من تاريخ' : 'From Date';
  String get toDate => isAr ? 'إلى تاريخ' : 'To Date';
  String get paymentType => isAr ? 'نوع الدفع' : 'Payment Type';
  String get all => isAr ? 'الكل' : 'All';
  String get amountRange => isAr ? 'نطاق المبلغ' : 'Amount Range';
  String get min => isAr ? 'الحد الأدنى' : 'Min';
  String get max => isAr ? 'الحد الأقصى' : 'Max';
  String get apply => isAr ? 'تطبيق' : 'Apply';
  String get clearAll => isAr ? 'مسح الكل' : 'Clear All';
  String get ofPayments => isAr ? 'من المدفوعات' : 'of payments';
  String get noEmployeeAccount => isAr ? 'لا يوجد لديك حساب. يرجى التحقق من مديرك.' : "You don't have an account. Please check with your manager.";

  // Profile page
  String get personalInformation => isAr ? 'المعلومات الشخصية' : 'Personal Information';
  String get employeeId => isAr ? 'رقم الموظف' : 'Employee ID';
  String get department => isAr ? 'القسم' : 'Department';
  String get company => isAr ? 'الشركة' : 'Company';
  String get dateOfJoining => isAr ? 'تاريخ التعيين' : 'Date of Joining';
  String get contactInformation => isAr ? 'معلومات الاتصال' : 'Contact Information';
  String get phone => isAr ? 'الهاتف' : 'Phone';
  String get email => isAr ? 'البريد الإلكتروني' : 'Email';
  String get emergencyContact => isAr ? 'جهة الاتصال في حالات الطوارئ' : 'Emergency Contact';
  String get address => isAr ? 'العنوان' : 'Address';
  String get currentAddress => isAr ? 'العنوان الحالي' : 'Current Address';
  String get permanentAddress => isAr ? 'العنوان الدائم' : 'Permanent Address';
  String get gender => isAr ? 'الجنس' : 'Gender';
  String get errorLoadingProfile => isAr ? 'خطأ في تحميل الملف الشخصي' : 'Error loading profile';
}

extension AppTextsX on BuildContext {
  AppTexts texts(WidgetRef ref) {
    final overrideLocale = ref.read(appLocaleProvider);
    final locale = overrideLocale ?? Localizations.localeOf(this);
    return AppTexts(locale);
  }
}

