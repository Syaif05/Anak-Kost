import 'package:flutter_test/flutter_test.dart';
import 'package:anakkost/core/constants/money.dart';
import 'package:anakkost/core/constants/stock.dart';

void main() {
  group('Money Invariants Tests (IDR int64)', () {
    test('Format nominal uang integer rupiah', () {
      expect(Money.format(15000), 'Rp15.000');
      expect(Money.format(1000000), 'Rp1.000.000');
      expect(Money.format(0), 'Rp0');
      expect(Money.format(2500, withSymbol: false), '2.500');
    });

    test('Parse input pengguna ke integer rupiah', () {
      expect(Money.parse('15.000'), 15000);
      expect(Money.parse('Rp 15.000'), 15000);
      expect(Money.parse('Rp1.500.000'), 1500000);
      expect(Money.parse('25000'), 25000);
      expect(Money.parse(''), 0);
      expect(Money.parse('   '), 0);
    });

    test('Validasi nominal positif', () {
      expect(Money.isValidPositive(15000), isTrue);
      expect(Money.isValidPositive(0), isFalse);
      expect(Money.isValidPositive(-5000), isFalse);
    });
  });

  group('Stock Invariants Tests (Fixed Precision Milli-Units)', () {
    test('Konversi kuantitas desimal ke milli-unit int64', () {
      expect(Stock.toMilliUnit(1.25), 1250);
      expect(Stock.toMilliUnit(5), 5000);
      expect(Stock.toMilliUnit(0.001), 1);
    });

    test('Parse string kuantitas input pengguna ke milli-unit', () {
      expect(Stock.parseToMilliUnit('1,25'), 1250);
      expect(Stock.parseToMilliUnit('1.25'), 1250);
      expect(Stock.parseToMilliUnit('5'), 5000);
      expect(Stock.parseToMilliUnit('0'), 0);
      expect(Stock.parseToMilliUnit(''), 0);
    });

    test('Konversi milli-unit kembali ke desimal & format display', () {
      expect(Stock.toDecimal(1250), 1.25);
      expect(Stock.format(1250, unit: 'pcs'), '1,25 pcs');
      expect(Stock.format(5000, unit: 'g'), '5 g');
    });
  });
}
