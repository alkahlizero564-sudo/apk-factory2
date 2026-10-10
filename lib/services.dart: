import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'store.dart';

/// ───────────── Supabase (عبر REST) ─────────────
class Supa {
  static const sql = '''create table if not exists factory_apps (
  id text primary key,
  name text,
  code text,
  updated bigint
);
alter table factory_apps enable row level security;
drop policy if exists "factory_all" on factory_apps;
create policy "factory_all" on factory_apps for all using (true) with check (true);
notify pgrst, 'reload schema';''';

  static String get _ref => (Uri.tryParse(store.k('sbUrl').trim())?.host ?? '').split('.').first;

  /// إنشاء الجدول والصلاحيات تلقائيًا عبر Supabase Management API
  static Future<String> setup() async {
    final t = store.k('sbToken').trim();
    if (t.isEmpty) throw 'أدخل Access Token من حساب Supabase أولًا';
    if (_ref.isEmpty) throw 'رابط Supabase غير صحيح';
    final r = await http.post(
      Uri.parse('https://api.supabase.com/v1/projects/$_ref/database/query'),
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
      body: jsonEncode({'query': sql}),
    );
    if (r.statusCode >= 300) throw 'Supabase setup ${r.statusCode}: ${utf8.decode(r.bodyBytes)}';
    return 'تم إنشاء الجدول والصلاحيات تلقائيًا ✔';
  }

  static String get _url {
    var u = store.k('sbUrl').trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  static bool get ready => store.k('sbUrl').trim().isNotEmpty && store.k('sbKey').trim().isNotEmpty;

  static Map<String, String> get _h {
    final k = store.k('sbKey').trim();
    return {'apikey': k, 'Authorization': 'Bearer $k', 'Content-Type': 'application/json'};
  }

  static void _check(http.Response r) {
    if (r.statusCode >= 300) throw 'Supabase ${r.statusCode}: ${utf8.decode(r.bodyBytes)}';
  }

  static Future<void> push(AppItem a) async {
    final r = await http.post(
      Uri.parse('$_url/rest/v1/factory_apps?on_conflict=id'),
      headers: {..._h, 'Prefer': 'resolution=merge-duplicates,return=minimal'},
      body: jsonEncode(a.toJson()),
    );
    _check(r);
  }

  static Future<List<AppItem>> pull() async {
    final r = await http.get(Uri.parse('$_url/rest/v1/factory_apps?select=*'), headers: _h);
    _check(r);
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return list.map((e) => AppItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static Future<void> remove(String id) async {
    final r = await http.delete(Uri.parse('$_url/rest/v1/factory_apps?id=eq.$id'), headers: _h);
    _check(r);
  }

  /// دفع صامت بعد كل تعديل (يتجاهل الأخطاء)
  static void pushQuiet(String id) {
    if (!ready) return;
    final i = store.apps.indexWhere((a) => a.id == id);
    if (i < 0) return;
    unawaited(push(store.apps[i]).catchError((_) {}));
  }

  static void removeQuiet(String id) {
    if (!ready) return;
    unawaited(remove(id).catchError((_) {}));
  }

  static Future<String> sync() async {
    if (!ready) throw 'أدخل رابط Supabase والمفتاح أولًا';
    List<AppItem> remote;
    try {
      remote = await pull();
    } catch (e) {
      final s = '$e';
      final missing = s.contains('404') || s.contains('PGRST205') || s.contains('42P01');
      if (missing && store.k('sbToken').trim().isNotEmpty) {
        await setup(); // الجدول غير موجود: أنشئه تلقائيًا ثم أعد المحاولة
        remote = await pull();
      } else {
        rethrow;
      }
    }
    final rm = {for (final r in remote) r.id: r};
    var down = 0, up = 0;
    for (final r in remote) {
      final i = store.apps.indexWhere((a) => a.id == r.id);
      if (i < 0) {
        store.apps.add(r);
        down++;
      } else if (r.updated > store.apps[i].updated) {
        store.apps[i] = r;
        down++;
      }
    }
    for (final a in List<AppItem>.from(store.apps)) {
      final r = rm[a.id];
      if (r == null || a.updated > r.updated) {
        await push(a);
        up++;
      }
    }
    store.saveApps();
    return 'تمت المزامنة: نزل $down وارتفع $up';
  }
}

/// ───────────── Claude + Gemini ─────────────
class AI {
  static const _system =
      'You are an expert web developer. You receive the full source of a single-file HTML app '
      '(inline CSS and JS, no external build step) and a request: either a change or a bug report. '
      'Return the COMPLETE updated file only, inside one ```html fenced block. '
      'No explanations before or after. Keep the app working offline and mobile friendly. '
      'If the current file is empty, create the app from the request.';

  static Future<String> edit({
    required String provider,
    required String code,
    required String instruction,
    String errors = '',
  }) async {
    final user = StringBuffer()
      ..writeln('Current file:')
      ..writeln('```html')
      ..writeln(code)
      ..writeln('```')
      ..writeln()
      ..writeln('Request:')
      ..writeln(instruction);
    if (errors.trim().isNotEmpty) {
      user
        ..writeln()
        ..writeln('Runtime errors seen in preview:')
        ..writeln(errors);
    }
    final text = provider == 'claude' ? await _claude(user.toString()) : await _gemini(user.toString());
    return _extract(text);
  }

  static Future<String> _claude(String user) async {
    final key = store.k('claude').trim();
    if (key.isEmpty) throw 'أدخل مفتاح Claude API في قائمة المفاتيح';
    final r = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': store.model('claude'),
            'max_tokens': 16000,
            'system': _system,
            'messages': [
              {'role': 'user', 'content': user}
            ],
          }),
        )
        .timeout(const Duration(minutes: 5));
    final body = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 300) throw 'Claude ${r.statusCode}: $body';
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();
  }

  static Future<String> _gemini(String user) async {
    final key = store.k('gemini').trim();
    if (key.isEmpty) throw 'أدخل مفتاح Gemini API في قائمة المفاتيح';
    final model = store.model('gemini');
    final r = await http
        .post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent'),
          headers: {'x-goog-api-key': key, 'content-type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _system}
              ]
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': user}
                ]
              }
            ],
          }),
        )
        .timeout(const Duration(minutes: 5));
    final body = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 300) throw 'Gemini ${r.statusCode}: $body';
    final data = jsonDecode(body) as Map<String, dynamic>;
    final cands = data['candidates'] as List?;
    if (cands == null || cands.isEmpty) throw 'Gemini لم يُرجع نتيجة: $body';
    final parts = cands[0]['content']['parts'] as List;
    return parts.map((p) => (p['text'] ?? '') as String).join();
  }

  static String _extract(String text) {
    final start = text.indexOf('```');
    if (start >= 0) {
      final nl = text.indexOf('\n', start);
      final end = text.lastIndexOf('```');
      if (nl >= 0 && end > nl) return text.substring(nl + 1, end).trim();
    }
    final t = text.trim();
    if (t.toLowerCase().contains('<html') || t.toLowerCase().contains('<!doctype')) return t;
    throw 'لم أجد كودًا في رد الذكاء الاصطناعي';
  }
}

