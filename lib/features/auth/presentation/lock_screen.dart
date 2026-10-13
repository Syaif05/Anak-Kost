import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/security/app_lock_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _enteredPin = '';
  String? _errorMessage;
  Timer? _cooldownTimer;
  int _remainingCooldownSeconds = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer(DateTime until) {
    _cooldownTimer?.cancel();
    _remainingCooldownSeconds = until.difference(DateTime.now()).inSeconds;
    if (_remainingCooldownSeconds <= 0) return;

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = until.difference(DateTime.now()).inSeconds;
      setState(() {
        _remainingCooldownSeconds = remaining;
      });
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  void _onDigitPressed(String digit) async {
    final lockService = ref.read(appLockServiceProvider);
    if (lockService.status == AppLockStatus.cooldown) {
      return;
    }

    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == 6) {
        final success = await lockService.unlockWithPin(_enteredPin);
        if (!mounted) return;

        if (success) {
          context.go('/');
        } else {
          setState(() {
            _enteredPin = '';
            if (lockService.status == AppLockStatus.cooldown && lockService.cooldownUntil != null) {
              _startCooldownTimer(lockService.cooldownUntil!);
              _errorMessage = 'Terlalu banyak percobaan salah. Tunggu sebentar.';
            } else {
              _errorMessage = 'PIN salah (${lockService.failedAttempts}x)';
            }
          });
        }
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onBiometricsPressed() async {
    final lockService = ref.read(appLockServiceProvider);
    final success = await lockService.unlockWithBiometrics();
    if (!mounted) return;
    if (success) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockService = ref.watch(appLockServiceProvider);

    return ListenableBuilder(
      listenable: lockService,
      builder: (ctx, child) {
        if (lockService.status == AppLockStatus.cooldown &&
            lockService.cooldownUntil != null &&
            _remainingCooldownSeconds <= 0) {
          _startCooldownTimer(lockService.cooldownUntil!);
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSecondary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 30,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Masukkan PIN',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Buka aplikasi Dompet Kos Anda',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Indikator 6 Digit PIN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      final isFilled = index < _enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? AppTheme.primaryTeal : Colors.transparent,
                          border: Border.all(
                            color: isFilled ? AppTheme.primaryTeal : AppTheme.borderColor,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 16),
                  if (_remainingCooldownSeconds > 0)
                    Text(
                      'Coba lagi dalam $_remainingCooldownSeconds detik',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  const Spacer(),

                  // NumPad Grid
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      children: [
                        _buildRow(['1', '2', '3']),
                        const SizedBox(height: 14),
                        _buildRow(['4', '5', '6']),
                        const SizedBox(height: 14),
                        _buildRow(['7', '8', '9']),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (lockService.isBiometricsSupported)
                              IconButton(
                                iconSize: 28,
                                icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryTeal),
                                onPressed: _onBiometricsPressed,
                              )
                            else
                              const SizedBox(width: 68, height: 68),
                            _buildButton('0'),
                            IconButton(
                              iconSize: 26,
                              icon: const Icon(Icons.backspace_outlined, color: AppTheme.textSecondary),
                              onPressed: _onBackspacePressed,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildButton).toList(),
    );
  }

  Widget _buildButton(String digit) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onDigitPressed(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
