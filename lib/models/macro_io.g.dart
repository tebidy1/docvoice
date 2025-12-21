// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macro_io.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetMacroCollection on Isar {
  IsarCollection<Macro> get macros => this.collection();
}

const MacroSchema = CollectionSchema(
  name: r'Macro',
  id: -2582945574721736876,
  properties: {
    r'aiInstruction': PropertySchema(
      id: 0,
      name: r'aiInstruction',
      type: IsarType.string,
    ),
    r'category': PropertySchema(
      id: 1,
      name: r'category',
      type: IsarType.string,
    ),
    r'content': PropertySchema(
      id: 2,
      name: r'content',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'isAiMacro': PropertySchema(
      id: 4,
      name: r'isAiMacro',
      type: IsarType.bool,
    ),
    r'isFavorite': PropertySchema(
      id: 5,
      name: r'isFavorite',
      type: IsarType.bool,
    ),
    r'lastUsed': PropertySchema(
      id: 6,
      name: r'lastUsed',
      type: IsarType.dateTime,
    ),
    r'trigger': PropertySchema(
      id: 7,
      name: r'trigger',
      type: IsarType.string,
    ),
    r'usageCount': PropertySchema(
      id: 8,
      name: r'usageCount',
      type: IsarType.long,
    )
  },
  estimateSize: _macroEstimateSize,
  serialize: _macroSerialize,
  deserialize: _macroDeserialize,
  deserializeProp: _macroDeserializeProp,
  idName: r'id',
  indexes: {
    r'trigger': IndexSchema(
      id: -9206707463460544926,
      name: r'trigger',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'trigger',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _macroGetId,
  getLinks: _macroGetLinks,
  attach: _macroAttach,
  version: '3.1.0+1',
);

int _macroEstimateSize(
  Macro object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.aiInstruction;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.category.length * 3;
  bytesCount += 3 + object.content.length * 3;
  bytesCount += 3 + object.trigger.length * 3;
  return bytesCount;
}

void _macroSerialize(
  Macro object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.aiInstruction);
  writer.writeString(offsets[1], object.category);
  writer.writeString(offsets[2], object.content);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeBool(offsets[4], object.isAiMacro);
  writer.writeBool(offsets[5], object.isFavorite);
  writer.writeDateTime(offsets[6], object.lastUsed);
  writer.writeString(offsets[7], object.trigger);
  writer.writeLong(offsets[8], object.usageCount);
}

Macro _macroDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Macro();
  object.aiInstruction = reader.readStringOrNull(offsets[0]);
  object.category = reader.readString(offsets[1]);
  object.content = reader.readString(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.id = id;
  object.isAiMacro = reader.readBool(offsets[4]);
  object.isFavorite = reader.readBool(offsets[5]);
  object.lastUsed = reader.readDateTimeOrNull(offsets[6]);
  object.trigger = reader.readString(offsets[7]);
  object.usageCount = reader.readLong(offsets[8]);
  return object;
}

P _macroDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _macroGetId(Macro object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _macroGetLinks(Macro object) {
  return [];
}

void _macroAttach(IsarCollection<dynamic> col, Id id, Macro object) {
  object.id = id;
}

extension MacroQueryWhereSort on QueryBuilder<Macro, Macro, QWhere> {
  QueryBuilder<Macro, Macro, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhere> anyTrigger() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'trigger'),
      );
    });
  }
}

extension MacroQueryWhere on QueryBuilder<Macro, Macro, QWhereClause> {
  QueryBuilder<Macro, Macro, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> triggerEqualTo(String trigger) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'trigger',
        value: [trigger],
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> triggerNotEqualTo(
      String trigger) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'trigger',
              lower: [],
              upper: [trigger],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'trigger',
              lower: [trigger],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'trigger',
              lower: [trigger],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'trigger',
              lower: [],
              upper: [trigger],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> triggerGreaterThan(
    String trigger, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'trigger',
        lower: [trigger],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> triggerLessThan(
    String trigger, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'trigger',
        lower: [],
        upper: [trigger],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> triggerBetween(
    String lowerTrigger,
    String upperTrigger, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'trigger',
        lower: [lowerTrigger],
        includeLower: includeLower,
        upper: [upperTrigger],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> triggerStartsWith(
      String TriggerPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'trigger',
        lower: [TriggerPrefix],
        upper: ['$TriggerPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> triggerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'trigger',
        value: [''],
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterWhereClause> triggerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'trigger',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'trigger',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'trigger',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'trigger',
              upper: [''],
            ));
      }
    });
  }
}

