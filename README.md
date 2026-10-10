# 🏭 مصنع التطبيقات | App Factory

تطبيق أندرويد (Flutter) يخليك تبني تطبيقات ويب كاملة من هاتفك: تكتب الكود أو تطلبه من **Claude** أو **Gemini**، تعاينه فورًا، ثم تبنيه إلى **APK** عبر **GitHub Actions** وتثبّته على الهاتف، وكل شيء متزامن مع **Supabase**.

> **App Factory** is an Android app (Flutter) that connects Claude, Gemini, Supabase and GitHub Actions: write or generate single-file HTML apps, preview them live, fix bugs with AI, then build and install an APK, all from your phone.

---

## ✨ المميزات

| القائمة | الوظيفة |
|---|---|
| 🔑 **المفاتيح** | Claude API، Gemini API، رابط ومفتاح Supabase، GitHub Token واسم مستودع البناء، واختيار المزوّد الافتراضي |
| 📱 **تطبيقاتي** | إدخال كود كل تطبيق (HTML/CSS/JS في ملف واحد)، زر تشغيل للمعاينة الفعلية، مزامنة مع Supabase |
| 🛠️ **التعديلات** | تكتب التعديل أو الخطأ، والذكاء الاصطناعي يعدّل الكود ويحفظه تلقائيًا، مع زر تراجع وإرفاق أخطاء المعاينة |
| 📦 **بناء APK** | يرفع الكود لمستودع GitHub ← يشغّل Actions ← ينزّل الـ APK ← يفتح شاشة التثبيت |

## 🧭 كيف يشتغل

```
تطبيقاتي (كود HTML)  ──►  التعديلات (Claude / Gemini)  ──►  الكود يتحدّث تلقائيًا
        │                                                         │
        └────────────── مزامنة Supabase (جدول factory_apps) ◄─────┘
        │
        ▼
بناء APK:  رفع apps/<id>/index.html ► GitHub Actions (Capacitor + Gradle) ► تنزيل APK ► تثبيت
```

## 🗂️ هيكل المشروع

```
app_factory/
├── lib/
│   ├── main.dart        # نقطة الدخول والتنقل السفلي
│   ├── store.dart       # الحالة والتخزين المحلي والتطبيقان الافتراضيان
│   ├── services.dart    # Supabase + Claude/Gemini + GitHub (رفع/بناء/تنزيل)
│   └── screens.dart     # الشاشات الأربع والمعاينة
├── .github/workflows/
│   └── build_factory.yml   # يبني تطبيق المصنع نفسه (APK)
├── pubspec.yaml
└── README.md
```

> مجلد `android/` يُولَّد تلقائيًا داخل الـ workflow عبر `flutter create`، فما محتاج ترفعه.

## 🚀 الإعداد خطوة بخطوة

### 1) مستودع المصنع
1. أنشئ مستودع GitHub جديد وارفع كل ملفات المشروع على الفرع `main`.
2. أول `push` يشغّل **Build Factory APK** تلقائيًا.
3. من تبويب **Actions** ← آخر تشغيل ← **Artifacts** ← حمّل `factory-apk` وثبّته على هاتفك.

### 2) مستودع بناء التطبيقات
1. أنشئ مستودعًا ثانيًا فاضيًا (فعّل "Add a README")، مثلًا `username/apk-builder`.
2. أنشئ **GitHub Token**:
   - Classic: صلاحيات `repo` و`workflow`.
   - Fine-grained: صلاحيات `Contents` و`Actions` و`Workflows` بمستوى Read & Write على هذا المستودع.

### 3) Supabase
1. أنشئ مشروعًا واحصل على **Project URL** و**anon public key** (Settings ← API).
2. أنشئ **Access Token** من `supabase.com/dashboard/account/tokens` (يبدأ بـ `sbp_`).
3. في التطبيق اضغط **"إعداد قاعدة البيانات تلقائيًا"**: ينشئ الجدول والصلاحيات بدون SQL Editor.

> رابط المشروع ومفتاح الـ API وحدهم ما بيقدروا ينشئوا جداول (قيد أمني من Supabase)، ولهذا نحتاج الـ Access Token مرة واحدة. بعد الإعداد امسحه من التطبيق وألغِه من حسابك.

### 4) مفاتيح الذكاء الاصطناعي
- **Claude**: مفتاح من [console.anthropic.com](https://console.anthropic.com).
- **Gemini**: مفتاح من [aistudio.google.com](https://aistudio.google.com).

ثم افتح التطبيق ← **المفاتيح** وأدخل كل القيم.

## 📖 الاستخدام

1. **تطبيقاتي** ← افتح التطبيق الأول أو الثاني (أو أضف جديدًا) ← الصق الكود ← ▶ للمعاينة.
2. **التعديلات** ← اختر التطبيق والمزوّد ← اكتب الطلب، مثل: *"غيّر لون الأزرار للأخضر وأضف زر تصفير"* ← نفّذ.
3. **بناء APK** ← اختر التطبيق ← **ابنِ وثبّت**. البناء ياخد غالبًا ٣-٦ دقائق.

كل تطبيق يُبنى بمعرّف فريد (`com.factory.<id>`)، فتقدر تثبّت أكثر من تطبيق جنب بعض.

## 🧱 التقنيات

- **Flutter** (الواجهة)، `webview_flutter` (المعاينة)، `open_filex` (التثبيت)
- **Capacitor 6** داخل GitHub Actions (تغليف صفحة الويب كتطبيق أندرويد)
- **Supabase REST** (التزامن)، **Anthropic Messages API** و**Gemini generateContent** (التعديل بالذكاء الاصطناعي)

## 🔒 الأمان

- المفاتيح تُحفظ محليًا على الهاتف بدون تشفير إضافي، فلا تشارك نسخة الهاتف أو نسخه الاحتياطي.
- سياسة الجدول في Supabase مفتوحة (`using (true)`) لتسهيل التجربة. للاستخدام الجاد فعّل Supabase Auth وقيّد السياسة بالمستخدم.
- الـ Access Token لـ Supabase يعطي صلاحية كاملة على الحساب: استخدمه للإعداد فقط ثم ألغِه.
- الـ APK الناتج نسخة **debug** (موقّعة بمفتاح debug)، تصلح للتثبيت الشخصي وليس للنشر على المتجر.

## ⚠️ حدود حالية

- التطبيقات المبنية يجب أن تكون ملف HTML واحد (CSS وJS داخله).
- يحتاج الهاتف سماح "تثبيت من مصادر غير معروفة" لتطبيق المصنع في أول تثبيت.
- المشروع لم يُختبر بعد على جهاز فعلي؛ أي خطأ في أول بناء يُرسَل لإصلاحه.

## 🗺️ خارطة الطريق

- [ ] إنشاء تطبيق جديد من وصف نصي فقط
- [ ] توقيع APK بمفتاح release
- [ ] تشفير المفاتيح (`flutter_secure_storage`)
- [ ] تسجيل دخول Supabase وسياسات لكل مستخدم
- [ ] سجل نسخ لكل تطبيق بدل تراجع واحد

## 📄 الترخيص

MIT — استخدمه وعدّل عليه كما تشاء.
