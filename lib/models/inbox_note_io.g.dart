// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_note_io.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetInboxNoteCollection on Isar {
  IsarCollection<InboxNote> get inboxNotes => this.collection();
}

const InboxNoteSchema = CollectionSchema(
  name: r'InboxNote',
  id: -5514384511939818714,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'patientName': PropertySchema(
      id: 1,
      name: r'patientName',
      type: IsarType.string,
    ),
    r'rawText': PropertySchema(
      id: 2,
      name: r'rawText',
      type: IsarType.string,
    ),
    r'status': PropertySchema(
      id: 3,
      name: r'status',
      type: IsarType.string,
      enumMap: _InboxNotestatusEnumValueMap,
    ),
    r'suggestedMacroId': PropertySchema(
      id: 4,
      name: r'suggestedMacroId',
      type: IsarType.long,
    ),
    r'summary': PropertySchema(
      id: 5,
      name: r'summary',
      type: IsarType.string,
    )
  },
  estimateSize: _inboxNoteEstimateSize,
  serialize: _inboxNoteSerialize,
  deserialize: _inboxNoteDeserialize,
  deserializeProp: _inboxNoteDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _inboxNoteGetId,
  getLinks: _inboxNoteGetLinks,
  attach: _inboxNoteAttach,
  version: '3.1.0+1',
);

int _inboxNoteEstimateSize(
  InboxNote object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.patientName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.rawText.length * 3;
  bytesCount += 3 + object.status.name.length * 3;
  {
    final value = object.summary;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _inboxNoteSerialize(
  InboxNote object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.patientName);
  writer.writeString(offsets[2], object.rawText);
  writer.writeString(offsets[3], object.status.name);
  writer.writeLong(offsets[4], object.suggestedMacroId);
  writer.writeString(offsets[5], object.summary);
}

InboxNote _inboxNoteDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = InboxNote();
  object.createdAt = reader.readDateTimeOrNull(offsets[0]);
  object.id = id;
  object.patientName = reader.readStringOrNull(offsets[1]);
  object.rawText = reader.readString(offsets[2]);
  object.status =
      _InboxNotestatusValueEnumMap[reader.readStringOrNull(offsets[3])] ??
          InboxStatus.pending;
  object.suggestedMacroId = reader.readLongOrNull(offsets[4]);
  object.summary = reader.readStringOrNull(offsets[5]);
  return object;
}

P _inboxNoteDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (_InboxNotestatusValueEnumMap[reader.readStringOrNull(offset)] ??
          InboxStatus.pending) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _InboxNotestatusEnumValueMap = {
  r'pending': r'pending',
  r'processed': r'processed',
  r'archived': r'archived',
};
const _InboxNotestatusValueEnumMap = {
  r'pending': InboxStatus.pending,
  r'processed': InboxStatus.processed,
  r'archived': InboxStatus.archived,
};

Id _inboxNoteGetId(InboxNote object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _inboxNoteGetLinks(InboxNote object) {
  return [];
}

void _inboxNoteAttach(IsarCollection<dynamic> col, Id id, InboxNote object) {
  object.id = id;
}

extension InboxNoteQueryWhereSort
    on QueryBuilder<InboxNote, InboxNote, QWhere> {
  QueryBuilder<InboxNote, InboxNote, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension InboxNoteQueryWhere
    on QueryBuilder<InboxNote, InboxNote, QWhereClause> {
  QueryBuilder<InboxNote, InboxNote, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<InboxNote, InboxNote, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterWhereClause> idBetween(
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
}

extension InboxNoteQueryFilter
    on QueryBuilder<InboxNote, InboxNote, QFilterCondition> {
  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> createdAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      createdAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdAt',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> createdAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime? value, {
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

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> createdAtLessThan(
    DateTime? value, {
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

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> createdAtBetween(
    DateTime? lower,
    DateTime? upper, {
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

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> idBetween(
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

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      patientNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'patientName',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      patientNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'patientName',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> patientNameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      patientNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> patientNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> patientNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'patientName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      patientNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> patientNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> patientNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> patientNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'patientName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      patientNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'patientName',
        value: '',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      patientNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'patientName',
        value: '',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rawText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rawText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> rawTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawText',
        value: '',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      rawTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rawText',
        value: '',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusEqualTo(
    InboxStatus value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusGreaterThan(
    InboxStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusLessThan(
    InboxStatus value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusBetween(
    InboxStatus lower,
    InboxStatus upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      suggestedMacroIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'suggestedMacroId',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      suggestedMacroIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'suggestedMacroId',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      suggestedMacroIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'suggestedMacroId',
        value: value,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      suggestedMacroIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'suggestedMacroId',
        value: value,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      suggestedMacroIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'suggestedMacroId',
        value: value,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      suggestedMacroIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'suggestedMacroId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'summary',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'summary',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'summary',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'summary',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'summary',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition> summaryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'summary',
        value: '',
      ));
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterFilterCondition>
      summaryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'summary',
        value: '',
      ));
    });
  }
}

extension InboxNoteQueryObject
    on QueryBuilder<InboxNote, InboxNote, QFilterCondition> {}

extension InboxNoteQueryLinks
    on QueryBuilder<InboxNote, InboxNote, QFilterCondition> {}

extension InboxNoteQuerySortBy on QueryBuilder<InboxNote, InboxNote, QSortBy> {
  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortByPatientName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientName', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortByPatientNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientName', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortByRawText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawText', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortByRawTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawText', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortBySuggestedMacroId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'suggestedMacroId', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy>
      sortBySuggestedMacroIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'suggestedMacroId', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortBySummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> sortBySummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }
}

extension InboxNoteQuerySortThenBy
    on QueryBuilder<InboxNote, InboxNote, QSortThenBy> {
  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByPatientName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientName', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByPatientNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientName', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByRawText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawText', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByRawTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawText', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenBySuggestedMacroId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'suggestedMacroId', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy>
      thenBySuggestedMacroIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'suggestedMacroId', Sort.desc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenBySummary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.asc);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QAfterSortBy> thenBySummaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'summary', Sort.desc);
    });
  }
}

extension InboxNoteQueryWhereDistinct
    on QueryBuilder<InboxNote, InboxNote, QDistinct> {
  QueryBuilder<InboxNote, InboxNote, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<InboxNote, InboxNote, QDistinct> distinctByPatientName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'patientName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QDistinct> distinctByRawText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<InboxNote, InboxNote, QDistinct> distinctBySuggestedMacroId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'suggestedMacroId');
    });
  }

  QueryBuilder<InboxNote, InboxNote, QDistinct> distinctBySummary(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'summary', caseSensitive: caseSensitive);
    });
  }
}

extension InboxNoteQueryProperty
    on QueryBuilder<InboxNote, InboxNote, QQueryProperty> {
  QueryBuilder<InboxNote, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<InboxNote, DateTime?, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<InboxNote, String?, QQueryOperations> patientNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'patientName');
    });
  }

  QueryBuilder<InboxNote, String, QQueryOperations> rawTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawText');
    });
  }

  QueryBuilder<InboxNote, InboxStatus, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<InboxNote, int?, QQueryOperations> suggestedMacroIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'suggestedMacroId');
    });
  }

  QueryBuilder<InboxNote, String?, QQueryOperations> summaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'summary');
    });
  }
}
