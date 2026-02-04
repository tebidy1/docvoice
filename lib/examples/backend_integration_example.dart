import 'dart:io';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/macro.dart';
import '../models/inbox_note.dart';

/// مثال عملي لاستخدام النظام المتكامل مع الباك اند
class BackendIntegrationExample extends StatefulWidget {
  const BackendIntegrationExample({Key? key}) : super(key: key);

  @override
  State<BackendIntegrationExample> createState() => _BackendIntegrationExampleState();
}

class _BackendIntegrationExampleState extends State<BackendIntegrationExample> {
  late MacroRepository _macroRepository;
  late InboxNoteRepository _inboxNoteRepository;
  late AudioService _audioService;
  
  List<Macro> _macros = [];
  List<InboxNote> _inboxNotes = [];
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // تهيئة الخدمات
      await ServiceLocator.initialize();
      
      // الحصول على المستودعات والخدمات
      _macroRepository = ServiceLocator.get<MacroRepository>();
      _inboxNoteRepository = ServiceLocator.get<InboxNoteRepository>();
      _audioService = ServiceLocator.get<AudioService>();
      
      // تحميل البيانات الأولية
      await _loadData();
      
      setState(() {
        _statusMessage = 'تم تهيئة النظام بنجاح';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في التهيئة: $e';
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // تحميل الماكروهات
      final macros = await _macroRepository.getAll();
      
      // تحميل الملاحظات
      final notes = await _inboxNoteRepository.getAll();
      
      setState(() {
        _macros = macros;
        _inboxNotes = notes;
        _isLoading = false;
        _statusMessage = 'تم تحميل ${macros.length} ماكرو و ${notes.length} ملاحظة';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'خطأ في تحميل البيانات: $e';
      });
    }
  }

  Future<void> _createSampleMacro() async {
    try {
      final newMacro = Macro()
        ..trigger = 'bp'
        ..content = 'ضغط الدم طبيعي'
        ..category = 'طبي'
        ..createdAt = DateTime.now();

      final createdMacro = await _macroRepository.create(newMacro);
      
      setState(() {
        _macros.add(createdMacro);
        _statusMessage = 'تم إنشاء ماكرو جديد: ${createdMacro.trigger}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في إنشاء الماكرو: $e';
      });
    }
  }

  Future<void> _createSampleNote() async {
    try {
      final newNote = InboxNote()
        ..title = 'ملاحظة تجريبية'
        ..content = 'هذه ملاحظة تجريبية تم إنشاؤها من التطبيق'
        ..status = NoteStatus.draft
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      final createdNote = await _inboxNoteRepository.create(newNote);
      
      setState(() {
        _inboxNotes.add(createdNote);
        _statusMessage = 'تم إنشاء ملاحظة جديدة: ${createdNote.title}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'خطأ في إنشاء الملاحظة: $e';
      });
    }
  }

  Future<void> _testBackendConnectivity() async {
    setState(() {
      _statusMessage = 'اختبار الاتصال مع الباك اند...';
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      await apiService.init();
      
      // Test 1: Check if we can reach the API
      setState(() {
        _statusMessage = 'اختبار 1: فحص الوصول للـ API...';
      });
      
      // Try to get macros (this should work even without auth for testing)
      final macrosResponse = await apiService.get('/macros');
      
      setState(() {
        _statusMessage = 'اختبار 1 نجح: تم الوصول للـ API بنجاح\n'
                        'الاستجابة: ${macrosResponse['message'] ?? 'تم تحميل البيانات'}';
      });
      
      // Test 2: Try to get inbox notes
      setState(() {
        _statusMessage = 'اختبار 2: فحص ملاحظات الصندوق الوارد...';
      });
      
      final notesResponse = await apiService.get('/inbox-notes');
      
      setState(() {
        _statusMessage = 'اختبار 2 نجح: تم الوصول لملاحظات الصندوق الوارد\n'
                        'عدد الملاحظات: ${(notesResponse['data'] as List?)?.length ?? 0}';
      });
      
      // Test 3: Test repository integration
      setState(() {
        _statusMessage = 'اختبار 3: فحص تكامل المستودعات...';
      });
      
      final macros = await _macroRepository.getAll();
      final notes = await _inboxNoteRepository.getAll();
      
      setState(() {
        _statusMessage = 'جميع الاختبارات نجحت! ✅\n'
                        'الماكروهات: ${macros.length}\n'
                        'الملاحظات: ${notes.length}\n'
                        'الاتصال مع الباك اند يعمل بشكل صحيح';
        _macros = macros;
        _inboxNotes = notes;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _statusMessage = 'فشل في الاتصال مع الباك اند ❌\n'
                        'الخطأ: $e\n'
                        'تأكد من:\n'
                        '1. تشغيل الخادم على https://docvoice.gumra-ai.com\n'
                        '2. صحة إعدادات الشبكة\n'
                        '3. صحة رمز المصادقة';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مثال التكامل مع الباك اند'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رسالة الحالة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                _statusMessage.isEmpty ? 'جاري التهيئة...' : _statusMessage,
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // أزرار العمليات
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث البيانات'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createSampleMacro,
                  icon: const Icon(Icons.add),
                  label: const Text('إنشاء ماكرو'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createSampleNote,
                  icon: const Icon(Icons.note_add),
                  label: const Text('إنشاء ملاحظة'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testBackendConnectivity,
                  icon: const Icon(Icons.wifi),
                  label: const Text('اختبار الاتصال'),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // عرض البيانات
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'الماكروهات'),
                              Tab(text: 'الملاحظات'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // قائمة الماكروهات
                                _buildMacrosList(),
                                // قائمة الملاحظات
                                _buildNotesList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosList() {
    if (_macros.isEmpty) {
      return const Center(
        child: Text('لا توجد ماكروهات'),
      );
    }

    return ListView.builder(
      itemCount: _macros.length,
      itemBuilder: (context, index) {
        final macro = _macros[index];
        return Card(
          child: ListTile(
            title: Text(macro.trigger),
            subtitle: Text(macro.content),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(macro.category),
                if (macro.isFavorite)
                  const Icon(Icons.favorite, color: Colors.red, size: 16),
              ],
            ),
            onTap: () async {
              // تبديل المفضلة
              try {
                await _macroRepository.toggleFavorite(macro.id.toString());
                await _loadData(); // إعادة تحميل البيانات
              } catch (e) {
                setState(() {
                  _statusMessage = 'خطأ في تبديل المفضلة: $e';
                });
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildNotesList() {
    if (_inboxNotes.isEmpty) {
      return const Center(
        child: Text('لا توجد ملاحظات'),
      );
    }

    return ListView.builder(
      itemCount: _inboxNotes.length,
      itemBuilder: (context, index) {
        final note = _inboxNotes[index];
        return Card(
          child: ListTile(
            title: Text(note.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'الحالة: ${note.status.toString().split('.').last}',
                  style: TextStyle(
                    color: _getStatusColor(note.status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: Text(
              '${note.createdAt.day}/${note.createdAt.month}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(NoteStatus status) {
    switch (status) {
      case NoteStatus.draft:
        return Colors.orange;
      case NoteStatus.processed:
        return Colors.blue;
      case NoteStatus.ready:
        return Colors.green;
      case NoteStatus.archived:
        return Colors.grey;
    }
  }
}