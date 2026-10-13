import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/providers/core_providers.dart';

class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) async {
    if (!_isConfirming) {
      if (_firstPin.length < 6) {
        setState(() {
          _firstPin += digit;
          _errorMessage = null;
        });
        if (_firstPin.length == 6) {
          setState(() {
            _isConfirming = true;
          });
        }
      }
    } else {
      if (_confirmPin.length < 6) {
        setState(() {
          _confirmPin += digit;
          _errorMessage = null;
        });
        if (_confirmPin.length == 6) {
          if (_firstPin == _confirmPin) {
            final lockService = ref.read(appLockServiceProvider);
            await lockService.setupPin(_confirmPin);
            if (mounted) {
              context.go('/');
            }
          } else {
            setState(() {
              _firstPin = '';
              _confirmPin = '';
              _isConfirming = false;
              _errorMessage = 'PIN tidak cocok. Silakan ulangi dari awal.';
            });
          }
        }
      }
    }
  }

  void _onBackspacePressed() {
    if (!_isConfirming) {
      if (_firstPin.isNotEmpty) {
        setState(() {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
          _errorMessage = null;
        });
      }
    } else {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isConfirming = false;
          _firstPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _firstPin;

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
                  Icons.shield_outlined,
                  size: 30,
                  color: AppTheme.primaryTeal,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Konfirmasi PIN' : 'Buat PIN 6-Digit',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Masukkan kembali PIN yang sama'
                    : 'PIN ini melindungi seluruh data keuangan & dokumen di perangkat',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Indikator 6 Digit
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = index < currentPin.length;
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
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
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
