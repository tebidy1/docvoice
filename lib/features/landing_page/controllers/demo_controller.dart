import 'package:flutter/material.dart';

enum DemoState {
  idle,
  recording,
  processing,
  templateSelection,
  transcriptionReady,
  generating,
  finished
}

class DemoController extends ChangeNotifier {
  DemoState _state = DemoState.idle;
  DemoState get state => _state;

  String _transcribedText = "";
  String get transcribedText => _transcribedText;

  String _formattedText = "";
  String get formattedText => _formattedText;

  String _selectedTemplate = "SOAP Note";
  String get selectedTemplate => _selectedTemplate;

  bool _demoCompleted = false;
  bool get demoCompleted => _demoCompleted;

  int _recordSeconds = 0;
  int get recordSeconds => _recordSeconds;

  void selectTemplate(String template) {
    _selectedTemplate = template;
    notifyListeners();
    // Auto-generate after selection
    generateNote();
  }

  // 1. Start Recording
  Future<void> startRecording() async {
    _state = DemoState.recording;
    _transcribedText = ""; // Clear previous
    _recordSeconds = 0;
    notifyListeners();
    _simulateTimer();
  }

  void _simulateTimer() async {
    while (_state == DemoState.recording) {
      await Future.delayed(const Duration(seconds: 1));
      if (_state == DemoState.recording) {
        _recordSeconds++;
        notifyListeners();
      }
    }
  }

  // 2. Stop Recording -> Processing -> Template Selection
  Future<void> stopRecording() async {
    _state = DemoState.processing;
    notifyListeners();

    // Simulate Transcription
    await Future.delayed(const Duration(seconds: 2));

    _transcribedText = "المريض ذكر، 33 سنة، يشكو من ألم في الظهر وضيق في التنفس مع تورم في الأطراف السفلية وحمى ليلية. لا يوجد حساسية معروفة.";
    _state = DemoState.templateSelection;
    notifyListeners();
  }

  // Bypass: Use Sample Text
  void useSampleText() {
    _transcribedText = "33-year-old patient with back pain and shortness of breath, associated lower limb edema and night fever. No known allergies.";
    _state = DemoState.templateSelection;
    notifyListeners();
  }



  // 3. Generate Formatted Note
  Future<void> generateNote() async {
    _state = DemoState.generating;
    notifyListeners();

    // Simulate AI Generation
    await Future.delayed(const Duration(seconds: 2));

    if (_selectedTemplate == "SOAP Note") {
      _formattedText = """
Subjective:
33-year-old male presents with back pain and shortness of breath.
Reports associated lower limb edema and night fever.
Allergies: NKDA.

Objective:
General: Alert and oriented.
Resp: Shortness of breath noted on exertion.
Extremities: Bilateral lower limb edema present.

Assessment:
1. Back Pain - Differential includes muscular strain vs discogenic.
2. Dyspnea with Edema - Rule out CHF or DVT/PE.
3. Fever of unknown origin.

Plan:
- Order CXR, D-Dimer, and CBC.
- Lower limb Doppler ultrasound.
- Symptomatic management for pain and fever.
""";
    } else if (_selectedTemplate == "Radiology Request") {
      _formattedText = """
Reason for Exam:
Back pain, dyspnea, and lower limb edema with fever.

Clinical History:
33yo male with acute onset symptoms. Rule out PE or DVT.

Requested Study:
CT Pulmonary Angiogram and Doppler US Lower Limbs.

Priority:
Urgent.
""";
    } else if (_selectedTemplate == "Progress Note") {
      _formattedText = """
Patient Status:
Patient reports persistent back pain and dyspnea.
New onset fever and leg swelling noted.

Physical Exam:
Lungs: Clear to auscultation but tachypneic.
Extremities: 2+ pitting edema bilateral.

Plan:
Workup for infectious vs thromboembolic etiology initiated.
Monitor vitals q4h.
""";
    } else {
       _formattedText = """
Discharge Summary (Short):
Diagnosis: Pyelonephritis (Presumed).
Course: Treated with IV antibiotics. Fever resolved.
Discharge Meds: Ciprofloxacin 500mg BID x 7 days.
Follow-up: PCP in 1 week.
""";
    }

    _state = DemoState.finished;
    
    // Mark as completed for gating logic
    if (!_demoCompleted) {
      _demoCompleted = true;
    }
    
    notifyListeners();
  }

  void reset() {
    _state = DemoState.idle;
    _transcribedText = "";
    _formattedText = "";
    _recordSeconds = 0;
    notifyListeners();
  }
}
