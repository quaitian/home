import 'umalqura_data.dart';

/// Hijri calculation methods compared by the app.
enum HijriMethod { ummAlQura, civil, astronomical }

extension HijriMethodInfo on HijriMethod {
  String get nameAr => switch (this) {
    HijriMethod.ummAlQura => 'أم القرى',
    HijriMethod.civil => 'الحسابي (الجدولي)',
    HijriMethod.astronomical => 'الحسابي الفلكي',
  };
  String get descAr => switch (this) {
    HijriMethod.ummAlQura => 'المعتمد رسمياً في السعودية',
    HijriMethod.civil => 'دورة 30 سنة، بداية مدنية (الجمعة)',
    HijriMethod.astronomical => 'دورة 30 سنة، بداية فلكية (الخميس)',
  };
}

class HijriDate {
  final int year, month, day;
  const HijriDate(this.year, this.month, this.day);
  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() => '$day/$month/$year';
}

const hijriMonthsAr = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];
const gregMonthsAr = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Indexed by DateTime.weekday (1 = Monday … 7 = Sunday).
const weekdaysAr = [
  '',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

// ---------- Julian Day Number helpers (proleptic Gregorian) ----------

int _fdiv(int a, int b) => (a / b).floor();

int jdnFromGregorian(int y, int m, int d) {
  final a = _fdiv(14 - m, 12);
  final yy = y + 4800 - a;
  final mm = m + 12 * a - 3;
  return d +
      _fdiv(153 * mm + 2, 5) +
      365 * yy +
      _fdiv(yy, 4) -
      _fdiv(yy, 100) +
      _fdiv(yy, 400) -
      32045;
}

DateTime gregorianFromJdn(int jdn) {
  final a = jdn + 32044;
  final b = _fdiv(4 * a + 3, 146097);
  final c = a - _fdiv(146097 * b, 4);
  final d = _fdiv(4 * c + 3, 1461);
  final e = c - _fdiv(1461 * d, 4);
  final m = _fdiv(5 * e + 2, 153);
  final day = e - _fdiv(153 * m + 2, 5) + 1;
  final month = m + 3 - 12 * _fdiv(m, 10);
  final year = 100 * b + d - 4800 + _fdiv(m, 10);
  return DateTime.utc(year, month, day);
}

int jdnOf(DateTime g) => jdnFromGregorian(g.year, g.month, g.day);

// ---------- Tabular (arithmetical) Islamic calendar ----------

const _civilEpoch = 1948440; // Friday 16 July 622
const _astroEpoch = 1948439; // Thursday 15 July 622

int _tabEpoch(HijriMethod m) =>
    m == HijriMethod.astronomical ? _astroEpoch : _civilEpoch;

bool _tabLeap(int y) => (14 + 11 * y) % 30 < 11;

int _tabMonthLength(int y, int m) =>
    (m % 2 == 1 || (m == 12 && _tabLeap(y))) ? 30 : 29;

int _tabToJdn(int y, int m, int d, int epoch) =>
    d +
    (29.5 * (m - 1)).ceil() +
    (y - 1) * 354 +
    _fdiv(3 + 11 * y, 30) +
    epoch -
    1;

HijriDate _tabFromJdn(int jdn, int epoch) {
  final y = _fdiv(30 * (jdn - epoch) + 10646, 10631);
  var m = (((jdn - (29 + _tabToJdn(y, 1, 1, epoch))) / 29.5).ceil() + 1);
  if (m > 12) m = 12;
  if (m < 1) m = 1;
  final d = jdn - _tabToJdn(y, m, 1, epoch) + 1;
  return HijriDate(y, m, d);
}

// ---------- Umm al-Qura (table 1300–1600 AH) ----------

final List<int> _uqMonthStarts = () {
  final starts = <int>[];
  var jdn = ummAlQuraStartJdn;
  for (final mask in ummAlQuraMasks) {
    for (var m = 0; m < 12; m++) {
      starts.add(jdn);
      jdn += (mask >> m) & 1 == 1 ? 30 : 29;
    }
  }
  starts.add(jdn); // sentinel: 1 Muharram after the last year
  return starts;
}();

const ummAlQuraLastYear = 1600;

bool ummAlQuraCoversYear(int y) =>
    y >= ummAlQuraFirstYear && y <= ummAlQuraLastYear;

bool ummAlQuraCoversJdn(int jdn) =>
    jdn >= _uqMonthStarts.first && jdn < _uqMonthStarts.last;

int _uqMonthLength(int y, int m) =>
    (ummAlQuraMasks[y - ummAlQuraFirstYear] >> (m - 1)) & 1 == 1 ? 30 : 29;

HijriDate _uqFromJdn(int jdn) {
  var lo = 0, hi = _uqMonthStarts.length - 2;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (_uqMonthStarts[mid] <= jdn) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return HijriDate(
    ummAlQuraFirstYear + lo ~/ 12,
    lo % 12 + 1,
    jdn - _uqMonthStarts[lo] + 1,
  );
}

// ---------- Public API ----------

/// Whether [method] is evaluated from its own data for year [y]
/// (Umm al-Qura outside 1300–1600 AH falls back to the civil calendar).
bool usesFallback(HijriMethod method, int y) =>
    method == HijriMethod.ummAlQura && !ummAlQuraCoversYear(y);

int monthLength(HijriMethod method, int y, int m) {
  if (method == HijriMethod.ummAlQura && ummAlQuraCoversYear(y)) {
    return _uqMonthLength(y, m);
  }
  return _tabMonthLength(y, m);
}

/// Gregorian → Hijri.
HijriDate toHijri(DateTime g, HijriMethod method) {
  final jdn = jdnOf(g);
  if (method == HijriMethod.ummAlQura && ummAlQuraCoversJdn(jdn)) {
    return _uqFromJdn(jdn);
  }
  return _tabFromJdn(
    jdn,
    method == HijriMethod.ummAlQura ? _civilEpoch : _tabEpoch(method),
  );
}

/// Hijri → Gregorian. Returns null if the day does not exist in that month.
DateTime? toGregorian(HijriDate h, HijriMethod method) {
  if (h.month < 1 || h.month > 12 || h.day < 1) return null;
  if (h.day > monthLength(method, h.year, h.month)) return null;
  if (method == HijriMethod.ummAlQura && ummAlQuraCoversYear(h.year)) {
    final idx = (h.year - ummAlQuraFirstYear) * 12 + h.month - 1;
    return gregorianFromJdn(_uqMonthStarts[idx] + h.day - 1);
  }
  final epoch = method == HijriMethod.ummAlQura
      ? _civilEpoch
      : _tabEpoch(method);
  return gregorianFromJdn(_tabToJdn(h.year, h.month, h.day, epoch));
}

String formatHijri(HijriDate h) =>
    '${h.day} ${hijriMonthsAr[h.month - 1]} ${h.year}هـ';
String formatGregorian(DateTime g) =>
    '${g.day} ${gregMonthsAr[g.month - 1]} ${g.year}م';
String _p2(int n) => n.toString().padLeft(2, '0');
String numericHijri(HijriDate h) => '${_p2(h.day)}/${_p2(h.month)}/${h.year}';
String numericGregorian(DateTime g) =>
    '${_p2(g.day)}/${_p2(g.month)}/${g.year}';

/// Arabic count of days with correct grammatical form.
String daysAr(int n) {
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومان';
  if (n >= 3 && n <= 10) return '$n أيام';
  return '$n يوماً';
}

/// "بيوم / بيومين / بـ 3 أيام".
String byDaysAr(int n) => n == 1
    ? 'بيوم'
    : n == 2
    ? 'بيومين'
    : 'بـ ${daysAr(n)}';

/// "قبل/بعد N يوم" relative to [today].
String relativeAr(DateTime date, DateTime today) {
  final n = jdnOf(date) - jdnOf(today);
  if (n == 0) return 'اليوم';
  final a = n.abs();
  final w = a == 1
      ? 'يوم واحد'
      : a == 2
      ? 'يومين'
      : (a <= 10 ? '$a أيام' : '$a يوماً');
  return n > 0 ? 'بعد $w' : 'قبل $w';
}
