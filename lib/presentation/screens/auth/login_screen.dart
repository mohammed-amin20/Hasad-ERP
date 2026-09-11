import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';

/// Sign-in screen matching the reference HTML login: a dark navy→blue
/// gradient backdrop, radial glows, and a white radius-24 card with the
/// wheat logo, tagline, credentials form, and demo-accounts hint.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _submitting = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      // Success: HasadApp reacts to the auth stream and swaps to the shell.
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = mapErrorToAppException(error).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1120),
              Color(0xFF122043),
              Color(0xFF1E3A8A),
              Color(0xFF2563EB),
            ],
            stops: [0, 0.42, 0.76, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -180,
              right: -120,
              width: 520,
              height: 520,
              child: const _Glow(
                gradient: RadialGradient(
                  colors: [Color(0x472562EB), Colors.transparent],
                ),
              ),
            ),
            Positioned(
              bottom: -160,
              left: -140,
              width: 560,
              height: 560,
              child: const _Glow(
                gradient: RadialGradient(
                  colors: [Color(0x29D97706), Colors.transparent],
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth * 0.92),
                  child: _LoginCard(
                    formKey: _formKey,
                    email: _email,
                    password: _password,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    error: _error,
                    submitting: _submitting,
                    onSubmit: _submit,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.gradient});

  final RadialGradient gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.error,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final String? error;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 400,
      padding: const EdgeInsets.fromLTRB(36, 40, 36, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xD9E2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80020617),
            blurRadius: 70,
            offset: Offset(0, 30),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _LoginLogo()),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'حصاد',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  ' Hasad',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'منصة إدارة الأعمال والمحاسبة الذكية',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                hintText: 'name@example.com',
                prefixIcon: FaIcon(FontAwesomeIcons.envelope),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'أدخل البريد الإلكتروني';
                }
                if (!value.contains('@')) {
                  return 'البريد الإلكتروني غير صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: password,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const FaIcon(FontAwesomeIcons.lock),
                suffixIcon: IconButton(
                  tooltip: obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                  onPressed: onToggleObscure,
                  icon: FaIcon(
                    obscure ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'أدخل كلمة المرور';
                }
                return null;
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.circleExclamation,
                      color: AppColors.danger,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: AppTheme.light.textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: AppProgress(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.arrowRightFromBracket,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('تسجيل الدخول'),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(
                      text: 'حساب تجريبي (مدير الشركة):',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const TextSpan(text: '\n'),
                    TextSpan(text: 'owner4@test.local   /   Test@1234567'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginLogo extends StatelessWidget {
  const _LoginLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB45309), Color(0xFFF59E0B), Color(0xFFFBBF24)],
          stops: [0, 0.55, 1],
        ),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x66D97706),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
          BoxShadow(color: Color(0x59FFFFFF), offset: Offset(0, -1)),
        ],
      ),
      child: const FaIcon(
        FontAwesomeIcons.wheatAwn,
        color: Colors.white,
        semanticLabel: 'شعار حصاد',
        size: 34,
      ),
    );
  }
}
