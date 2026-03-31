import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';
import '../interfaces/abstract_repository.dart';
import '../interfaces/macro_repository.dart';
import 'package:soutnote/core/models/macro.dart';

import '../../core/ai/ai_prompt_constants.dart';

/// Local storage implementation of MacroRepository
/// Uses Isar database for efficient querying and persistence
class LocalMacroRepository extends AbstractLocalRepository<Macro> implements MacroRepository {
  static Isar? _isarInstance;
  
  Future<Isar> get isar async {
    if (_isarInstance != null) return _isarInstance!;
    final dir = await getApplicationDocumentsDirectory();
    _isarInstance = await Isar.open(
      [MacroSchema],
      directory: dir.path,
    );
    return _isarInstance!;
  }
  final StreamController<List<Macro>> _watchController = StreamController<List<Macro>>.broadcast();
  bool _isInitialized = false;
  
  LocalMacroRepository({
    super.cacheManager,
    super.cacheStrategy,
  }) : super(storageKey: 'macros');

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await this.isar;
    await _seedDefaultMacrosIfNeeded();
    _isInitialized = true;
    
    // Start watching Isar and pipe to our controller
    final isar = await this.isar;
    isar.macros.where().watch(fireImmediately: true).listen((macros) {
      if (!_watchController.isClosed) {
        _watchController.add(macros);
      }
    });
  }

  Future<void> _seedDefaultMacrosIfNeeded() async {
    try {
      final isar = await this.isar;
      final count = await isar.macros.count();
      
      if (count == 0) {
        print("LocalMacroRepository: Seeding default macros...");
        await isar.writeTxn(() async {
          final defaults = [
            Macro()..trigger = "📝 Classic SOAP"..content = AIPromptConstants.templateClassicSoap..category = "General",
            Macro()..trigger = "🚨 ER SOAP"..content = AIPromptConstants.templateErSoap..category = "Emergency",
            Macro()..trigger = "📞 SBAR Consult"..content = AIPromptConstants.templateSbar..category = "Referral",
            Macro()..trigger = "📄 ER Discharge"..content = AIPromptConstants.templateDischarge..category = "Emergency",
            Macro()..trigger = "🤒 Sick Leave"..content = AIPromptConstants.templateSickLeave..category = "Admin",
          ];
          await isar.macros.putAll(defaults);
        });
      }
    } catch (e) {
      print("LocalMacroRepository: Error seeding macros: $e");
    }
  }

  @override
  String getEntityId(Macro entity) => entity.id.toString();

  @override
  Map<String, dynamic> toStorable(Macro entity) => entity.toJson();

  @override
  Macro fromStorable(Map<String, dynamic> data) => Macro.fromJson(data);

  // Storage operations - dummy implementation for AbstractLocalRepository compatibility
  @override
  Future<Map<String, dynamic>?> readFromStorage(String key) async => null;
  @override
  Future<void> writeToStorage(String key, Map<String, dynamic> data) async {}
  @override
  Future<void> deleteFromStorage(String key) async {}
  @override
  Future<List<String>> getAllStorageKeys() async => [];

  // Override all fetch/CRUD operations to use Isar directly
  
  @override
  Future<Macro?> fetchById(String id) async {
    final isar = await this.isar;
    final intId = int.tryParse(id);
    if (intId == null) return null;
    return await isar.macros.get(intId);
  }

  @override
  Future<List<Macro>> fetchAll() async {
    final isar = await this.isar;
    return await isar.macros.where().findAll();
  }

  @override
  Future<List<Macro>> fetchPaginated({required int offset, required int limit}) async {
    final isar = await this.isar;
    return await isar.macros.where().offset(offset).limit(limit).findAll();
  }

  @override
  Future<List<Macro>> searchEntities(String query) async {
    final isar = await this.isar;
    return await isar.macros
        .filter()
        .triggerContains(query, caseSensitive: false)
        .or()
        .contentContains(query, caseSensitive: false)
        .or()
        .categoryContains(query, caseSensitive: false)
        .findAll();
  }

  @override
  Future<Macro> createEntity(Macro entity) async {
    final isar = await this.isar;
    await isar.writeTxn(() async {
      await isar.macros.put(entity);
    });
    return entity;
  }

  @override
  Future<Macro> updateEntity(Macro entity) async {
    final isar = await this.isar;
    await isar.writeTxn(() async {
      await isar.macros.put(entity);
    });
    return entity;
  }

  @override
  Future<void> deleteEntity(String id) async {
    final isar = await this.isar;
    final intId = int.tryParse(id);
    if (intId != null) {
      await isar.writeTxn(() async {
        await isar.macros.delete(intId);
      });
    }
  }

  // MacroRepository specific implementations

  @override
  Future<List<Macro>> getByCategory(String category) async {
    final isar = await this.isar;
    return await isar.macros.filter().categoryEqualTo(category).findAll();
  }

  @override
  Future<List<Macro>> getFavorites() async {
    final isar = await this.isar;
    return await isar.macros.filter().isFavoriteEqualTo(true).findAll();
  }

  @override
  Future<List<Macro>> getMostUsed({int limit = 10}) async {
    final isar = await this.isar;
    return await isar.macros.where().sortByUsageCountDesc().limit(limit).findAll();
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final isar = await this.isar;
    final intId = int.tryParse(id);
    if (intId != null) {
      await isar.writeTxn(() async {
        final macro = await isar.macros.get(intId);
        if (macro != null) {
          macro.isFavorite = !macro.isFavorite;
          await isar.macros.put(macro);
        }
      });
    }
  }

  @override
  Future<void> incrementUsage(String id) async {
    final isar = await this.isar;
    final intId = int.tryParse(id);
    if (intId != null) {
      await isar.writeTxn(() async {
        final macro = await isar.macros.get(intId);
        if (macro != null) {
          macro.usageCount++;
          macro.lastUsed = DateTime.now();
          await isar.macros.put(macro);
        }
      });
    }
  }

  @override
  Future<List<String>> getCategories() async {
    final all = await fetchAll();
    return all.map((m) => m.category).toSet().toList()..sort();
  }

  @override
  Future<String?> findExpansion(String text) async {
    final all = await fetchAll();
    all.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
    final normalized = text.toLowerCase();
    for (final macro in all) {
      if (normalized.contains(macro.trigger.toLowerCase())) {
        await incrementUsage(macro.id.toString());
        return macro.content;
      }
    }
    return null;
  }

  @override
  Future<List<Macro>> searchByTrigger(String trigger) async {
    final isar = await this.isar;
    return await isar.macros.filter().triggerContains(trigger, caseSensitive: false).findAll();
  }

  @override
  Future<String> getMacrosAsJson() async {
    final all = await fetchAll();
    return jsonEncode(all.map((m) => {
      'id': m.id,
      'trigger': m.trigger,
      'content': m.content,
      'category': m.category,
    }).toList());
  }

  @override
  Future<void> sync() async {}

  @override
  Stream<List<Macro>> watch() => _watchController.stream;

  void dispose() {
    _watchController.close();
  }
}