import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

/// Property-based test runner
class PropertyTest {
  static const int defaultRuns = 100;
  
  /// Run property test with generated values
  static void property<T>(
    String description,
    Generator<T> generator,
    bool Function(T) property, {
    int runs = defaultRuns,
    int? seed,
  }) {
    test(description, () {
      final random = Random(seed);
      final failures = <T>[];
      
      for (int i = 0; i < runs; i++) {
        final value = generator.generate(random);
        
        try {
          final result = property(value);
          if (!result) {
            failures.add(value);
          }
        } catch (e) {
          failures.add(value);
          rethrow;
        }
      }
      
      if (failures.isNotEmpty) {
        fail('Property failed for values: ${failures.take(5).toList()}');
      }
    });
  }
  
  /// Run property test with two generators
  static void property2<T1, T2>(
    String description,
    Generator<T1> gen1,
    Generator<T2> gen2,
    bool Function(T1, T2) property, {
    int runs = defaultRuns,
    int? seed,
  }) {
    test(description, () {
      final random = Random(seed);
      final failures = <String>[];
      
      for (int i = 0; i < runs; i++) {
        final value1 = gen1.generate(random);
        final value2 = gen2.generate(random);
        
        try {
          final result = property(value1, value2);
          if (!result) {
            failures.add('($value1, $value2)');
          }
        } catch (e) {
          failures.add('($value1, $value2)');
          rethrow;
        }
      }
      
      if (failures.isNotEmpty) {
        fail('Property failed for values: ${failures.take(5).toList()}');
      }
    });
  }
}

/// Base generator interface
abstract class Generator<T> {
  T generate(Random random);
  
  /// Map generator to another type
  Generator<U> map<U>(U Function(T) mapper) {
    return MappedGenerator(this, mapper);
  }
  
  /// Filter generator values
  Generator<T> where(bool Function(T) predicate) {
    return FilteredGenerator(this, predicate);
  }
}

/// Mapped generator
class MappedGenerator<T, U> extends Generator<U> {
  final Generator<T> source;
  final U Function(T) mapper;
  
  MappedGenerator(this.source, this.mapper);
  
  @override
  U generate(Random random) {
    return mapper(source.generate(random));
  }
}

/// Filtered generator
class FilteredGenerator<T> extends Generator<T> {
  final Generator<T> source;
  final bool Function(T) predicate;
  final int maxAttempts;
  
  FilteredGenerator(this.source, this.predicate, {this.maxAttempts = 100});
  
  @override
  T generate(Random random) {
    for (int i = 0; i < maxAttempts; i++) {
      final value = source.generate(random);
      if (predicate(value)) {
        return value;
      }
    }
    throw StateError('Could not generate valid value after $maxAttempts attempts');
  }
}

/// Generators for common types
class Gen {
  /// Generate integers
  static Generator<int> integer({int min = -1000, int max = 1000}) {
    return IntGenerator(min, max);
  }
  
  /// Generate positive integers
  static Generator<int> positiveInt({int max = 1000}) {
    return IntGenerator(1, max);
  }
  
  /// Generate strings
  static Generator<String> string({int minLength = 0, int maxLength = 100}) {
    return StringGenerator(minLength, maxLength);
  }
  
  /// Generate non-empty strings
  static Generator<String> nonEmptyString({int maxLength = 100}) {
    return StringGenerator(1, maxLength);
  }
  
  /// Generate booleans
  static Generator<bool> boolean() {
    return BooleanGenerator();
  }
  
  /// Generate from list of values
  static Generator<T> oneOf<T>(List<T> values) {
    return OneOfGenerator(values);
  }
  
  /// Generate lists
  static Generator<List<T>> listOf<T>(Generator<T> elementGen, {int minLength = 0, int maxLength = 10}) {
    return ListGenerator(elementGen, minLength, maxLength);
  }
  
  /// Generate constant value
  static Generator<T> constant<T>(T value) {
    return ConstantGenerator(value);
  }
}

/// Integer generator
class IntGenerator extends Generator<int> {
  final int min;
  final int max;
  
  IntGenerator(this.min, this.max);
  
  @override
  int generate(Random random) {
    return min + random.nextInt(max - min + 1);
  }
}

/// String generator
class StringGenerator extends Generator<String> {
  final int minLength;
  final int maxLength;
  static const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
  
  StringGenerator(this.minLength, this.maxLength);
  
  @override
  String generate(Random random) {
    final length = minLength + random.nextInt(maxLength - minLength + 1);
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }
}

/// Boolean generator
class BooleanGenerator extends Generator<bool> {
  @override
  bool generate(Random random) {
    return random.nextBool();
  }
}

/// One-of generator
class OneOfGenerator<T> extends Generator<T> {
  final List<T> values;
  
  OneOfGenerator(this.values);
  
  @override
  T generate(Random random) {
    return values[random.nextInt(values.length)];
  }
}

/// List generator
class ListGenerator<T> extends Generator<List<T>> {
  final Generator<T> elementGenerator;
  final int minLength;
  final int maxLength;
  
  ListGenerator(this.elementGenerator, this.minLength, this.maxLength);
  
  @override
  List<T> generate(Random random) {
    final length = minLength + random.nextInt(maxLength - minLength + 1);
    return List.generate(length, (_) => elementGenerator.generate(random));
  }
}

/// Constant generator
class ConstantGenerator<T> extends Generator<T> {
  final T value;
  
  ConstantGenerator(this.value);
  
  @override
  T generate(Random random) {
    return value;
  }
}