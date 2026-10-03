import 'package:kitchen_engine/nepali_calendar.dart';
import 'package:test/test.dart';

void main() {
  group('NepaliCalendar & BS Date Converter', () {
    test('converts anchor date 2023-04-14 to 2080-01-01 BS', () {
      final bs = NepaliCalendar.gregorianToBs(DateTime.utc(2023, 4, 14));
      expect(bs.year, equals(2080));
      expect(bs.month, equals(1));
      expect(bs.day, equals(1));
    });

    test('converts Dashain 2080 date correctly', () {
      final bs = NepaliCalendar.gregorianToBs(DateTime.utc(2023, 10, 24));
      expect(bs.year, equals(2080));
      expect(bs.month, equals(7));
      expect(bs.day, equals(7));
    });

    test('converts English digits to Devanagari numerals', () {
      expect(NepaliCalendar.toDevanagariDigits('0123456789'), equals('०१२३४५६७८९'));
      expect(NepaliCalendar.toDevanagariDigits(2081), equals('२०८१'));
    });

    test('formats Lakh-Crore numbers and NPR currency', () {
      expect(NepaliCalendar.formatLakhCrore(500), equals('500'));
      expect(NepaliCalendar.formatLakhCrore(1500), equals('1,500'));
      expect(NepaliCalendar.formatLakhCrore(100000), equals('1,00,000'));
      expect(NepaliCalendar.formatLakhCrore(1250000), equals('12,50,000'));
      expect(NepaliCalendar.formatLakhCrore(10000000), equals('1,00,00,000'));

      expect(
        NepaliCalendar.formatLakhCrore(125000, preferDevanagari: true, includeCurrency: true),
        equals('रू १,२५,०००'),
      );
      expect(
        NepaliCalendar.formatLakhCrore(125000, preferDevanagari: false, includeCurrency: true),
        equals('NPR 1,25,000'),
      );
    });

    test('resolves Six Ritus correctly for all 12 BS months', () {
      expect(NepaliCalendar.getRituForBsMonth(1).id, equals(RituName.basanta));
      expect(NepaliCalendar.getRituForBsMonth(2).id, equals(RituName.grishma));
      expect(NepaliCalendar.getRituForBsMonth(5).id, equals(RituName.barsha));
      expect(NepaliCalendar.getRituForBsMonth(6).id, equals(RituName.sharad));
      expect(NepaliCalendar.getRituForBsMonth(9).id, equals(RituName.hemanta));
      expect(NepaliCalendar.getRituForBsMonth(11).id, equals(RituName.shishir));
      expect(NepaliCalendar.getRituForBsMonth(12).id, equals(RituName.basanta));
    });

    test('formats BS date string in Nepali and English', () {
      const bs = BsDate(year: 2081, month: 6, day: 15);
      expect(NepaliCalendar.formatBs(bs, preferNepali: true), equals('२०८१ असोज १५'));
      expect(NepaliCalendar.formatBs(bs, preferNepali: false), equals('Ashwin 15, 2081 BS'));
    });
  });
}
