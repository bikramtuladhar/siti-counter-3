library;

/// Represents a date in the Bikram Sambat (BS) calendar.
class BsDate {
  final int year;
  final int month; // 1 = Baisakh, 12 = Chaitra
  final int day;

  const BsDate({
    required this.year,
    required this.month,
    required this.day,
  });

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')} BS';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BsDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => year.hashCode ^ month.hashCode ^ day.hashCode;
}

enum RituName {
  basanta,
  grishma,
  barsha,
  sharad,
  hemanta,
  shishir,
}

class RituInfo {
  final RituName id;
  final String nameEn;
  final String nameNe;
  final List<int> bsMonths;
  final String element;

  const RituInfo({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    required this.bsMonths,
    required this.element,
  });
}

class NepaliCalendar {
  static const List<String> nepaliMonthsNe = [
    'बैशाख', 'जेठ', 'असार', 'साउन', 'भदौ', 'असोज',
    'कात्तिक', 'मंसिर', 'पुस', 'माघ', 'फागुन', 'चैत'
  ];

  static const List<String> nepaliMonthsEn = [
    'Baisakh', 'Jestha', 'Ashadh', 'Shrawan', 'Bhadra', 'Ashwin',
    'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra'
  ];

  static const List<String> nepaliDaysNe = [
    'आइतबार', 'सोमबार', 'मङ्गलबार', 'बुधबार', 'बिहीबार', 'शुक्रबार', 'शनिबार'
  ];

  static const List<String> devanagariDigits = [
    '०', '१', '२', '३', '४', '५', '६', '७', '८', '९'
  ];

  static const Map<RituName, RituInfo> sixRitus = {
    RituName.basanta: RituInfo(
      id: RituName.basanta,
      nameEn: 'Basanta (Spring)',
      nameNe: 'बसन्त',
      bsMonths: [12, 1],
      element: 'Air & Blossom',
    ),
    RituName.grishma: RituInfo(
      id: RituName.grishma,
      nameEn: 'Grishma (Summer)',
      nameNe: 'ग्रीष्म',
      bsMonths: [2, 3],
      element: 'Heat & Sun',
    ),
    RituName.barsha: RituInfo(
      id: RituName.barsha,
      nameEn: 'Barsha (Monsoon)',
      nameNe: 'वर्षा',
      bsMonths: [4, 5],
      element: 'Rain & Growth',
    ),
    RituName.sharad: RituInfo(
      id: RituName.sharad,
      nameEn: 'Sharad (Autumn)',
      nameNe: 'शरद',
      bsMonths: [6, 7],
      element: 'Harvest & Festivity',
    ),
    RituName.hemanta: RituInfo(
      id: RituName.hemanta,
      nameEn: 'Hemanta (Late Autumn)',
      nameNe: 'हेमन्त',
      bsMonths: [8, 9],
      element: 'Crisp Dew & Fermentation',
    ),
    RituName.shishir: RituInfo(
      id: RituName.shishir,
      nameEn: 'Shishir (Winter)',
      nameNe: 'शिशिर',
      bsMonths: [10, 11],
      element: 'Frost & Roots',
    ),
  };

  static const Map<int, List<int>> bsCalendarData = {
    2075: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2076: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2077: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2078: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
    2079: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2080: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
    2081: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
    2082: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2084: [31, 31, 32, 31, 31, 30, 30, 30, 29, 30, 30, 30],
    2085: [31, 32, 31, 32, 30, 31, 30, 30, 29, 30, 30, 30],
  };

  static const BsDate anchorBs = BsDate(year: 2080, month: 1, day: 1);
  static final DateTime anchorAd = DateTime.utc(2023, 4, 14);

