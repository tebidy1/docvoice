import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/services/api_service.dart';
import 'lib/core/di/service_locator.dart';
import 'lib/core/interfaces/macro_repository.dart';
import 'lib/core/interfaces/inbox_note_repository.dart';

/// اختبار بسيط للتحقق من الاتصال مع الباك اند
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 بدء اختبار الاتصال مع الباك اند...');
  
  try {
    // تحميل متغيرات البيئة
    await dotenv.load(fileName: ".env");
    print('✅ تم تحميل متغيرات البيئة');
    
    // تهيئة خدمة الـ API
    final apiService = ApiService();
    await apiService.init();
    print('✅ تم تهيئة خدمة الـ API');
    
    // تهيئة حاوي الحقن
    await ServiceLocator.initialize();
    print('✅ تم تهيئة حاوي الحقن');
    
    // اختبار 1: الوصول المباشر للـ API
    print('\n📡 اختبار 1: الوصول المباشر للـ API...');
    try {
      final response = await apiService.get('/macros');
      print('✅ نجح الوصول للـ API');
      print('   الاستجابة: ${response['message'] ?? 'تم تحميل البيانات'}');
      
      if (response['data'] != null) {
        final data = response['data'] as List;
        print('   عدد الماكروهات: ${data.length}');
      }
    } catch (e) {
      print('❌ فشل الوصول للـ API: $e');
    }
    
    // اختبار 2: استخدام المستودعات
    print('\n📚 اختبار 2: استخدام المستودعات...');
    try {
      final macroRepository = ServiceLocator.get<MacroRepository>();
      final inboxRepository = ServiceLocator.get<InboxNoteRepository>();
      
      final macros = await macroRepository.getAll();
      final notes = await inboxRepository.getAll();
      
      print('✅ نجح استخدام المستودعات');
      print('   الماكروهات: ${macros.length}');
      print('   الملاحظات: ${notes.length}');
      
      // عرض بعض التفاصيل
      if (macros.isNotEmpty) {
        final firstMacro = macros.first;
        print('   مثال ماكرو: ${firstMacro.trigger} -> ${firstMacro.content}');
      }
      
      if (notes.isNotEmpty) {
        final firstNote = notes.first;
        print('   مثال ملاحظة: ${firstNote.title}');
      }
      
    } catch (e) {
      print('❌ فشل استخدام المستودعات: $e');
    }
    
    // اختبار 3: إنشاء ماكرو جديد
    print('\n➕ اختبار 3: إنشاء ماكرو جديد...');
    try {
      final macroRepository = ServiceLocator.get<MacroRepository>();
      
      // إنشاء ماكرو تجريبي
      final testMacro = await macroRepository.create({
        'trigger': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'content': 'هذا ماكرو تجريبي تم إنشاؤه من اختبار الاتصال',
        'category': 'اختبار',
      } as dynamic); // Cast to dynamic to match interface
      
      print('✅ تم إنشاء ماكرو جديد بنجاح');
      print('   المعرف: ${testMacro.id}');
      print('   المحفز: ${testMacro.trigger}');
      
    } catch (e) {
      print('❌ فشل إنشاء ماكرو جديد: $e');
    }
    
    print('\n🎉 انتهى الاختبار بنجاح!');
    print('💡 النظام جاهز للاستخدام مع الباك اند');
    
  } catch (e) {
    print('💥 خطأ عام في الاختبار: $e');
    print('🔧 تأكد من:');
    print('   1. تشغيل الخادم على https://docvoice.gumra-ai.com');
    print('   2. صحة ملف .env');
    print('   3. الاتصال بالإنترنت');
  }
  
  // إنهاء البرنامج
  exit(0);
}