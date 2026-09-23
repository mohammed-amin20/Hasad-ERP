import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/brand_lockup.dart';
import '../../../core/widgets/brand_logo.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  late final AnimationController _entrance;

  bool _submitting = false;
  String? _error;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
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
            Positioned(
              bottom: 36,
              right: 36,
              width: 220,
              height: 190,
              child: Opacity(
                opacity: 0.07,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: SvgPicture.asset(
                    BrandAssets.mono,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: screenWidth * 0.92),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _entrance,
                      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                    ),
                    child: SlideTransition(
                      position: _entrance.drive(
                        Tween(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeOutCubic)),
                      ),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.97, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _entrance,
                            curve: const Interval(
                              0.0,
                              0.8,
                              curve: Curves.easeOut,
                            ),
                          ),
                        ),
                        child: _LoginCard(
                          formKey: _formKey,
                          email: _email,
                          password: _password,
                          obscure: _obscure,
                          onToggleObscure: () =>
                              setState(() => _obscure = !_obscure),
                          error: _error,
                          submitting: _submitting,
                          onSubmit: _submit,
                        ),
                      ),
                    ),
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

/// Brand header for the login card: the official squircle on a soft amber
/// halo, the Arabic wordmark + Latin submark (BrandLockup), the tagline, and
/// a slim brand-gradient accent line echoing the stat-card accent pattern.
class _BrandMoment extends StatelessWidget {
  const _BrandMoment();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandEnd.withValues(alpha: 0.16),
                    AppColors.brandEnd.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const SizedBox(width: 180, height: 180),
            ),
            const BrandLockup(width: 200),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'منصة إدارة الأعمال والمحاسبة الذكية',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 4,
          width: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: AppColors.brandGradient,
          ),
        ),
      ],
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
            const _BrandMoment(),
            const SizedBox(height: 24),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                hintText: 'name@example.com',
                prefixIcon: FaIcon(
                  FontAwesomeIcons.envelope,
                  size: 20,
                  color: AppColors.inputIcon,
                ),
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
                prefixIcon: const FaIcon(
                  FontAwesomeIcons.lock,
                  size: 20,
                  color: AppColors.inputIcon,
                ),
                suffixIcon: IconButton(
                  iconSize: 20,
                  tooltip: obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                  onPressed: onToggleObscure,
                  icon: FaIcon(
                    obscure
                        ? FontAwesomeIcons.eye
                        : FontAwesomeIcons.eyeSlash,
                    color: AppColors.inputIcon,
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
