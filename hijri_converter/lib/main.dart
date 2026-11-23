import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'calendar.dart';

void main() => runApp(const HijriApp());

const _seed = Color(0xFF1F6F63);

class HijriApp extends StatelessWidget {
  const HijriApp({super.key});

  ThemeData _theme(Brightness b) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: b),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'محوّل التاريخ الهجري',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: const ConverterPage(),
  );
}

enum Mode { h2g, g2h }

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});
  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  Mode mode = Mode.h2g;
  HijriMethod method = HijriMethod.ummAlQura;
  int day = 1, month = 9;
  final yearCtrl = TextEditingController(text: '1447');
  String? error;
  _Result? result;

  DateTime get today {
    final n = DateTime.now();
    return DateTime.utc(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _convert();
  }

  @override
  void dispose() {
    yearCtrl.dispose();
    super.dispose();
  }

  void _setToday() {
    final t = today;
    if (mode == Mode.h2g) {
      final h = toHijri(t, method);
      _setInputs(h.year, h.month, h.day);
    } else {
      _setInputs(t.year, t.month, t.day);
    }
  }

  void _setInputs(int y, int m, int d) {
    yearCtrl.text = '$y';
    month = m;
    day = d;
  }

  void _switchMode(Mode m) {
    setState(() {
      mode = m;
      _setToday();
      _convert();
    });
  }

  void _swap() {
    final r = result;
    if (r == null) return;
    setState(() {
      if (mode == Mode.h2g) {
        mode = Mode.g2h;
        _setInputs(r.gregorian.year, r.gregorian.month, r.gregorian.day);
      } else {
        mode = Mode.h2g;
        method = HijriMethod.ummAlQura;
        _setInputs(r.hijri.year, r.hijri.month, r.hijri.day);
      }
      _convert();
    });
  }

  void _convert() {
    error = null;
    final y = int.tryParse(yearCtrl.text.trim());
    if (y == null) {
      error = 'اكتب السنة بالأرقام.';
      result = null;
      return;
    }
    if (mode == Mode.h2g) {
      if (y < 1 || y > 1700) {
        error = 'أدخل سنة هجرية بين 1 و1700.';
        result = null;
        return;
      }
      final h = HijriDate(y, month, day);
      final g = toGregorian(h, method);
      if (g == null) {
        error =
            'شهر ${hijriMonthsAr[month - 1]} $yهـ في تقويم ${method.nameAr} '
            'عدد أيامه ${monthLength(method, y, month)} يوماً فقط، فلا يوجد يوم $day.';
        result = null;
        return;
      }
      final rows = HijriMethod.values.map((mt) {
        final t = toGregorian(h, mt);
        return _Row(
          method: mt,
          text: t == null
              ? 'لا يوجد هذا اليوم (الشهر 29 يوماً)'
              : '${weekdaysAr[t.weekday]} ${formatGregorian(t)}',
          diff: t == null ? null : jdnOf(t) - jdnOf(g),
        );
      }).toList();
      result = _Result(
        hijri: h,
        gregorian: g,
        main: formatGregorian(g),
        alt: '${formatHijri(h)}  ←  ${numericGregorian(g)}',
        chips: [
          relativeAr(g, today),
          '${hijriMonthsAr[month - 1]} هذا العام ${monthLength(method, y, month)} يوماً',
          if (usesFallback(method, y)) 'خارج جدول أم القرى: حساب جدولي',
        ],
        rows: rows,
      );
    } else {
      if (y < 622 || y > 2200) {
        error = 'أدخل سنة ميلادية بين 622 و2200.';
        result = null;
        return;
      }
      final g = DateTime.utc(y, month, day);
      if (g.month != month) {
        error = 'شهر ${gregMonthsAr[month - 1]} $y ليس فيه يوم $day.';
        result = null;
        return;
      }
      final main = toHijri(g, HijriMethod.ummAlQura);
      final ref = toGregorian(main, HijriMethod.ummAlQura)!;
      final rows = HijriMethod.values.map((mt) {
        final h = toHijri(g, mt);
        final t = toGregorian(main, mt);
        // Negative: this method starts the month earlier than Umm al-Qura.
        final diff = h == main ? 0 : (t == null ? -1 : jdnOf(t) - jdnOf(ref));
        return _Row(method: mt, text: formatHijri(h), diff: diff);
      }).toList();
      result = _Result(
        hijri: main,
        gregorian: g,
        main: formatHijri(main),
        alt: '${formatGregorian(g)}  ←  ${numericHijri(main)}',
        chips: [relativeAr(g, today), 'حسب تقويم أم القرى'],
        rows: rows,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = today;
    final th = toHijri(t, HijriMethod.ummAlQura);
    return Scaffold(
      appBar: AppBar(
        title: const Text('محوّل التاريخ الهجري'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Card(
              color: cs.secondaryContainer,
              elevation: 0,
              child: ListTile(
                leading: Icon(
                  Icons.nightlight_round,
                  color: cs.onSecondaryContainer,
                ),
                title: const Text('اليوم'),
                subtitle: Text(
                  '${weekdaysAr[t.weekday]}، ${formatHijri(th)}\n${formatGregorian(t)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<Mode>(
              segments: const [
                ButtonSegment(value: Mode.h2g, label: Text('هجري ← ميلادي')),
                ButtonSegment(value: Mode.g2h, label: Text('ميلادي ← هجري')),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _switchMode(s.first),
            ),
            const SizedBox(height: 12),
            _inputCard(cs),
            const SizedBox(height: 12),
            if (error != null)
              Card(
                color: cs.errorContainer,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    error!,
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              ),
            if (result != null) ..._resultWidgets(context, result!),
            const SizedBox(height: 16),
            Text(
              'التقويم الهجري قمري، وبداية الشهر تعتمد على رؤية الهلال، لذلك قد يختلف '
              'التاريخ الفعلي في بلدك يوماً واحداً (وأحياناً يومين) عن أي حساب. '
              'تقويم أم القرى هو المعتمد رسمياً في السعودية، والتقويم الجدولي يستخدم '
              'دورة ثابتة من 30 سنة. في رمضان والعيدين يُعتمد إعلان الجهة الرسمية في بلدك.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputCard(ColorScheme cs) {
    final months = mode == Mode.h2g ? hijriMonthsAr : gregMonthsAr;
    final maxDay = mode == Mode.h2g ? 30 : 31;
    if (day > maxDay) day = maxDay;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('d-$mode-$day'),
                    initialValue: day,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اليوم',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 1; i <= maxDay; i++)
                        DropdownMenuItem(value: i, child: Text('$i')),
                    ],
                    onChanged: (v) => setState(() => day = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('m-$mode-$month'),
                    initialValue: month,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الشهر',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 0; i < 12; i++)
                        DropdownMenuItem(
                          value: i + 1,
                          child: Text(
                            '${i + 1} - ${months[i]}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => month = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: yearCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'السنة',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => setState(_convert),
                  ),
                ),
              ],
            ),
            if (mode == Mode.h2g) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<HijriMethod>(
                key: ValueKey('method-$method'),
                initialValue: method,
                decoration: const InputDecoration(
                  labelText: 'طريقة الحساب',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final m in HijriMethod.values)
                    DropdownMenuItem(value: m, child: Text(m.nameAr)),
                ],
                onChanged: (v) => setState(() {
                  method = v!;
                  _convert();
                }),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => setState(() {
                      FocusScope.of(context).unfocus();
                      _convert();
                    }),
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('حوّل التاريخ'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _setToday();
                    _convert();
                  }),
                  child: const Text('اليوم'),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'اعكس النتيجة',
                  onPressed: _swap,
                  icon: const Icon(Icons.swap_horiz),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _resultWidgets(BuildContext context, _Result r) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final maxDiff = r.rows
        .where((x) => x.diff != null)
        .fold<int>(0, (a, x) => x.diff!.abs() > a ? x.diff!.abs() : a);
    final same = maxDiff == 0;
    final okBg = Colors.green.withValues(alpha: 0.15);
    final warnBg = Colors.orange.withValues(alpha: 0.18);
    return [
      Card(
        elevation: 0,
        color: cs.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Text(
                weekdaysAr[r.gregorian.weekday],
                style: tt.titleMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                r.main,
                textAlign: TextAlign.center,
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                r.alt,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final c in r.chips)
                    Chip(label: Text(c), visualDensity: VisualDensity.compact),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: same ? okBg : warnBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              same ? Icons.check_circle : Icons.info,
              color: same ? Colors.green.shade700 : Colors.orange.shade800,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                same
                    ? 'لا يوجد اختلاف: جميع طرق الحساب تعطي التاريخ نفسه، ومع ذلك قد تختلف الرؤية المحلية يوماً واحداً.'
                    : 'يوجد اختلاف بمقدار ${daysAr(maxDiff)} بين طرق الحساب لهذا التاريخ. اعتمد التقويم الرسمي في بلدك.',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text('المقارنة بين طرق الحساب', style: tt.titleMedium),
            ),
            for (final row in r.rows)
              ListTile(
                title: Text(
                  row.method.nameAr,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${row.text}\n${row.method.descAr}'),
                isThreeLine: true,
                trailing: _diffChip(row.diff, okBg, warnBg),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _diffChip(int? diff, Color okBg, Color warnBg) {
    final String label;
    if (diff == null) {
      label = 'غير موجود';
    } else if (diff == 0) {
      label = 'مطابق';
    } else {
      label = '${diff < 0 ? 'متقدم' : 'متأخر'} ${byDaysAr(diff.abs())}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: diff == 0 ? okBg : warnBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _Row {
  final HijriMethod method;
  final String text;
  final int? diff;
  _Row({required this.method, required this.text, required this.diff});
}

class _Result {
  final HijriDate hijri;
  final DateTime gregorian;
  final String main, alt;
  final List<String> chips;
  final List<_Row> rows;
  _Result({
    required this.hijri,
    required this.gregorian,
    required this.main,
    required this.alt,
    required this.chips,
    required this.rows,
  });
}
