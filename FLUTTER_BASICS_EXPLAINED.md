# 📚 شرح كود Flutter الأساسي

## الملف: `lib/main.dart`

هذا هو أهم ملف في التطبيق - كل شيء يبدأ من هنا!

---

## 🔍 شرح السطور الأولى:

```dart
import 'package:flutter/material.dart';
```
**الترجمة:** استيراد مكتبة Material من Flutter
**الشرح:** هذه المكتبة تحتوي على عناصر واجهة المستخدم الجاهزة (أزرار، نصوص، إلخ)

---

```dart
void main() {
  runApp(const MyApp());
}
```
**الترجمة:** الدالة الرئيسية
**الشرح:** 
- `main()` = دالة البداية (تشغل التطبيق)
- `runApp()` = تشغيل تطبيق Flutter
- `MyApp()` = الودجت (عنصر واجهة) الرئيسي للتطبيق

---

## 🏗️ البناء الأساسي:

### 1️⃣ **MyApp** - جسم التطبيق
```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(...),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
```

**الشرح:**
- `StatelessWidget` = ودجت ثابت (لا يتغير)
- `build()` = الدالة التي ترسم الواجهة
- `MaterialApp` = غلاف التطبيق الأساسي
- `title` = عنوان التطبيق
- `theme` = الألوان والخطوط
- `home` = الشاشة الأولى

---

### 2️⃣ **MyHomePage** - الشاشة الرئيسية
```dart
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}
```

**الشرح:**
- `StatefulWidget` = ودجت يمكن أن يتغير (يحتوي على بيانات)
- `title` = متغير يحتفظ باسم الصفحة
- `createState()` = ينشئ الحالة (State) الخاصة بهذا الودجت

---

## 🔄 الفرق بين Stateless و Stateful:

### **StatelessWidget** (ثابت):
```dart
class GreetingCard extends StatelessWidget {
  const GreetingCard();
  
  @override
  Widget build(BuildContext context) {
    return Text("مرحباً!");  // لا يتغير أبداً
  }
}
```

### **StatefulWidget** (متغير):
```dart
class Counter extends StatefulWidget {
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int count = 0;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("$count"),
        FloatingActionButton(
          onPressed: () {
            setState(() {
              count++;  // تحديث البيانات
            });
          },
          child: Icon(Icons.add),
        ),
      ],
    );
  }
}
```

---

## 🚀 الآن: دعنا نشغل التطبيق!

في Terminal اكتب:

```bash
cd c:\Users\aa333\OneDrive\Desktop\project\trust_app
flutter run
```

سيظهر لك تطبيق بسيط فيه زر يعد الأرقام!

---

## 📝 المفاهيم المهمة:

- **Widget** = عنصر واجهة (زر، نص، صورة، إلخ)
- **State** = البيانات التي قد تتغير
- **build()** = الدالة التي ترسم الواجهة
- **setState()** = إخبار Flutter أن البيانات تغيرت وتحديث الواجهة

---

## التالي:

1. شغّل التطبيق الأساسي
2. دعني أشرح الآن كيفية بناء تطبيق Trust
3. سنعدّل هذا الكود تدريجياً
