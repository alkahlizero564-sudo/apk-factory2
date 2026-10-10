import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'services.dart';
import 'store.dart';

void snack(BuildContext c, String m) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

/// ───────────── اختيار التطبيق ─────────────
class AppPicker extends StatelessWidget {
  const AppPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final sel = store.selected;
        return DropdownButtonFormField<String>(
          value: sel?.id,
          decoration: const InputDecoration(labelText: 'التطبيق', border: OutlineInputBorder()),
          items: [for (final a in store.apps) DropdownMenuItem(value: a.id, child: Text(a.name))],
          onChanged: (v) {
            if (v != null) store.select(v);
          },
        );
      },
    );
  }
}

/// ───────────── المفاتيح ─────────────
class KeyField extends StatefulWidget {
  final String name, label;
  final bool secret;
  final String hint;
  const KeyField(this.name, this.label, {super.key, this.secret = false, this.hint = ''});

  @override
  State<KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<KeyField> {
  late final TextEditingController c = TextEditingController(text: store.k(widget.name));
  late bool hide = widget.secret;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: hide,
        autocorrect: false,
        enableSuggestions: false,
        textDirection: TextDirection.ltr,
        onChanged: (v) => store.setKey(widget.name, v),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          border: const OutlineInputBorder(),
          suffixIcon: widget.secret
              ? IconButton(
                  icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => hide = !hide),
                )
              : null,
        ),
      ),
    );
  }
}

class KeysScreen extends StatelessWidget {
  const KeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المفاتيح')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('مزوّد الذكاء الاصطناعي للتعديلات', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: store,
            builder: (_, __) => SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'claude', label: Text('Claude')),
                ButtonSegment(value: 'gemini', label: Text('Gemini')),
              ],
              selected: {store.k('provider')},
              onSelectionChanged: (s) => store.setKey('provider', s.first, notify: true),
            ),
          ),
          const Divider(height: 32),
          const KeyField('claude', 'مفتاح Claude API', secret: true, hint: 'sk-ant-...'),
          const KeyField('claudeModel', 'موديل Claude (اختياري)', hint: 'claude-sonnet-5-5'),
          const KeyField('gemini', 'مفتاح Gemini API', secret: true, hint: 'AIza...'),
          const KeyField('geminiModel', 'موديل Gemini (اختياري)', hint: 'gemini-2.5-flash'),
          const Divider(height: 32),
          const KeyField('sbUrl', 'رابط Supabase', hint: 'https://xxxx.supabase.co'),
          const KeyField('sbKey', 'مفتاح Supabase (anon public)', secret: true),
          const KeyField('sbToken', 'Access Token لإعداد القاعدة تلقائيًا (sbp_...)', secret: true),
          const Text(
            'يُؤخذ مرة واحدة من supabase.com/dashboard/account/tokens. بعد الإعداد تقدر تحذفه من هنا وتلغيه من حسابك.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('إعداد قاعدة البيانات تلقائيًا'),
              onPressed: () async {
                try {
                  snack(context, await Supa.setup());
                } catch (e) {
                  snack(context, '$e');
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('نسخ SQL يدويًا'),
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: Supa.sql));
                    snack(context, 'تم النسخ');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text('مزامنة الآن'),
                  onPressed: () async {
                    try {
                      snack(context, await Supa.sync());
                    } catch (e) {
                      snack(context, '$e');
                    }
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const KeyField('ghToken', 'مفتاح GitHub (Token)', secret: true, hint: 'ghp_... / github_pat_...'),
          const KeyField('ghRepo', 'مستودع بناء الـ APK', hint: 'username/apk-builder'),
          const Text(
            'صلاحيات مفتاح GitHub: repo + workflow (Classic)، أو Contents و Actions و Workflows بصلاحية Read & Write (Fine-grained).',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// ───────────── تطبيقاتي ─────────────
class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيقاتي'),
        actions: [
          IconButton(
            tooltip: 'مزامنة Supabase',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              try {
                snack(context, await Supa.sync());
              } catch (e) {
                snack(context, '$e');
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CodePage())),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (_, __) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: store.apps.length,
          itemBuilder: (ctx, i) {
            final a = store.apps[i];
            return Card(
              child: ListTile(
                title: Text(a.name),
                subtitle: Text('${a.code.length} حرف'),
                onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => CodePage(app: a))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'تشغيل / معاينة',
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () =>
                          Navigator.push(ctx, MaterialPageRoute(builder: (_) => PreviewPage(app: a))),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: Text('حذف ${a.name}؟'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                              TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          store.remove(a.id);
                          Supa.removeQuiet(a.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// إدخال / تعديل الكود يدويًا
class CodePage extends StatefulWidget {
  final AppItem? app;
  const CodePage({super.key, this.app});

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  late final TextEditingController n = TextEditingController(text: widget.app?.name ?? '');
  late final TextEditingController c = TextEditingController(text: widget.app?.code ?? '');
  String? id;

  @override
  void initState() {
    super.initState();
    id = widget.app?.id;
  }

  @override
  void dispose() {
    n.dispose();
    c.dispose();
    super.dispose();
  }

  void save() {
    if (id == null) {
      id = store.add(n.text, c.text).id;
    } else {
      store.update(id!, name: n.text, code: c.text);
    }
    Supa.pushQuiet(id!);
    snack(context, 'تم الحفظ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app == null ? 'تطبيق جديد' : 'كود التطبيق'),
        actions: [
          IconButton(
            tooltip: 'معاينة',
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              save();
              final a = store.apps.firstWhere((x) => x.id == id);
              Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewPage(app: a)));
            },
          ),
          IconButton(tooltip: 'حفظ', icon: const Icon(Icons.save), onPressed: save),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: 'اسم التطبيق', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: c,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'الصق كود HTML/CSS/JS هنا (ملف واحد)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ───────────── المعاينة الفعلية ─────────────
class PreviewPage extends StatefulWidget {
  final AppItem app;
  const PreviewPage({super.key, required this.app});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  late final WebViewController ctl;

  static const _hook =
      '<script>window.onerror=function(m,s,l){FactoryErr.postMessage(m+" (سطر "+l+")");};'
      'window.addEventListener("unhandledrejection",function(e){FactoryErr.postMessage(String(e.reason));});</script>';

  @override
  void initState() {
    super.initState();
    store.errors[widget.app.id] = [];
    final code = widget.app.code;
    final html = code.contains('<head>') ? code.replaceFirst('<head>', '<head>$_hook') : '$_hook$code';
    ctl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FactoryErr', onMessageReceived: (m) {
        (store.errors[widget.app.id] ??= []).add(m.message);
        if (mounted) setState(() {});
      })
      ..loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    final errs = store.errors[widget.app.id] ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app.name),
        actions: [
          IconButton(
            tooltip: 'أخطاء المعاينة',
            icon: Badge(isLabelVisible: errs.isNotEmpty, label: Text('${errs.length}'), child: const Icon(Icons.bug_report)),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('أخطاء المعاينة'),
                content: SingleChildScrollView(
                  child: SelectableText(errs.isEmpty ? 'لا توجد أخطاء' : errs.join('\n')),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('إغلاق'))],
              ),
            ),
          ),
        ],
      ),
      body: WebViewWidget(controller: ctl),
    );
  }
}

/// ───────────── التعديلات بالذكاء الاصطناعي ─────────────
class EditScreen extends StatefulWidget {
  const EditScreen({super.key});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final c = TextEditingController();
  bool busy = false;
  bool withErrors = true;
  String log = '';

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final a = store.selected;
    if (a == null || c.text.trim().isEmpty) return;
    final provider = store.k('provider');
    setState(() {
      busy = true;
      log = 'جارٍ التعديل بواسطة ${provider == 'claude' ? 'Claude' : 'Gemini'}...';
    });
    try {
      final errs = withErrors ? (store.errors[a.id] ?? []).join('\n') : '';
      final out = await AI.edit(provider: provider, code: a.code, instruction: c.text.trim(), errors: errs);
      store.update(a.id, code: out);
      store.errors[a.id] = [];
      Supa.pushQuiet(a.id);
      c.clear();
      log = 'تم تعديل الكود وحفظه في تطبيقاتي ✔';
    } catch (e) {
      log = 'خطأ: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التعديلات وتصحيح الأخطاء')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppPicker(),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: store,
            builder: (_, __) => SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'claude', label: Text('Claude')),
                ButtonSegment(value: 'gemini', label: Text('Gemini')),
              ],
              selected: {store.k('provider')},
              onSelectionChanged: (s) => store.setKey('provider', s.first, notify: true),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'اكتب التعديل أو الخطأ',
              hintText: 'مثال: غيّر لون الأزرار للأخضر وأضف زر تصفير',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('أرفق أخطاء آخر معاينة'),
            value: withErrors,
            onChanged: (v) => setState(() => withErrors = v),
          ),
          FilledButton.icon(
            onPressed: busy ? null : send,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_fix_high),
            label: const Text('نفّذ التعديل'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('تراجع'),
                  onPressed: busy
                      ? null
                      : () {
                          final a = store.selected;
                          if (a == null) return;
                          final ok = store.undo(a.id);
                          if (ok) Supa.pushQuiet(a.id);
                          setState(() => log = ok ? 'تم التراجع عن آخر تعديل' : 'لا يوجد تعديل للتراجع عنه');
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('معاينة'),
                  onPressed: () {
                    final a = store.selected;
                    if (a == null) return;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PreviewPage(app: a)));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (log.isNotEmpty) SelectableText(log),
        ],
      ),
    );
  }
}

