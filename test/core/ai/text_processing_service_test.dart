/// ============================================================
/// UNIT TESTS — TextProcessingService (Smart Copy)
/// ============================================================
/// Tests the critical Smart Copy algorithm to ensure:
///   1. Placeholder tokens (brackets) are removed CLEANLY
///   2. Valid clinical data on the SAME LINE is preserved
///   3. Blank separator lines are preserved (structural)
///   4. Multiple blank lines are collapsed to one
///   5. The old "delete entire line" bug does NOT regress
///
/// RUN: `flutter test test/core/ai/text_processing_service_test.dart`
/// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:soutnote/core/ai/text_processing_service.dart';

void main() {
  group('TextProcessingService.applySmartCopy', () {
    // ----------------------------------------------------------
    // THE CRITICAL REGRESSION TEST
    // Verifies the old "delete entire line" bug is FIXED.
    // ----------------------------------------------------------

    test(
      '🚨 CRITICAL: Preserves valid data on same line as placeholder',
      () {
        const input = 'Vitals: BP: 120/80 mmHg, HR: [Not Reported]';
        final result = TextProcessingService.applySmartCopy(input);

        // Must KEEP the BP reading
        expect(result, contains('120/80 mmHg'));
        expect(result, contains('BP:'));

        // Must REMOVE the [Not Reported] token
        expect(result, isNot(contains('[Not Reported]')));
        expect(result, isNot(contains('Not Reported')));
      },
    );

    test(
      '🚨 CRITICAL: Preserves valid data alongside [not specified] bracket',
      () {
        const input =
            '• Labs: HbA1c: 8.2%, Kidney Function: [Value not specified]';
        final result = TextProcessingService.applySmartCopy(input);

        expect(result, contains('8.2%'));
        expect(result, contains('HbA1c:'));
        expect(result, isNot(contains('[Value not specified]')));
      },
    );

    // ----------------------------------------------------------
    // LINES THAT SHOULD BE COMPLETELY REMOVED
    // (lines where the ENTIRE content is a placeholder)
    // ----------------------------------------------------------

    test(
      'Removes a line that is ONLY a placeholder',
      () {
        // After removing [Diagnosis not specified], only "• Diagnosis:" remains.
        // This is a label-only line (no clinical value) so the whole line is discarded.
        const input = '• Diagnosis: [Diagnosis not specified]';
        final result = TextProcessingService.applySmartCopy(input);

        expect(result.trim(), isEmpty);
        expect(result, isNot(contains('Diagnosis not specified')));
        expect(result, isNot(contains('[Diagnosis')));
      },
    );

    test(
      'Removes bare "Not Reported" only lines',
      () {
        const input = 'Chief Complaint: Not Reported';
        final result = TextProcessingService.applySmartCopy(input);

        expect(result, isNot(contains('Not Reported')));
      },
    );

    test(
      'Removes "[ Select ]" token from lines',
      () {
        const input = 'Modality: [ Select ]';
        final result = TextProcessingService.applySmartCopy(input);

        expect(result, isNot(contains('[ Select ]')));
        expect(result, isNot(contains('Select')));
      },
    );

    // ----------------------------------------------------------
    // MULTI-LINE NOTE TESTS
    // ----------------------------------------------------------

    test(
      'Full SOAP note: removes placeholders, keeps valid content',
      () {
        const input = '''
SOAP NOTE

SUBJECTIVE:
• Chief Complaint: Chest pain
• HPI: [History of Present Illness not specified]
• ROS: [Relevant Systems / Negatives]

OBJECTIVE:
• Vitals: BP: 130/85 mmHg | HR: [Value / bpm] | Temp: 37.1°C
• General Appearance: Alert and oriented

ASSESSMENT:
• Primary Diagnosis: [Dx]

PLAN:
• Pharmacotherapy: Aspirin 100mg daily
• Follow-up: 2 weeks
''';

        final result = TextProcessingService.applySmartCopy(input);

        // Valid data must survive
        expect(result, contains('Chest pain'));
        expect(result, contains('130/85 mmHg'));
        expect(result, contains('37.1°C'));
        expect(result, contains('Alert and oriented'));
        expect(result, contains('Aspirin 100mg daily'));
        expect(result, contains('2 weeks'));

        // ALL bracket placeholders must be removed — both missing-info
        // keywords AND unfilled template fields like [Dx], [Value / bpm]
        expect(result, isNot(contains('[History of Present Illness')));
        expect(result, isNot(contains('[Relevant Systems')));
        expect(result, isNot(contains('[Value / bpm]')));
        expect(result, isNot(contains('[Dx]')));
        expect(result, isNot(contains('[')));
        expect(result, isNot(contains(']')));

        // Headers must survive
        expect(result, contains('SUBJECTIVE:'));
        expect(result, contains('OBJECTIVE:'));
        expect(result, contains('PLAN:'));
      },
    );

    test(
      'Preserves blank separator lines for note structure',
      () {
        const input = 'SUBJECTIVE:\n• Complaint: Fever\n\nOBJECTIVE:\n• Vitals: Temp 38.5°C';
        final result = TextProcessingService.applySmartCopy(input);

        // There should still be blank separation between sections
        expect(result, contains('\n\n'));
      },
    );

    test(
      'Collapses excessive blank lines',
      () {
        const input = 'Line 1\n\n\n\n\nLine 2';
        final result = TextProcessingService.applySmartCopy(input);

        // Should not have 3+ consecutive newlines
        expect(result, isNot(contains('\n\n\n')));
      },
    );

    // ----------------------------------------------------------
    // EDGE CASES
    // ----------------------------------------------------------

    test('Returns empty string for empty input', () {
      expect(TextProcessingService.applySmartCopy(''), isEmpty);
    });

    test('Returns unchanged text when no placeholders exist', () {
      const input = 'Patient is a 45-year-old male with hypertension.';
      final result = TextProcessingService.applySmartCopy(input);
      expect(result, equals(input));
    });

    test('Handles text with ONLY placeholders gracefully', () {
      const input = '[Not Reported]\n[Value not specified]\n[ Select ]';
      final result = TextProcessingService.applySmartCopy(input);
      expect(result.trim(), isEmpty);
    });
  });

  // ----------------------------------------------------------
  // countPlaceholders tests
  // ----------------------------------------------------------
  group('TextProcessingService.countPlaceholders', () {
    test('Counts bracket placeholders correctly', () {
      // 3 distinct bracket tokens — each at a unique position.
      // Fixed: no double-counting even if a token matches multiple patterns.
      const input =
          'BP: [not specified], HR: [not provided], Temp: [select]';
      expect(TextProcessingService.countPlaceholders(input), equals(3));
    });

    test('Counts ALL bracket types, not only missing-info keywords', () {
      // [Dx], [Value / bpm], [Date] are template placeholders without
      // keywords like "not specified" — they must still be counted.
      const input = 'Diagnosis: [Dx], Vitals: HR [Value / bpm], Date: [Date]';
      expect(TextProcessingService.countPlaceholders(input), equals(3));
    });

    test('Counts bare Not Reported correctly', () {
      const input = 'Complaint: Not Reported\nHistory: Not Reported';
      expect(TextProcessingService.countPlaceholders(input), equals(2));
    });

    test('Returns 0 for clean text', () {
      const input = 'Patient has fever and cough.';
      expect(TextProcessingService.countPlaceholders(input), equals(0));
    });
  });

  // ----------------------------------------------------------
  // findPlaceholderAtCursor tests
  // ----------------------------------------------------------
  group('TextProcessingService.findPlaceholderAtCursor', () {
    test('Returns correct range when cursor is inside a bracket', () {
      const text = 'BP: [Value / mmHg] HR: 80';
      // Cursor at index 7 (inside "[Value / mmHg]", which starts at 4)
      final result = TextProcessingService.findPlaceholderAtCursor(text, 7);

      expect(result, isNotNull);
      expect(result!.start, equals(4));
      expect(result.end, equals(18));
    });

    test('Returns null when cursor is outside any placeholder', () {
      const text = 'Patient has fever. BP: [not specified]';
      final result = TextProcessingService.findPlaceholderAtCursor(text, 5);
      expect(result, isNull);
    });

    test('Returns null for empty text', () {
      final result = TextProcessingService.findPlaceholderAtCursor('', 0);
      expect(result, isNull);
    });
  });
}
