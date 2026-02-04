import 'dart:math';
import 'property_test.dart';
import '../../models/macro.dart';
import '../../models/inbox_note.dart';
import '../../models/user.dart';

/// Domain-specific generators for ScribeFlow
class ScribeFlowGenerators {
  /// Generate Macro objects
  static Generator<Macro> macro() {
    return MacroGenerator();
  }
  
  /// Generate InboxNote objects
  static Generator<InboxNote> inboxNote() {
    return InboxNoteGenerator();
  }
  
  /// Generate User objects
  static Generator<User> user() {
    return UserGenerator();
  }
  
  /// Generate audio file metadata
  static Generator<Map<String, dynamic>> audioFileMetadata() {
    return AudioFileMetadataGenerator();
  }
  
  /// Generate WebSocket events
  static Generator<Map<String, dynamic>> webSocketEvent() {
    return WebSocketEventGenerator();
  }
  
  /// Generate settings data
  static Generator<Map<String, dynamic>> settingsData() {
    return SettingsDataGenerator();
  }
}

/// Macro generator
class MacroGenerator extends Generator<Macro> {
  @override
  Macro generate(Random random) {
    final macro = Macro();
    macro.id = random.nextInt(10000);
    macro.trigger = _generateTrigger(random);
    macro.content = _generateContent(random);
    macro.category = _generateCategory(random);
    macro.isFavorite = random.nextBool();
    macro.usageCount = random.nextInt(100);
    macro.isAiMacro = random.nextBool();
    macro.aiInstruction = random.nextBool() ? _generateAiInstruction(random) : null;
    macro.createdAt = _generateDateTime(random);
    macro.lastUsed = random.nextBool() ? _generateDateTime(random) : null;
    return macro;
  }
  
  String _generateTrigger(Random random) {
    final triggers = [
      'normal cardio',
      'chest pain',
      'shortness of breath',
      'blood pressure',
      'heart rate',
      'patient history',
      'physical exam',
      'diagnosis',
      'treatment plan',
      'follow up',
    ];
    return triggers[random.nextInt(triggers.length)];
  }
  
  String _generateContent(Random random) {
    final contents = [
      'Normal cardiovascular examination with regular rate and rhythm.',
      'Patient presents with chest pain, further evaluation needed.',
      'Blood pressure within normal limits.',
      'Recommend follow-up in 2 weeks.',
      'Patient education provided regarding medication compliance.',
    ];
    return contents[random.nextInt(contents.length)];
  }
  
  String _generateCategory(Random random) {
    final categories = ['Cardiology', 'General', 'Pediatrics', 'Surgery', 'Emergency'];
    return categories[random.nextInt(categories.length)];
  }
  
  String _generateAiInstruction(Random random) {
    final instructions = [
      'Format as SOAP note',
      'Include differential diagnosis',
      'Add treatment recommendations',
      'Format for discharge summary',
    ];
    return instructions[random.nextInt(instructions.length)];
  }
  
  DateTime _generateDateTime(Random random) {
    final now = DateTime.now();
    final daysAgo = random.nextInt(365);
    return now.subtract(Duration(days: daysAgo));
  }
}

/// InboxNote generator
class InboxNoteGenerator extends Generator<InboxNote> {
  @override
  InboxNote generate(Random random) {
    final note = InboxNote();
    note.id = random.nextInt(10000);
    note.uuid = _generateUuid(random);
    note.title = _generateTitle(random);
    note.content = _generateNoteContent(random);
    note.originalText = _generateOriginalText(random);
    note.formattedText = random.nextBool() ? _generateFormattedText(random) : '';
    note.summary = random.nextBool() ? _generateSummary(random) : null;
    note.audioPath = random.nextBool() ? _generateAudioPath(random) : null;
    note.status = _generateStatus(random);
    note.createdAt = _generateDateTime(random);
    note.updatedAt = _generateDateTime(random);
    note.appliedMacroId = random.nextBool() ? random.nextInt(100).toString() : null;
    note.suggestedMacroId = random.nextBool() ? random.nextInt(100) : null;
    return note;
  }
  
  String _generateUuid(Random random) {
    return '${random.nextInt(100000)}-${random.nextInt(100000)}-${random.nextInt(100000)}';
  }
  
  String _generateTitle(Random random) {
    final titles = [
      'Patient Consultation',
      'Follow-up Visit',
      'Emergency Assessment',
      'Routine Checkup',
      'Specialist Referral',
    ];
    return titles[random.nextInt(titles.length)];
  }
  
  String _generateNoteContent(Random random) {
    final contents = [
      'Patient presents with symptoms requiring evaluation.',
      'Routine examination completed with normal findings.',
      'Follow-up appointment scheduled for next week.',
      'Medication adjustment recommended based on response.',
    ];
    return contents[random.nextInt(contents.length)];
  }
  
  String _generateOriginalText(Random random) {
    final texts = [
      'Patient came in today complaining of chest pain',
      'Follow up visit for hypertension management',
      'Routine physical examination for annual checkup',
      'Emergency visit for shortness of breath',
    ];
    return texts[random.nextInt(texts.length)];
  }
  
  String _generateFormattedText(Random random) {
    return 'FORMATTED: ${_generateOriginalText(random)}';
  }
  
  String _generateSummary(Random random) {
    final summaries = [
      'Chest pain evaluation',
      'Hypertension follow-up',
      'Annual physical',
      'Emergency assessment',
    ];
    return summaries[random.nextInt(summaries.length)];
  }
  
