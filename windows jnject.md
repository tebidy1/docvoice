```md
نفذ في مشروع فلاتر نسخة ديسكتوب عند فتح الملاحظة اضف ذر حقن 
# Windows Desktop Automation Injection Prompt
# Label-Based Field Injection (Using Visible Text)
المرجع لحقول الحقن واليه الحقن هو الحقن موجود هنا عند فتح ملاحظة يوجد ذر حقن 
D:\docvoice\extension اعتبر المشروع مرجع 

أنت خبير Windows UI Automation و Desktop RPA Engineering.

المطلوب:
بناء نظام احترافي يقوم بالعثور على حقول الإدخال داخل تطبيق ويندوز خارجي اعتمادًا على النص الظاهر للمستخدم (Label / Visible Text)، ثم حقن القيم داخل الحقول المرتبطة بها.

يجب أن يعمل النظام مع:
- WinForms
- WPF
- بعض تطبيقات Electron
- التطبيقات التقليدية في ويندوز

---

# الهدف الرئيسي

عند وجود واجهة مثل:

اسم المستخدم: [________]
كلمة المرور: [________]

يقوم النظام بـ:

1. العثور على عنصر النص:
   "اسم المستخدم"

2. تحديد الحقل المرتبط به:
   TextBox / Edit Control

3. حقن القيمة المطلوبة داخل الحقل.

---

# متطلبات النظام

## 1. استخدام Windows UI Automation

استخدم:
- UIAutomationClient
- AutomationElement
- TreeWalker
- ControlType
- ValuePattern

ولا تعتمد فقط على SendKeys.

---

# 2. استراتيجية البحث المطلوبة

يجب تنفيذ Selector Engine ذكي يعمل كالتالي:

## المرحلة الأولى:
البحث عن Label بواسطة:

- NameProperty
- Visible Text
- Automation Name

مثال:

Name = "اسم المستخدم"

---

## المرحلة الثانية:
بعد العثور على الـ Label:

احصل على:
- Parent Element
- Sibling Elements
- Nearby Controls

---

## المرحلة الثالثة:
ابحث عن أقرب عنصر من النوع:

- Edit
- TextBox
- Document

ويكون:

- بجانب الـ Label
- أو على يمينه
- أو داخل نفس الـ Parent Container

---

# قواعد تحديد الحقل الصحيح

الأولوية تكون:

1. Same Parent
2. Right Of Label
3. Closest Distance
4. Matching TabIndex
5. Matching Layout Row

---

# يجب دعم الحالات التالية

## الحالة 1

اسم المستخدم: [textbox]

## الحالة 2

اسم المستخدم
[textbox]

## الحالة 3

| اسم المستخدم | [textbox] |

## الحالة 4

واجهة RTL عربية

---

# يجب دعم اللغة العربية بالكامل

النظام يجب أن:
- يدعم UTF-8
- يدعم RTL
- يقرأ النصوص العربية بشكل صحيح
- يحقن النص العربي بدون مشاكل encoding

---

# طرق الحقن المطلوبة

## الطريقة الأساسية

ValuePattern.SetValue()

---

## Fallback 1

SendMessage(WM_SETTEXT)

---

## Fallback 2

Keyboard Simulation

---

# المطلوب عند فشل العثور على العنصر

إذا لم يتم العثور على الحقل:

- اطبع Tree Structure
- اطبع جميع العناصر المجاورة
- اطبع:
  - Name
  - AutomationId
  - ControlType
  - ClassName
  - BoundingRectangle

---

# يجب بناء Selector Engine احترافي

مثال Selector:

{
  "label": "اسم المستخدم",
  "target_control": "Edit",
  "same_parent": true,
  "direction": "right",
  "max_distance": 300
}

---

# المطلوب دعم التطبيقات التالية

- WinForms
- WPF
- ERP Systems
- Legacy Desktop Apps

---

# المطلوب هندسيًا

بناء:

- UI Scanner
- Element Finder
- Relative Selector Engine
- Injection Engine
- Retry System
- Fallback Strategy

---

# المطلوب إضافة Logging كامل

يشمل:

- العناصر المكتشفة
- الحقول
- سبب الفشل
- نوع التطبيق
- Automation Tree

---

# المطلوب دعم التطبيقات التي لا تحتوي AutomationId

النظام يجب أن يعتمد بالكامل على:
- Label Detection
- Relative Positioning
- Tree Traversal

---

# المطلوب إنتاج كود Production-Ready

يكون:
- Modular
- Expandable
- Stable
- Fault Tolerant

---

# Stack المطلوب

Frontend:
- Flutter Desktop

Automation Layer:
- C#

Windows APIs:
- UI Automation
- Win32 API

---

# Architecture المطلوبة

Flutter UI
    ↓
Automation Service (C#)
    ↓
Selector Engine
    ↓
Windows UI Automation
    ↓
Target Application

---

# المطلوب النهائي

إنشاء نظام Desktop Automation احترافي شبيه بـ:
- UiPath
- Power Automate
- Automation Anywhere

لكن يعتمد أساسًا على:
Visible Label Injection Strategy
```
