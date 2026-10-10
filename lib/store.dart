import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppItem {
  String id, name, code;
  int updated;
  AppItem({required this.id, required this.name, required this.code, required this.updated});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'code': code, 'updated': updated};

  factory AppItem.fromJson(Map<String, dynamic> j) => AppItem(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        code: (j['code'] ?? '') as String,
        updated: ((j['updated'] ?? 0) as num).toInt(),
      );
}

class Store extends ChangeNotifier {
  late SharedPreferences _p;
  final Map<String, String> _keys = {};
  List<AppItem> apps = [];
  final Map<String, String> backups = {};
  final Map<String, List<String>> errors = {};
  String selectedId = '';

  static const keyNames = [
    'provider',
    'claude',
    'claudeModel',
    'gemini',
    'geminiModel',
    'sbUrl',
    'sbKey',
    'sbToken',
    'ghToken',
    'ghRepo',
  ];

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    for (final n in keyNames) {
      _keys[n] = _p.getString('k_$n') ?? '';
    }
    if (_keys['provider']!.isEmpty) _keys['provider'] = 'claude';
    final raw = _p.getString('apps');
    if (raw != null) {
      apps = (jsonDecode(raw) as List)
          .map((e) => AppItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (apps.isEmpty) {
      apps = [
        AppItem(id: 'a1', name: 'التطبيق الأول', code: _starter1, updated: 1),
        AppItem(id: 'a2', name: 'التطبيق الثاني', code: _starter2, updated: 1),
      ];
      _persist();
    }
    selectedId = apps.first.id;
  }

  String k(String n) => _keys[n] ?? '';

  String model(String provider) {
    final v = k(provider == 'claude' ? 'claudeModel' : 'geminiModel').trim();
    if (v.isNotEmpty) return v;
    return provider == 'claude' ? 'claude-sonnet-5-5' : 'gemini-2.5-flash';
  }

  void setKey(String n, String v, {bool notify = false}) {
    _keys[n] = v;
    _p.setString('k_$n', v);
    if (notify) notifyListeners();
  }

  AppItem? get selected {
    for (final a in apps) {
      if (a.id == selectedId) return a;
    }
    return apps.isEmpty ? null : apps.first;
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  String newId() => 'a${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  AppItem add(String name, String code) {
    final a = AppItem(
      id: newId(),
      name: name.trim().isEmpty ? 'تطبيق جديد' : name.trim(),
      code: code,
      updated: DateTime.now().millisecondsSinceEpoch,
    );
    apps.add(a);
    selectedId = a.id;
    _persist();
    notifyListeners();
    return a;
  }

  void update(String id, {String? name, String? code}) {
    final i = apps.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final a = apps[i];
    if (code != null && code != a.code) {
      backups[id] = a.code;
      a.code = code;
    }
    if (name != null && name.trim().isNotEmpty) a.name = name.trim();
    a.updated = DateTime.now().millisecondsSinceEpoch;
    _persist();
    notifyListeners();
  }

  bool undo(String id) {
    final b = backups[id];
    if (b == null) return false;
    final i = apps.indexWhere((a) => a.id == id);
    if (i < 0) return false;
    apps[i].code = b;
    apps[i].updated = DateTime.now().millisecondsSinceEpoch;
    backups.remove(id);
    _persist();
    notifyListeners();
    return true;
  }

  void remove(String id) {
    apps.removeWhere((a) => a.id == id);
    if (apps.isNotEmpty && selected == null) selectedId = apps.first.id;
    _persist();
    notifyListeners();
  }

  void saveApps() {
    _persist();
    notifyListeners();
  }

  void _persist() {
    _p.setString('apps', jsonEncode(apps.map((a) => a.toJson()).toList()));
  }
}

final store = Store();

const _starter1 = r'''<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>عدّاد</title>
<style>
  body{font-family:sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;margin:0;background:#eef2ff}
  h1{font-size:72px;margin:0}
  button{font-size:22px;padding:12px 28px;margin:8px;border:0;border-radius:12px;background:#4f46e5;color:#fff}
</style>
</head>
<body>
  <h1 id="n">0</h1>
  <div><button onclick="c(1)">+</button><button onclick="c(-1)">-</button></div>
  <script>
    let v = 0;
    function c(d){ v += d; document.getElementById('n').textContent = v; }
  </script>
</body>
</html>
''';

const _starter2 = r'''<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>مهامي</title>
<style>
  body{font-family:sans-serif;margin:0;padding:16px;background:#f0fdf4}
  input{width:70%;padding:10px;font-size:16px}
  button{padding:10px 16px;font-size:16px;border:0;border-radius:8px;background:#16a34a;color:#fff}
  li{background:#fff;margin:8px 0;padding:10px;border-radius:8px;list-style:none}
</style>
</head>
<body>
  <h2>مهامي</h2>
  <input id="t" placeholder="مهمة جديدة">
  <button onclick="add()">إضافة</button>
  <ul id="l"></ul>
  <script>
    function add(){
      const t = document.getElementById('t');
      if(!t.value.trim()) return;
      const li = document.createElement('li');
      li.textContent = t.value;
      li.onclick = () => li.remove();
      document.getElementById('l').appendChild(li);
      t.value = '';
    }
  </script>
</body>
</html>
''';