  String _generateAudioPath(Random random) {
    return '/audio/recording_${random.nextInt(1000)}.m4a';
  }
  
  NoteStatus _generateStatus(Random random) {
    final statuses = NoteStatus.values;
    return statuses[random.nextInt(statuses.length)];
  }
  
  DateTime _generateDateTime(Random random) {
    final now = DateTime.now();
    final daysAgo = random.nextInt(30);
    return now.subtract(Duration(days: daysAgo));
  }
}

/// User generator
class UserGenerator extends Generator<User> {
  @override
  User generate(Random random) {
    return User(
      id: random.nextInt(10000),
      name: _generateName(random),
      email: _generateEmail(random),
      phone: random.nextBool() ? _generatePhone(random) : null,
      companyId: random.nextBool() ? random.nextInt(100) : null,
      companyName: random.nextBool() ? _generateCompanyName(random) : null,
      role: _generateRole(random),
      status: random.nextBool() ? _generateStatus(random) : null,
      isOnline: random.nextBool(),
      lastSeen: random.nextBool() ? _generateDateTime(random) : null,
      profileImageUrl: random.nextBool() ? _generateImageUrl(random) : null,
      createdAt: _generateDateTime(random),
      updatedAt: _generateDateTime(random),
    );
  }
  
  String _generateName(Random random) {
    final firstNames = ['John', 'Jane', 'Michael', 'Sarah', 'David', 'Emily'];
    final lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia'];
    return '${firstNames[random.nextInt(firstNames.length)]} ${lastNames[random.nextInt(lastNames.length)]}';
  }
  
  String _generateEmail(Random random) {
    final domains = ['example.com', 'test.com', 'demo.org'];
    final name = _generateName(random).toLowerCase().replaceAll(' ', '.');
    return '$name@${domains[random.nextInt(domains.length)]}';
  }
  
  String _generatePhone(Random random) {
    return '+1${random.nextInt(900) + 100}${random.nextInt(900) + 100}${random.nextInt(9000) + 1000}';
  }
  
  String _generateCompanyName(Random random) {
    final companies = ['Medical Center', 'Health Clinic', 'Hospital System', 'Care Group'];
    return companies[random.nextInt(companies.length)];
  }
  
  String _generateRole(Random random) {
    final roles = ['admin', 'company_manager', 'member'];
    return roles[random.nextInt(roles.length)];
  }
  
  String _generateStatus(Random random) {
    final statuses = ['active', 'inactive', 'pending'];
    return statuses[random.nextInt(statuses.length)];
  }
  
  String _generateImageUrl(Random random) {
    return 'https://example.com/avatar/${random.nextInt(1000)}.jpg';
  }
  
  DateTime _generateDateTime(Random random) {
    final now = DateTime.now();
    final daysAgo = random.nextInt(365);
    return now.subtract(Duration(days: daysAgo));
  }
}

/// Audio file metadata generator
class AudioFileMetadataGenerator extends Generator<Map<String, dynamic>> {
  @override
  Map<String, dynamic> generate(Random random) {
    final formats = ['mp3', 'wav', 'm4a', 'flac'];
    final format = formats[random.nextInt(formats.length)];
    
    return {
      'filename': 'recording_${random.nextInt(1000)}.$format',
      'format': format,
      'size': random.nextInt(10000000) + 1000, // 1KB to 10MB
      'duration': random.nextInt(600) + 10, // 10 seconds to 10 minutes
      'sample_rate': [8000, 16000, 44100, 48000][random.nextInt(4)],
      'channels': random.nextBool() ? 1 : 2,
      'bitrate': [64, 128, 192, 256, 320][random.nextInt(5)],
    };
  }
}

/// WebSocket event generator
class WebSocketEventGenerator extends Generator<Map<String, dynamic>> {
  @override
  Map<String, dynamic> generate(Random random) {
    final eventTypes = [
      'transcription_status',
      'note_created',
      'user_online',
      'user_offline',
      'notification',
    ];
    
    final channels = [
      'user.123',
      'transcription.456',
      'notifications',
      'presence',
    ];
    
    return {
      'type': eventTypes[random.nextInt(eventTypes.length)],
      'channel': channels[random.nextInt(channels.length)],
      'data': _generateEventData(random),
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': random.nextBool() ? random.nextInt(1000).toString() : null,
    };
  }
  
  Map<String, dynamic> _generateEventData(Random random) {
    return {
      'id': random.nextInt(10000),
      'message': 'Event data message ${random.nextInt(100)}',
      'status': ['pending', 'processing', 'completed'][random.nextInt(3)],
      'progress': random.nextDouble(),
    };
  }
}

/// Settings data generator
class SettingsDataGenerator extends Generator<Map<String, dynamic>> {
  @override
  Map<String, dynamic> generate(Random random) {
    return {
      'theme': ['light', 'dark', 'system'][random.nextInt(3)],
      'language': ['en', 'es', 'fr'][random.nextInt(3)],
      'auto_sync': random.nextBool(),
      'offline_mode': random.nextBool(),
      'notification_enabled': random.nextBool(),
      'audio_quality': ['low', 'medium', 'high'][random.nextInt(3)],
      'auto_transcribe': random.nextBool(),
      'sync_interval': random.nextInt(60) + 5, // 5-65 minutes
      'cache_size_mb': random.nextInt(500) + 50, // 50-550 MB
      'max_audio_length': random.nextInt(600) + 60, // 1-10 minutes
    };
  }
}