/// ───────────── GitHub: رفع الكود + بناء APK ─────────────
class GH {
  static String get _token => store.k('ghToken').trim();
  static String get _repo => store.k('ghRepo').trim();

  static Map<String, String> get _h => {
        'Authorization': 'Bearer $_token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  static Uri _u(String path, [Map<String, String>? q]) =>
      Uri.https('api.github.com', '/repos/$_repo$path', q);

  static void _check(http.Response r) {
    if (r.statusCode >= 300) throw 'GitHub ${r.statusCode}: ${utf8.decode(r.bodyBytes)}';
  }

  static const workflowYaml = r'''name: Build APK
on:
  workflow_dispatch:
    inputs:
      app_id:
        description: app id
        required: true
      app_name:
        description: app name
        required: true
jobs:
  build:
    runs-on: ubuntu-latest
    env:
      APP_ID: ${{ inputs.app_id }}
      APP_NAME: ${{ inputs.app_name }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - name: Prepare Capacitor project
        run: |
          mkdir -p www
          cp "apps/$APP_ID/index.html" www/index.html
          npm init -y
          npm i @capacitor/core@6 @capacitor/cli@6 @capacitor/android@6
          npx cap init "$APP_NAME" "com.factory.$APP_ID" --web-dir www
          npx cap add android
          npx cap sync android
      - name: Build debug APK
        working-directory: android
        run: |
          chmod +x gradlew
          ./gradlew assembleDebug
      - uses: actions/upload-artifact@v4
        with:
          name: apk-${{ inputs.app_id }}
          path: android/app/build/outputs/apk/debug/app-debug.apk
''';

  static Future<void> putFile(String path, String content, String message) async {
    String? sha;
    final g = await http.get(_u('/contents/$path'), headers: _h);
    if (g.statusCode == 200) {
      final j = jsonDecode(g.body) as Map<String, dynamic>;
      sha = j['sha'] as String?;
      final old = ((j['content'] ?? '') as String).replaceAll('\n', '');
      if (old == base64Encode(utf8.encode(content))) return; // لا تغيير
    }
    final r = await http.put(
      _u('/contents/$path'),
      headers: {..._h, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'content': base64Encode(utf8.encode(content)),
        if (sha != null) 'sha': sha,
      }),
    );
    _check(r);
  }

