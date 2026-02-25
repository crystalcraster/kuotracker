import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const KuoApp());
}

class KuoApp extends StatelessWidget {
  const KuoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'КУО',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C3AED), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF09051A),
      ),
      home: const KuoHomePage(),
    );
  }
}

class Spirit {
  const Spirit({required this.key, required this.label, required this.color, required this.kuoCoeff, required this.units, required this.perUnitMl});

  final String key;
  final String label;
  final Color color;
  final double kuoCoeff;
  final List<String> units;
  final Map<String, double> perUnitMl;
}

const List<Spirit> spirits = [
  Spirit(key: 'beer', label: 'Пиво', color: Color(0xFFF5A623), kuoCoeff: 1, units: ['мл', 'л', 'банка'], perUnitMl: {'банка': 500}),
  Spirit(key: 'vodka', label: 'Водка', color: Color(0xFFA0C4FF), kuoCoeff: 5, units: ['мл', 'л', 'стоп'], perUnitMl: {'стоп': 50}),
  Spirit(key: 'wine', label: 'Вино', color: Color(0xFFC97AB5), kuoCoeff: 0, units: ['мл', 'л', 'бокал'], perUnitMl: {'бокал': 150}),
  Spirit(key: 'whiskey', label: 'Виски', color: Color(0xFFC07840), kuoCoeff: 0, units: ['мл', 'л', 'стоп'], perUnitMl: {'стоп': 50}),
  Spirit(key: 'cognac', label: 'Коньяк', color: Color(0xFFE8C47A), kuoCoeff: 0, units: ['мл', 'л', 'стоп'], perUnitMl: {'стоп': 50}),
  Spirit(key: 'rum', label: 'Ром', color: Color(0xFFD4622A), kuoCoeff: 0, units: ['мл', 'л', 'стоп'], perUnitMl: {'стоп': 50}),
  Spirit(key: 'tequila', label: 'Текила', color: Color(0xFFB8D96E), kuoCoeff: 0, units: ['мл', 'л', 'стоп'], perUnitMl: {'стоп': 50}),
  Spirit(key: 'gin', label: 'Джин', color: Color(0xFF7AC4C4), kuoCoeff: 0, units: ['мл', 'л', 'стоп'], perUnitMl: {'стоп': 50}),
];

const monthNames = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
const monthNamesShort = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];

class MonthMetrics {
  const MonthMetrics({required this.kuo, required this.maxSeries, required this.soberDays});

  final double kuo;
  final int maxSeries;
  final int soberDays;
}

class LeaderboardEntry {
  const LeaderboardEntry({required this.name, required this.kuo, required this.label, required this.timestamp});

  final String name;
  final double kuo;
  final String label;
  final int timestamp;

  Map<String, dynamic> toJson() => {'name': name, 'kuo': kuo, 'label': label, 'timestamp': timestamp};

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      name: (json['name'] ?? '').toString(),
      kuo: (json['kuo'] ?? 0).toDouble(),
      label: (json['label'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? 0) as int,
    );
  }
}

class KuoHomePage extends StatefulWidget {
  const KuoHomePage({super.key});

  @override
  State<KuoHomePage> createState() => _KuoHomePageState();
}

class _KuoHomePageState extends State<KuoHomePage> {
  static const String _logStorageKey = 'kuo_logs_v1';
  static const String _lbStorageKey = 'kuo_leaderboard_v1';

