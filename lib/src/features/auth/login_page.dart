import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_kv.dart';
import '../../l10n/app_texts.dart';
import 'auth_controller.dart';
import 'biometric_service.dart';
import 'language_selection_dialog.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _rememberMe = false;
  bool _enableBiometric = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedUsername();
    _checkBiometricAvailability();
  }

  Future<void> _loadRememberedUsername() async {
    final remembered = await SecureKv.read(SecureKeys.rememberMeEnabled);
    if (remembered == '1') {
      final username = await SecureKv.read(SecureKeys.rememberedUsername);
      if (username != null && username.isNotEmpty) {
        setState(() {
          _userCtrl.text = username;
          _rememberMe = true;
        });
      }
    }
    
    // Check if biometric was previously enabled
    final biometricEnabled = await SecureKv.read(SecureKeys.biometricEnabled);
    if (biometricEnabled == '1' && _biometricAvailable) {
      setState(() {
        _enableBiometric = true;
      });
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheck = await BiometricService.canAuthenticate();
      if (mounted) {
        setState(() {
          _biometricAvailable = canCheck;
        });
      }
    } catch (_) {
      // Biometric not available
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texts(ref);
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    ref.listen(authControllerProvider, (prev, next) async {
      next.whenOrNull(
        data: (session) async {
          if (session != null && mounted) {
            // Check if this is first login (no language selected yet)
            final isFirst = await ref.read(authControllerProvider.notifier).isFirstLogin();
            if (isFirst) {
              // Show language selection dialog
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const LanguageSelectionDialog(),
              );
            }
          }
        },
        error: (error, stackTrace) {
          if (mounted) {
            String errorMessage = t.invalidLogin;
            IconData? errorIcon = Icons.error_outline;
            
            // Check for specific error types
            if (error is DioException) {
              if (error.response != null) {
                final statusCode = error.response?.statusCode;
                final errorData = error.response?.data;
                
                // Check for authentication errors (401, 403)
                if (statusCode == 401 || statusCode == 403) {
                  // Try to extract error message from response
                  String? message;
                  if (errorData is Map) {
                    message = errorData['message']?.toString() ?? 
                              errorData['exc']?.toString() ?? 
                              errorData['exc_type']?.toString();
                  }
                  
                  // Check if message indicates wrong password
                  if (message != null) {
                    final msgLower = message.toLowerCase();
                    if (msgLower.contains('password') || msgLower.contains('pwd') || msgLower.contains('incorrect')) {
                      errorMessage = t.wrongPassword;
                      errorIcon = Icons.lock_outline;
                    } else if (msgLower.contains('user') || msgLower.contains('username') || msgLower.contains('email')) {
                      errorMessage = t.wrongUsername;
                      errorIcon = Icons.person_outline;
                    } else {
                      errorMessage = t.invalidLogin;
                    }
                  } else {
                    errorMessage = t.invalidLogin;
                  }
                } else if (statusCode != null && statusCode >= 500) {
                  errorMessage = t.loginError;
                  errorIcon = Icons.warning_outlined;
                }
              } else if (error.type == DioExceptionType.connectionTimeout || 
                         error.type == DioExceptionType.receiveTimeout ||
                         error.type == DioExceptionType.sendTimeout) {
                errorMessage = t.networkError;
                errorIcon = Icons.wifi_off_outlined;
              } else if (error.type == DioExceptionType.connectionError) {
                errorMessage = t.networkError;
                errorIcon = Icons.cloud_off_outlined;
              }
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(errorIcon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: theme.colorScheme.error,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: t.retry,
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    // Clear password field for security on retry
                    _passCtrl.clear();
                    _handleLogin(auth);
                  },
                ),
              ),
            );
            
            // Clear password field on error for security
            _passCtrl.clear();
          }
        },
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: size.height * 0.1,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
            child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                    // Logo/Brand Section
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C4CA5),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1C4CA5).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title Section
                Text(
                  t.appTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.loginTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Username Field - Flat Design
                    TextFormField(
                  controller: _userCtrl,
                  keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                      style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: t.emailOrUsername,
                        labelStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFF64748B),
                          size: 22,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF1C4CA5),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 1,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return t.pleaseEnterEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password Field - Flat Design
                    TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _handleLogin(auth),
                      style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: t.password,
                        labelStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF64748B),
                          size: 22,
                        ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF64748B),
                            size: 22,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF1C4CA5),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 1,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return t.pleaseEnterPassword;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Remember Me Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFF1C4CA5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _rememberMe = !_rememberMe;
                            });
                          },
                          child: Text(
                            t.rememberMe,
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Biometric Authentication Checkbox (only if available)
                    if (_biometricAvailable) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: _enableBiometric,
                            onChanged: (value) {
                              setState(() {
                                _enableBiometric = value ?? false;
                              });
                            },
                            activeColor: const Color(0xFF1C4CA5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _enableBiometric = !_enableBiometric;
                              });
                            },
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.fingerprint,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.enableBiometric,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Sign In Button - Flat Design
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : () => _handleLogin(auth),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C4CA5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                        ),
                  child: auth.isLoading
                      ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                t.signIn,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin(AsyncValue<dynamic> auth) async {
    if (_formKey.currentState?.validate() ?? false) {
      final u = _userCtrl.text.trim();
      final p = _passCtrl.text;
      
      // Save username if "Remember Me" is checked
      if (_rememberMe) {
        await SecureKv.write(SecureKeys.rememberedUsername, u);
        await SecureKv.write(SecureKeys.rememberMeEnabled, '1');
      } else {
        // Clear saved username if unchecked
        await SecureKv.delete(SecureKeys.rememberedUsername);
        await SecureKv.write(SecureKeys.rememberMeEnabled, '0');
      }
      
      // Save biometric preference
      if (_biometricAvailable) {
        await SecureKv.write(SecureKeys.biometricEnabled, _enableBiometric ? '1' : '0');
      }
      
      ref.read(authControllerProvider.notifier).login(
            usernameOrEmail: u,
            password: p,
          );
    }
  }
}