  /// Converts English/Western digits into Devanagari numerals.
  static String toDevanagariDigits(dynamic value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final code = str.codeUnitAt(i);
      if (code >= 48 && code <= 57) {
        buffer.write(devanagariDigits[code - 48]);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// Formats integer into South Asian Lakh/Crore grouping (e.g. 1,00,000 / 12,50,000)
  static String formatLakhCrore(
    num amount, {
    bool preferDevanagari = false,
    bool includeCurrency = false,
  }) {
    final isNegative = amount < 0;
    final absAmount = amount.abs().round();
    final str = absAmount.toString();
    String formatted;

    if (str.length <= 3) {
      formatted = str;
    } else {
      final lastThree = str.substring(str.length - 3);
      final remaining = str.substring(0, str.length - 3);

      final parts = <String>[];
      var rem = remaining;
      while (rem.length > 2) {
        parts.insert(0, rem.substring(rem.length - 2));
        rem = rem.substring(0, rem.length - 2);
      }
      if (rem.isNotEmpty) {
        parts.insert(0, rem);
      }

      formatted = '${parts.join(',')},$lastThree';
    }

    if (isNegative) {
      formatted = '-$formatted';
    }

    if (preferDevanagari) {
      formatted = toDevanagariDigits(formatted);
    }

    if (includeCurrency) {
      final symbol = preferDevanagari ? 'रू ' : 'NPR ';
      formatted = '$symbol$formatted';
    }

    return formatted;
  }

  /// Resolves the corresponding Six Ritus (ऋतु) from a BS Month (1 to 12).
  static RituInfo getRituForBsMonth(int bsMonth) {
    if (bsMonth == 12 || bsMonth == 1) return sixRitus[RituName.basanta]!;
    if (bsMonth == 2 || bsMonth == 3) return sixRitus[RituName.grishma]!;
    if (bsMonth == 4 || bsMonth == 5) return sixRitus[RituName.barsha]!;
    if (bsMonth == 6 || bsMonth == 7) return sixRitus[RituName.sharad]!;
    if (bsMonth == 8 || bsMonth == 9) return sixRitus[RituName.hemanta]!;
    return sixRitus[RituName.shishir]!;
  }

  /// Converts Gregorian [adDate] to [BsDate].
  static BsDate gregorianToBs(DateTime adDate) {
    final targetUtc = DateTime.utc(adDate.year, adDate.month, adDate.day);
    var diffDays = targetUtc.difference(anchorAd).inDays;

    var currentYear = anchorBs.year;
    var currentMonth = anchorBs.month;
    var currentDay = anchorBs.day;

    if (diffDays >= 0) {
      while (diffDays > 0) {
        final yearDays = bsCalendarData[currentYear];
        if (yearDays == null) {
          throw ArgumentError('BS year $currentYear out of supported range');
        }
        final daysInMonth = yearDays[currentMonth - 1];
        final remainingInMonth = daysInMonth - currentDay;

        if (diffDays <= remainingInMonth) {
          currentDay += diffDays;
          diffDays = 0;
        } else {
          diffDays -= (remainingInMonth + 1);
          currentDay = 1;
          currentMonth++;
          if (currentMonth > 12) {
            currentMonth = 1;
            currentYear++;
          }
        }
      }
    } else {
      diffDays = diffDays.abs();
      while (diffDays > 0) {
        if (currentDay > diffDays) {
          currentDay -= diffDays;
          diffDays = 0;
        } else {
          diffDays -= currentDay;
          currentMonth--;
          if (currentMonth < 1) {
            currentMonth = 12;
            currentYear--;
          }
          final yearDays = bsCalendarData[currentYear];
          if (yearDays == null) {
            throw ArgumentError('BS year $currentYear out of supported range');
          }
          currentDay = yearDays[currentMonth - 1];
        }
      }
    }

    return BsDate(year: currentYear, month: currentMonth, day: currentDay);
  }

  /// Formats [BsDate] with localized Nepali or English month names.
  static String formatBs(
    BsDate bs, {
    bool preferNepali = true,
    bool includeYear = true,
  }) {
    final monthName = preferNepali
        ? nepaliMonthsNe[bs.month - 1]
        : nepaliMonthsEn[bs.month - 1];

    final dayStr = preferNepali
        ? toDevanagariDigits(bs.day)
        : bs.day.toString();
    final yearStr = preferNepali
        ? toDevanagariDigits(bs.year)
        : bs.year.toString();

    if (includeYear) {
      return preferNepali
          ? '$yearStr $monthName $dayStr'
          : '$monthName $dayStr, $yearStr BS';
    }
    return '$monthName $dayStr';
  }
}
