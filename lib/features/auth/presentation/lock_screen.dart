import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: lockService,
      builder: (ctx, child) {
        if (lockService.status == AppLockStatus.cooldown &&
            lockService.cooldownUntil != null &&
            _remainingCooldownSeconds <= 0) {
          _startCooldownTimer(lockService.cooldownUntil!);
        }

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Spacer(),
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Masukkan PIN',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Buka aplikasi Anak Kost Anda',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 32),

              // Indikator 6 Digit PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? theme.colorScheme.primary : Colors.transparent,
                      border: Border.all(
                        color: theme.colorScheme.primary,
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),

              const Spacer(),

              // NumPad Grid
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  children: [
                    _buildRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (lockService.isBiometricsSupported)
                          IconButton(
                            iconSize: 32,
                            icon: const Icon(Icons.fingerprint),
                            onPressed: _onBiometricsPressed,
                          )
                        else
                          const SizedBox(width: 64, height: 64),
                        _buildButton('0'),
                        IconButton(
                          iconSize: 28,
                          icon: const Icon(Icons.backspace_outlined),
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
    final theme = Theme.of(context);
    return SizedBox(
      width: 68,
      height: 68,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        onPressed: () => _onDigitPressed(digit),
        child: Text(
          digit,
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