  final Map<String, Map<String, double>> _logs = {};
  final TextEditingController _nicknameController = TextEditingController();

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;
  bool _leaderboardAllTime = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_logStorageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final dayData = (entry.value as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
        _logs[entry.key] = dayData;
      }
    }

    if (_logs.isEmpty) {
      _loadDemoForCurrentMonth();
      await _saveLogs();
    }

    setState(() => _isLoading = false);
  }

  void _loadDemoForCurrentMonth() {
    final y = _currentMonth.year;
    final m = _currentMonth.month;
    _setLog(y, m, 1, {'beer_ml': 1500, 'wine_ml': 200});
    _setLog(y, m, 2, {'beer_ml': 2500, 'vodka_ml': 100, 'whiskey_ml': 100});
    _setLog(y, m, 3, {'beer_ml': 1000, 'vodka_ml': 200, 'wine_ml': 300});
    _setLog(y, m, 7, {'beer_ml': 3000, 'wine_ml': 450, 'rum_ml': 100});
    _setLog(y, m, 8, {'beer_ml': 2000, 'vodka_ml': 300, 'gin_ml': 100});
  }

  void _setLog(int year, int month, int day, Map<String, double> partial) {
    final key = _dayKey(DateTime(year, month, day));
    final base = {for (final s in spirits) '${s.key}_ml': 0.0};
    base.addAll(partial);
    _logs[key] = base;
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logStorageKey, jsonEncode(_logs));
  }

  String _dayKey(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  bool _isBinge(Map<String, double>? log) {
    if (log == null) return false;
    return spirits.any((s) => (log['${s.key}_ml'] ?? 0) > 0);
  }

  MonthMetrics _calcMonthMetrics(DateTime monthDate) {
    final y = monthDate.year;
    final m = monthDate.month;
    final dim = DateTime(y, m + 1, 0).day;

    int maxSeries = 0;
    int currentSeries = 0;
    int soberDays = 0;
    double maxBeer = 0;
    double maxVodka = 0;

    for (var d = 1; d <= dim; d++) {
      final log = _logs[_dayKey(DateTime(y, m, d))];
      if (_isBinge(log)) {
        currentSeries++;
        if (currentSeries > maxSeries) maxSeries = currentSeries;
        maxBeer = (log?['beer_ml'] ?? 0) > maxBeer ? (log?['beer_ml'] ?? 0) : maxBeer;
        maxVodka = (log?['vodka_ml'] ?? 0) > maxVodka ? (log?['vodka_ml'] ?? 0) : maxVodka;
      } else {
        currentSeries = 0;
        soberDays++;
      }
    }

    final kuo = (maxSeries * ((maxBeer / 1000) * 1 + (maxVodka / 1000) * 5));
    return MonthMetrics(kuo: double.parse(kuo.toStringAsFixed(2)), maxSeries: maxSeries, soberDays: soberDays);
  }

  ({double max, String label}) _calcAllTimeMax() {
    final months = <String>{};
    for (final key in _logs.keys) {
      months.add(key.substring(0, 7));
    }

    double maxKuo = 0;
    String label = 'за всё время';

    for (final month in months) {
      final parts = month.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final metrics = _calcMonthMetrics(DateTime(y, m));
      if (metrics.kuo > maxKuo) {
        maxKuo = metrics.kuo;
        label = '${monthNamesShort[m - 1]} $y';
      }
    }

    return (max: maxKuo, label: label);
  }

  int _calcSoberStreak() {
    var count = 0;
    var d = DateTime.now();
    while (count <= 730) {
      if (_isBinge(_logs[_dayKey(d)])) break;
      count++;
      d = d.subtract(const Duration(days: 1));
    }
    return count;
  }

  List<DateTime?> _buildCalendarDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final offset = first.weekday - 1;
    final dim = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[];

    for (var i = 0; i < offset; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= dim; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    return cells;
  }

  Future<List<LeaderboardEntry>> _readLeaderboard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lbStorageKey);
    if (raw == null) return [];
    final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return decoded.map(LeaderboardEntry.fromJson).toList();
  }

  Future<void> _writeLeaderboard(List<LeaderboardEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lbStorageKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> _submitLeaderboard() async {
    final name = _nicknameController.text.trim().toUpperCase();
    if (name.isEmpty) {
      setState(() => _statusText = 'Введите ник');
      return;
    }

    final monthMetrics = _calcMonthMetrics(_currentMonth);
    final allTime = _calcAllTimeMax();
    final monthLabel = '${monthNamesShort[_currentMonth.month - 1]} ${_currentMonth.year}';

    final entries = await _readLeaderboard();
    entries.add(LeaderboardEntry(name: name, kuo: monthMetrics.kuo, label: monthLabel, timestamp: DateTime.now().millisecondsSinceEpoch));

    final existingAllTime = entries.where((e) => e.name == name).map((e) => e.kuo).fold<double>(0, (prev, val) => val > prev ? val : prev);
    entries.add(LeaderboardEntry(
      name: '$name (ALL)',
      kuo: existingAllTime > allTime.max ? existingAllTime : allTime.max,
      label: allTime.label,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    await _writeLeaderboard(entries);
    setState(() => _statusText = 'Сохранено');
  }

  Future<void> _openLogSheet(DateTime date) async {
    final key = _dayKey(date);
    final source = _logs[key] ?? {for (final s in spirits) '${s.key}_ml': 0.0};

    final units = {for (final s in spirits) s.key: 'мл'};
    final values = {for (final s in spirits) s.key: source['${s.key}_ml'] ?? 0.0};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141026),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double stepFor(String unit) => unit == 'мл' ? 50 : unit == 'л' ? 0.05 : 1;

            double toMl(Spirit spirit, String unit, double value) {
              if (unit == 'мл') return value;
              if (unit == 'л') return value * 1000;
              return value * (spirit.perUnitMl[unit] ?? 1);
            }

            double fromMl(Spirit spirit, String unit, double ml) {
              if (unit == 'мл') return ml;
              if (unit == 'л') return ml / 1000;
              return ml / (spirit.perUnitMl[unit] ?? 1);
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Лог ${date.day}.${date.month}.${date.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ...spirits.map((spirit) {
                        final unit = units[spirit.key] ?? 'мл';
                        final displayValue = fromMl(spirit, unit, values[spirit.key] ?? 0);
                        return Card(
                          color: const Color(0xFF1B1530),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(backgroundColor: spirit.color, radius: 6),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(spirit.label)),
                                    DropdownButton<String>(
                                      value: unit,
                                      items: spirit.units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                      onChanged: (next) {
                                        if (next == null) return;
                                        setSheetState(() {
                                          units[spirit.key] = next;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        setSheetState(() {
                                          final next = (displayValue - stepFor(unit)).clamp(0, 99999).toDouble();
                                          values[spirit.key] = toMl(spirit, unit, next);
                                        });
                                      },
                                      icon: const Icon(Icons.remove_circle_outline),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: Text(displayValue.toStringAsFixed(unit == 'л' ? 2 : 0), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setSheetState(() {
                                          final next = (displayValue + stepFor(unit)).clamp(0, 99999).toDouble();
                                          values[spirit.key] = toMl(spirit, unit, next);
                                        });
                                      },
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _logs.remove(key);
                                });
                                _saveLogs();
                                Navigator.of(context).pop();
                              },
                              child: const Text('Очистить день'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _logs[key] = {for (final s in spirits) '${s.key}_ml': values[s.key] ?? 0};
                                });
                                _saveLogs();
                                Navigator.of(context).pop();
                              },
                              child: const Text('Сохранить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthMetrics = _calcMonthMetrics(_currentMonth);
    final allTime = _calcAllTimeMax();
    final soberStreak = _calcSoberStreak();
    final calendarDays = _buildCalendarDays(_currentMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('${monthNamesShort[_currentMonth.month - 1]} ${_currentMonth.year}'),
        actions: [
          IconButton(onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)), icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: () => _openLogSheet(DateTime.now()),
            icon: const Text('🍻', style: TextStyle(fontSize: 20)),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('ОТМЕТИТЬ СЕГОДНЯ'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _metricCard('КУО МЕСЯЦА', monthMetrics.kuo.toStringAsFixed(2), 'Серия: ${monthMetrics.maxSeries} дн.')),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('РЕКОРД', allTime.max.toStringAsFixed(2), allTime.label)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard('Трезвая серия', soberStreak.toString())),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Макс серия', monthMetrics.maxSeries.toString())),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Трезвые дни', monthMetrics.soberDays.toString())),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Календарь', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
            itemBuilder: (context, index) {
              final dt = calendarDays[index];
              if (dt == null) return const SizedBox.shrink();
              final log = _logs[_dayKey(dt)];
              final isToday = DateUtils.isSameDay(dt, DateTime.now());
              final binge = _isBinge(log);

              return InkWell(
                onTap: () => _openLogSheet(dt),
                child: Card(
                  color: binge ? const Color(0xFF3A2245) : const Color(0xFF141026),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isToday ? const Color(0xFF7C3AED) : Colors.transparent, width: 1.5),
                  ),
                  child: Center(child: Text('${dt.day}')),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Лидерборд', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(label: const Text('Месяц'), selected: !_leaderboardAllTime, onSelected: (_) => setState(() => _leaderboardAllTime = false)),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('Все времена'), selected: _leaderboardAllTime, onSelected: (_) => setState(() => _leaderboardAllTime = true)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: _nicknameController, decoration: const InputDecoration(labelText: 'Ник', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(onPressed: _submitLeaderboard, child: const Text('Отправить в лидерборд')),
          if (_statusText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_statusText)),
          const SizedBox(height: 8),
          FutureBuilder<List<LeaderboardEntry>>(
            future: _readLeaderboard(),
            builder: (context, snapshot) {
              final data = (snapshot.data ?? [])
                  .where((e) => _leaderboardAllTime ? e.name.contains('(ALL)') : !e.name.contains('(ALL)'))
                  .toList()
                ..sort((a, b) => b.kuo.compareTo(a.kuo));

              if (data.isEmpty) {
                return const Text('Пока пусто');
              }

              return Column(
                children: data.take(12).map((entry) {
                  return ListTile(
                    dense: true,
                    title: Text(entry.name),
                    subtitle: Text(entry.label),
                    trailing: Text(entry.kuo.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String value, String subtitle) {
    return Card(
      color: const Color(0xFF141026),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Card(
      color: const Color(0xFF141026),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