  static Future<String> build(AppItem a, void Function(String) log) async {
    if (_token.isEmpty || _repo.isEmpty) {
      throw 'أدخل مفتاح GitHub واسم المستودع (owner/repo) في قائمة المفاتيح';
    }
    if (a.code.trim().isEmpty) throw 'كود التطبيق فارغ';

    log('١) فحص المستودع...');
    final ri = await http.get(Uri.https('api.github.com', '/repos/$_repo'), headers: _h);
    _check(ri);
    final branch = ((jsonDecode(ri.body) as Map<String, dynamic>)['default_branch'] ?? 'main') as String;

    log('٢) رفع ملف البناء والكود...');
    await putFile('.github/workflows/build-apk.yml', workflowYaml, 'Add APK build workflow');
    await putFile('apps/${a.id}/index.html', a.code, 'Update ${a.name}');

    log('٣) تشغيل البناء...');
    final since = DateTime.now().toUtc().subtract(const Duration(seconds: 20));
    var dispatched = false;
    for (var i = 0; i < 6 && !dispatched; i++) {
      final r = await http.post(
        _u('/actions/workflows/build-apk.yml/dispatches'),
        headers: {..._h, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'ref': branch,
          'inputs': {'app_id': a.id, 'app_name': a.name},
        }),
      );
      if (r.statusCode == 204) {
        dispatched = true;
      } else if (i == 5) {
        _check(r);
        throw 'تعذر تشغيل البناء (${r.statusCode})';
      } else {
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    int? runId;
    for (var i = 0; i < 30 && runId == null; i++) {
      await Future.delayed(const Duration(seconds: 5));
      final r = await http.get(
        _u('/actions/workflows/build-apk.yml/runs', {'event': 'workflow_dispatch', 'per_page': '5'}),
        headers: _h,
      );
      _check(r);
      final runs = (jsonDecode(r.body) as Map<String, dynamic>)['workflow_runs'] as List;
      for (final run in runs) {
        if (DateTime.parse(run['created_at'] as String).isAfter(since)) {
          runId = run['id'] as int;
          break;
        }
      }
    }
    if (runId == null) throw 'لم يبدأ تشغيل البناء في GitHub. تأكد من صلاحية workflow للمفتاح.';

    log('٤) جارٍ البناء في GitHub (٣-٦ دقائق)...');
    var done = false;
    for (var i = 0; i < 120 && !done; i++) {
      await Future.delayed(const Duration(seconds: 10));
      final r = await http.get(_u('/actions/runs/$runId'), headers: _h);
      _check(r);
      final run = jsonDecode(r.body) as Map<String, dynamic>;
      if (run['status'] == 'completed') {
        done = true;
        if (run['conclusion'] != 'success') {
          throw 'فشل البناء. شوف السجل هنا: ${run['html_url']}';
        }
      }
    }
    if (!done) throw 'انتهت المهلة قبل اكتمال البناء';

    log('٥) تنزيل الـ APK...');
    final ar = await http.get(_u('/actions/runs/$runId/artifacts'), headers: _h);
    _check(ar);
    final arts = (jsonDecode(ar.body) as Map<String, dynamic>)['artifacts'] as List;
    final art = arts.firstWhere((x) => x['name'] == 'apk-${a.id}', orElse: () => null);
    if (art == null) throw 'لم أجد ملف الـ APK في نتيجة البناء';

    final req = http.Request('GET', Uri.parse(art['archive_download_url'] as String))
      ..followRedirects = false
      ..headers.addAll(_h);
    final res = await req.send();
    final loc = res.headers['location'];
    await res.stream.drain<void>();
    if (loc == null) throw 'تعذر الحصول على رابط التنزيل (${res.statusCode})';
    final zip = await http.get(Uri.parse(loc));
    if (zip.statusCode >= 300) throw 'فشل تنزيل الـ APK (${zip.statusCode})';

    final arc = ZipDecoder().decodeBytes(zip.bodyBytes);
    final f = arc.files.firstWhere((x) => x.isFile && x.name.endsWith('.apk'));
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/${a.id}.apk');
    await out.writeAsBytes(f.content as List<int>);
    log('✔ تم التنزيل. جارٍ فتح شاشة التثبيت...');
    return out.path;
  }
}