extension MacroQueryFilter on QueryBuilder<Macro, Macro, QFilterCondition> {
  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'aiInstruction',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'aiInstruction',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiInstruction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiInstruction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiInstruction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiInstruction',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiInstruction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiInstruction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiInstruction',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiInstruction',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiInstruction',
        value: '',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> aiInstructionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiInstruction',
        value: '',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'category',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'category',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'category',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'category',
        value: '',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'content',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'content',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'content',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'content',
        value: '',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'content',
        value: '',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> isAiMacroEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isAiMacro',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> isFavoriteEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isFavorite',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> lastUsedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastUsed',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> lastUsedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastUsed',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> lastUsedEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUsed',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> lastUsedGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUsed',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> lastUsedLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUsed',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> lastUsedBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUsed',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'trigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'trigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'trigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'trigger',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'trigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'trigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'trigger',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'trigger',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'trigger',
        value: '',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> triggerIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'trigger',
        value: '',
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> usageCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'usageCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> usageCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'usageCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> usageCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'usageCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Macro, Macro, QAfterFilterCondition> usageCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'usageCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension MacroQueryObject on QueryBuilder<Macro, Macro, QFilterCondition> {}

extension MacroQueryLinks on QueryBuilder<Macro, Macro, QFilterCondition> {}

extension MacroQuerySortBy on QueryBuilder<Macro, Macro, QSortBy> {
  QueryBuilder<Macro, Macro, QAfterSortBy> sortByAiInstruction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiInstruction', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByAiInstructionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiInstruction', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByIsAiMacro() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAiMacro', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByIsAiMacroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAiMacro', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByLastUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsed', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByLastUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsed', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByTrigger() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trigger', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByTriggerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trigger', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByUsageCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'usageCount', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> sortByUsageCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'usageCount', Sort.desc);
    });
  }
}

extension MacroQuerySortThenBy on QueryBuilder<Macro, Macro, QSortThenBy> {
  QueryBuilder<Macro, Macro, QAfterSortBy> thenByAiInstruction() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiInstruction', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByAiInstructionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiInstruction', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByContent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByContentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'content', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByIsAiMacro() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAiMacro', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByIsAiMacroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isAiMacro', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByLastUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsed', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByLastUsedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsed', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByTrigger() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trigger', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByTriggerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trigger', Sort.desc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByUsageCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'usageCount', Sort.asc);
    });
  }

  QueryBuilder<Macro, Macro, QAfterSortBy> thenByUsageCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'usageCount', Sort.desc);
    });
  }
}

extension MacroQueryWhereDistinct on QueryBuilder<Macro, Macro, QDistinct> {
  QueryBuilder<Macro, Macro, QDistinct> distinctByAiInstruction(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiInstruction',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Macro, Macro, QDistinct> distinctByCategory(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Macro, Macro, QDistinct> distinctByContent(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'content', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Macro, Macro, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Macro, Macro, QDistinct> distinctByIsAiMacro() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isAiMacro');
    });
  }

  QueryBuilder<Macro, Macro, QDistinct> distinctByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFavorite');
    });
  }

  QueryBuilder<Macro, Macro, QDistinct> distinctByLastUsed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUsed');
    });
  }

  QueryBuilder<Macro, Macro, QDistinct> distinctByTrigger(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trigger', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Macro, Macro, QDistinct> distinctByUsageCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'usageCount');
    });
  }
}

extension MacroQueryProperty on QueryBuilder<Macro, Macro, QQueryProperty> {
  QueryBuilder<Macro, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Macro, String?, QQueryOperations> aiInstructionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiInstruction');
    });
  }

  QueryBuilder<Macro, String, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<Macro, String, QQueryOperations> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'content');
    });
  }

  QueryBuilder<Macro, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Macro, bool, QQueryOperations> isAiMacroProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isAiMacro');
    });
  }

  QueryBuilder<Macro, bool, QQueryOperations> isFavoriteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFavorite');
    });
  }

  QueryBuilder<Macro, DateTime?, QQueryOperations> lastUsedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUsed');
    });
  }

  QueryBuilder<Macro, String, QQueryOperations> triggerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trigger');
    });
  }

  QueryBuilder<Macro, int, QQueryOperations> usageCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'usageCount');
    });
  }
}