/// ───────────── بناء APK وتثبيته ─────────────
class BuildScreen extends StatefulWidget {
  const BuildScreen({super.key});

  @override
  State<BuildScreen> createState() => _BuildScreenState();
}

class _BuildScreenState extends State<BuildScreen> {
  final logs = <String>[];
  bool busy = false;
  String? apk;

  Future<void> run() async {
    final a = store.selected;
    if (a == null) return;
    setState(() {
      busy = true;
      logs.clear();
      apk = null;
    });
    try {
      final p = await GH.build(a, (m) {
        if (mounted) setState(() => logs.add(m));
      });
      apk = p;
      await OpenFilex.open(p, type: 'application/vnd.android.package-archive');
    } catch (e) {
      logs.add('❌ $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('بناء APK وتثبيته')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppPicker(),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : run,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.rocket_launch),
            label: const Text('ابنِ وثبّت'),
          ),
          if (apk != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.install_mobile),
              label: const Text('تثبيت مرة أخرى'),
              onPressed: () => OpenFilex.open(apk!, type: 'application/vnd.android.package-archive'),
            ),
          ],
          const SizedBox(height: 16),
          for (final l in logs)
            Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: SelectableText(l)),
          if (logs.isEmpty)
            const Text(
              'الخطوات: رفع الكود لمستودع GitHub ← تشغيل GitHub Actions ← تنزيل الـ APK ← التثبيت.\n'
              'لازم تسمح لتطبيق المصنع بتثبيت التطبيقات (مصادر غير معروفة) أول مرة.',
              style: TextStyle(fontSize: 13),
            ),
        ],
      ),
    );
  }
}
