// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LensesTable extends Lenses with TableInfo<$LensesTable, LensRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _showCountMeta = const VerificationMeta(
    'showCount',
  );
  @override
  late final GeneratedColumn<int> showCount = GeneratedColumn<int>(
    'show_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LensOrdering, int> ordering =
      GeneratedColumn<int>(
        'ordering',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<LensOrdering>($LensesTable.$converterordering);
  @override
  late final GeneratedColumnWithTypeConverter<LensSelection, int> selection =
      GeneratedColumn<int>(
        'selection',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<LensSelection>($LensesTable.$converterselection);
  @override
  late final GeneratedColumnWithTypeConverter<Recurrence?, String> period =
      GeneratedColumn<String>(
        'period',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Recurrence?>($LensesTable.$converterperiodn);
  static const VerificationMeta _dormantAfterMeta = const VerificationMeta(
    'dormantAfter',
  );
  @override
  late final GeneratedColumn<int> dormantAfter = GeneratedColumn<int>(
    'dormant_after',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    showCount,
    ordering,
    selection,
    period,
    dormantAfter,
    sortIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<LensRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('show_count')) {
      context.handle(
        _showCountMeta,
        showCount.isAcceptableOrUnknown(data['show_count']!, _showCountMeta),
      );
    }
    if (data.containsKey('dormant_after')) {
      context.handle(
        _dormantAfterMeta,
        dormantAfter.isAcceptableOrUnknown(
          data['dormant_after']!,
          _dormantAfterMeta,
        ),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LensRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LensRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      showCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}show_count'],
      )!,
      ordering: $LensesTable.$converterordering.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}ordering'],
        )!,
      ),
      selection: $LensesTable.$converterselection.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}selection'],
        )!,
      ),
      period: $LensesTable.$converterperiodn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}period'],
        ),
      ),
      dormantAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dormant_after'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $LensesTable createAlias(String alias) {
    return $LensesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LensOrdering, int, int> $converterordering =
      const EnumIndexConverter<LensOrdering>(LensOrdering.values);
  static JsonTypeConverter2<LensSelection, int, int> $converterselection =
      const EnumIndexConverter<LensSelection>(LensSelection.values);
  static TypeConverter<Recurrence, String> $converterperiod =
      const RecurrenceConverter();
  static TypeConverter<Recurrence?, String?> $converterperiodn =
      NullAwareTypeConverter.wrap($converterperiod);
}

class LensRow extends DataClass implements Insertable<LensRow> {
  final int id;
  final String name;
  final int showCount;
  final LensOrdering ordering;
  final LensSelection selection;
  final Recurrence? period;
  final int? dormantAfter;
  final int sortIndex;
  const LensRow({
    required this.id,
    required this.name,
    required this.showCount,
    required this.ordering,
    required this.selection,
    this.period,
    this.dormantAfter,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['show_count'] = Variable<int>(showCount);
    {
      map['ordering'] = Variable<int>(
        $LensesTable.$converterordering.toSql(ordering),
      );
    }
    {
      map['selection'] = Variable<int>(
        $LensesTable.$converterselection.toSql(selection),
      );
    }
    if (!nullToAbsent || period != null) {
      map['period'] = Variable<String>(
        $LensesTable.$converterperiodn.toSql(period),
      );
    }
    if (!nullToAbsent || dormantAfter != null) {
      map['dormant_after'] = Variable<int>(dormantAfter);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  LensesCompanion toCompanion(bool nullToAbsent) {
    return LensesCompanion(
      id: Value(id),
      name: Value(name),
      showCount: Value(showCount),
      ordering: Value(ordering),
      selection: Value(selection),
      period: period == null && nullToAbsent
          ? const Value.absent()
          : Value(period),
      dormantAfter: dormantAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(dormantAfter),
      sortIndex: Value(sortIndex),
    );
  }

  factory LensRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LensRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      showCount: serializer.fromJson<int>(json['showCount']),
      ordering: $LensesTable.$converterordering.fromJson(
        serializer.fromJson<int>(json['ordering']),
      ),
      selection: $LensesTable.$converterselection.fromJson(
        serializer.fromJson<int>(json['selection']),
      ),
      period: serializer.fromJson<Recurrence?>(json['period']),
      dormantAfter: serializer.fromJson<int?>(json['dormantAfter']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'showCount': serializer.toJson<int>(showCount),
      'ordering': serializer.toJson<int>(
        $LensesTable.$converterordering.toJson(ordering),
      ),
      'selection': serializer.toJson<int>(
        $LensesTable.$converterselection.toJson(selection),
      ),
      'period': serializer.toJson<Recurrence?>(period),
      'dormantAfter': serializer.toJson<int?>(dormantAfter),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  LensRow copyWith({
    int? id,
    String? name,
    int? showCount,
    LensOrdering? ordering,
    LensSelection? selection,
    Value<Recurrence?> period = const Value.absent(),
    Value<int?> dormantAfter = const Value.absent(),
    int? sortIndex,
  }) => LensRow(
    id: id ?? this.id,
    name: name ?? this.name,
    showCount: showCount ?? this.showCount,
    ordering: ordering ?? this.ordering,
    selection: selection ?? this.selection,
    period: period.present ? period.value : this.period,
    dormantAfter: dormantAfter.present ? dormantAfter.value : this.dormantAfter,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  LensRow copyWithCompanion(LensesCompanion data) {
    return LensRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      showCount: data.showCount.present ? data.showCount.value : this.showCount,
      ordering: data.ordering.present ? data.ordering.value : this.ordering,
      selection: data.selection.present ? data.selection.value : this.selection,
      period: data.period.present ? data.period.value : this.period,
      dormantAfter: data.dormantAfter.present
          ? data.dormantAfter.value
          : this.dormantAfter,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LensRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('showCount: $showCount, ')
          ..write('ordering: $ordering, ')
          ..write('selection: $selection, ')
          ..write('period: $period, ')
          ..write('dormantAfter: $dormantAfter, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    showCount,
    ordering,
    selection,
    period,
    dormantAfter,
    sortIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LensRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.showCount == this.showCount &&
          other.ordering == this.ordering &&
          other.selection == this.selection &&
          other.period == this.period &&
          other.dormantAfter == this.dormantAfter &&
          other.sortIndex == this.sortIndex);
}

class LensesCompanion extends UpdateCompanion<LensRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> showCount;
  final Value<LensOrdering> ordering;
  final Value<LensSelection> selection;
  final Value<Recurrence?> period;
  final Value<int?> dormantAfter;
  final Value<int> sortIndex;
  const LensesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.showCount = const Value.absent(),
    this.ordering = const Value.absent(),
    this.selection = const Value.absent(),
    this.period = const Value.absent(),
    this.dormantAfter = const Value.absent(),
    this.sortIndex = const Value.absent(),
  });
  LensesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.showCount = const Value.absent(),
    required LensOrdering ordering,
    required LensSelection selection,
    this.period = const Value.absent(),
    this.dormantAfter = const Value.absent(),
    this.sortIndex = const Value.absent(),
  }) : name = Value(name),
       ordering = Value(ordering),
       selection = Value(selection);
  static Insertable<LensRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? showCount,
    Expression<int>? ordering,
    Expression<int>? selection,
    Expression<String>? period,
    Expression<int>? dormantAfter,
    Expression<int>? sortIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (showCount != null) 'show_count': showCount,
      if (ordering != null) 'ordering': ordering,
      if (selection != null) 'selection': selection,
      if (period != null) 'period': period,
      if (dormantAfter != null) 'dormant_after': dormantAfter,
      if (sortIndex != null) 'sort_index': sortIndex,
    });
  }

  LensesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? showCount,
    Value<LensOrdering>? ordering,
    Value<LensSelection>? selection,
    Value<Recurrence?>? period,
    Value<int?>? dormantAfter,
    Value<int>? sortIndex,
  }) {
    return LensesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      showCount: showCount ?? this.showCount,
      ordering: ordering ?? this.ordering,
      selection: selection ?? this.selection,
      period: period ?? this.period,
      dormantAfter: dormantAfter ?? this.dormantAfter,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (showCount.present) {
      map['show_count'] = Variable<int>(showCount.value);
    }
    if (ordering.present) {
      map['ordering'] = Variable<int>(
        $LensesTable.$converterordering.toSql(ordering.value),
      );
    }
    if (selection.present) {
      map['selection'] = Variable<int>(
        $LensesTable.$converterselection.toSql(selection.value),
      );
    }
    if (period.present) {
      map['period'] = Variable<String>(
        $LensesTable.$converterperiodn.toSql(period.value),
      );
    }
    if (dormantAfter.present) {
      map['dormant_after'] = Variable<int>(dormantAfter.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LensesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('showCount: $showCount, ')
          ..write('ordering: $ordering, ')
          ..write('selection: $selection, ')
          ..write('period: $period, ')
          ..write('dormantAfter: $dormantAfter, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }
}

class $TemplatesTable extends Templates
    with TableInfo<$TemplatesTable, TemplateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Recurrence, String> recurrence =
      GeneratedColumn<String>(
        'recurrence',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Recurrence>($TemplatesTable.$converterrecurrence);
  @override
  late final GeneratedColumnWithTypeConverter<WindowRule, String> windowRule =
      GeneratedColumn<String>(
        'window_rule',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<WindowRule>($TemplatesTable.$converterwindowRule);
  static const VerificationMeta _pausedMeta = const VerificationMeta('paused');
  @override
  late final GeneratedColumn<bool> paused = GeneratedColumn<bool>(
    'paused',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paused" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _resumeOnMeta = const VerificationMeta(
    'resumeOn',
  );
  @override
  late final GeneratedColumn<DateTime> resumeOn = GeneratedColumn<DateTime>(
    'resume_on',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultLensIdMeta = const VerificationMeta(
    'defaultLensId',
  );
  @override
  late final GeneratedColumn<int> defaultLensId = GeneratedColumn<int>(
    'default_lens_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lenses (id) ON DELETE SET NULL',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    note,
    recurrence,
    windowRule,
    paused,
    resumeOn,
    createdAt,
    defaultLensId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TemplateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('paused')) {
      context.handle(
        _pausedMeta,
        paused.isAcceptableOrUnknown(data['paused']!, _pausedMeta),
      );
    }
    if (data.containsKey('resume_on')) {
      context.handle(
        _resumeOnMeta,
        resumeOn.isAcceptableOrUnknown(data['resume_on']!, _resumeOnMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('default_lens_id')) {
      context.handle(
        _defaultLensIdMeta,
        defaultLensId.isAcceptableOrUnknown(
          data['default_lens_id']!,
          _defaultLensIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TemplateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TemplateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      recurrence: $TemplatesTable.$converterrecurrence.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}recurrence'],
        )!,
      ),
      windowRule: $TemplatesTable.$converterwindowRule.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}window_rule'],
        )!,
      ),
      paused: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paused'],
      )!,
      resumeOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resume_on'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      defaultLensId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_lens_id'],
      ),
    );
  }

  @override
  $TemplatesTable createAlias(String alias) {
    return $TemplatesTable(attachedDatabase, alias);
  }

  static TypeConverter<Recurrence, String> $converterrecurrence =
      const RecurrenceConverter();
  static TypeConverter<WindowRule, String> $converterwindowRule =
      const WindowRuleConverter();
}

class TemplateRow extends DataClass implements Insertable<TemplateRow> {
  final int id;
  final String name;
  final String? note;
  final Recurrence recurrence;
  final WindowRule windowRule;
  final bool paused;
  final DateTime? resumeOn;
  final DateTime createdAt;

  /// The Lens generated instances join by default (§4.2 stamping). Set to null
  /// if its lens is deleted.
  final int? defaultLensId;
  const TemplateRow({
    required this.id,
    required this.name,
    this.note,
    required this.recurrence,
    required this.windowRule,
    required this.paused,
    this.resumeOn,
    required this.createdAt,
    this.defaultLensId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['recurrence'] = Variable<String>(
        $TemplatesTable.$converterrecurrence.toSql(recurrence),
      );
    }
    {
      map['window_rule'] = Variable<String>(
        $TemplatesTable.$converterwindowRule.toSql(windowRule),
      );
    }
    map['paused'] = Variable<bool>(paused);
    if (!nullToAbsent || resumeOn != null) {
      map['resume_on'] = Variable<DateTime>(resumeOn);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || defaultLensId != null) {
      map['default_lens_id'] = Variable<int>(defaultLensId);
    }
    return map;
  }

  TemplatesCompanion toCompanion(bool nullToAbsent) {
    return TemplatesCompanion(
      id: Value(id),
      name: Value(name),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recurrence: Value(recurrence),
      windowRule: Value(windowRule),
      paused: Value(paused),
      resumeOn: resumeOn == null && nullToAbsent
          ? const Value.absent()
          : Value(resumeOn),
      createdAt: Value(createdAt),
      defaultLensId: defaultLensId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultLensId),
    );
  }

  factory TemplateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TemplateRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      note: serializer.fromJson<String?>(json['note']),
      recurrence: serializer.fromJson<Recurrence>(json['recurrence']),
      windowRule: serializer.fromJson<WindowRule>(json['windowRule']),
      paused: serializer.fromJson<bool>(json['paused']),
      resumeOn: serializer.fromJson<DateTime?>(json['resumeOn']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      defaultLensId: serializer.fromJson<int?>(json['defaultLensId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'note': serializer.toJson<String?>(note),
      'recurrence': serializer.toJson<Recurrence>(recurrence),
      'windowRule': serializer.toJson<WindowRule>(windowRule),
      'paused': serializer.toJson<bool>(paused),
      'resumeOn': serializer.toJson<DateTime?>(resumeOn),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'defaultLensId': serializer.toJson<int?>(defaultLensId),
    };
  }

  TemplateRow copyWith({
    int? id,
    String? name,
    Value<String?> note = const Value.absent(),
    Recurrence? recurrence,
    WindowRule? windowRule,
    bool? paused,
    Value<DateTime?> resumeOn = const Value.absent(),
    DateTime? createdAt,
    Value<int?> defaultLensId = const Value.absent(),
  }) => TemplateRow(
    id: id ?? this.id,
    name: name ?? this.name,
    note: note.present ? note.value : this.note,
    recurrence: recurrence ?? this.recurrence,
    windowRule: windowRule ?? this.windowRule,
    paused: paused ?? this.paused,
    resumeOn: resumeOn.present ? resumeOn.value : this.resumeOn,
    createdAt: createdAt ?? this.createdAt,
    defaultLensId: defaultLensId.present
        ? defaultLensId.value
        : this.defaultLensId,
  );
  TemplateRow copyWithCompanion(TemplatesCompanion data) {
    return TemplateRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      note: data.note.present ? data.note.value : this.note,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      windowRule: data.windowRule.present
          ? data.windowRule.value
          : this.windowRule,
      paused: data.paused.present ? data.paused.value : this.paused,
      resumeOn: data.resumeOn.present ? data.resumeOn.value : this.resumeOn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      defaultLensId: data.defaultLensId.present
          ? data.defaultLensId.value
          : this.defaultLensId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TemplateRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('recurrence: $recurrence, ')
          ..write('windowRule: $windowRule, ')
          ..write('paused: $paused, ')
          ..write('resumeOn: $resumeOn, ')
          ..write('createdAt: $createdAt, ')
          ..write('defaultLensId: $defaultLensId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    note,
    recurrence,
    windowRule,
    paused,
    resumeOn,
    createdAt,
    defaultLensId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TemplateRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.note == this.note &&
          other.recurrence == this.recurrence &&
          other.windowRule == this.windowRule &&
          other.paused == this.paused &&
          other.resumeOn == this.resumeOn &&
          other.createdAt == this.createdAt &&
          other.defaultLensId == this.defaultLensId);
}

class TemplatesCompanion extends UpdateCompanion<TemplateRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> note;
  final Value<Recurrence> recurrence;
  final Value<WindowRule> windowRule;
  final Value<bool> paused;
  final Value<DateTime?> resumeOn;
  final Value<DateTime> createdAt;
  final Value<int?> defaultLensId;
  const TemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.note = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.windowRule = const Value.absent(),
    this.paused = const Value.absent(),
    this.resumeOn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.defaultLensId = const Value.absent(),
  });
  TemplatesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.note = const Value.absent(),
    required Recurrence recurrence,
    required WindowRule windowRule,
    this.paused = const Value.absent(),
    this.resumeOn = const Value.absent(),
    required DateTime createdAt,
    this.defaultLensId = const Value.absent(),
  }) : name = Value(name),
       recurrence = Value(recurrence),
       windowRule = Value(windowRule),
       createdAt = Value(createdAt);
  static Insertable<TemplateRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? note,
    Expression<String>? recurrence,
    Expression<String>? windowRule,
    Expression<bool>? paused,
    Expression<DateTime>? resumeOn,
    Expression<DateTime>? createdAt,
    Expression<int>? defaultLensId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (note != null) 'note': note,
      if (recurrence != null) 'recurrence': recurrence,
      if (windowRule != null) 'window_rule': windowRule,
      if (paused != null) 'paused': paused,
      if (resumeOn != null) 'resume_on': resumeOn,
      if (createdAt != null) 'created_at': createdAt,
      if (defaultLensId != null) 'default_lens_id': defaultLensId,
    });
  }

  TemplatesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? note,
    Value<Recurrence>? recurrence,
    Value<WindowRule>? windowRule,
    Value<bool>? paused,
    Value<DateTime?>? resumeOn,
    Value<DateTime>? createdAt,
    Value<int?>? defaultLensId,
  }) {
    return TemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      note: note ?? this.note,
      recurrence: recurrence ?? this.recurrence,
      windowRule: windowRule ?? this.windowRule,
      paused: paused ?? this.paused,
      resumeOn: resumeOn ?? this.resumeOn,
      createdAt: createdAt ?? this.createdAt,
      defaultLensId: defaultLensId ?? this.defaultLensId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(
        $TemplatesTable.$converterrecurrence.toSql(recurrence.value),
      );
    }
    if (windowRule.present) {
      map['window_rule'] = Variable<String>(
        $TemplatesTable.$converterwindowRule.toSql(windowRule.value),
      );
    }
    if (paused.present) {
      map['paused'] = Variable<bool>(paused.value);
    }
    if (resumeOn.present) {
      map['resume_on'] = Variable<DateTime>(resumeOn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (defaultLensId.present) {
      map['default_lens_id'] = Variable<int>(defaultLensId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('recurrence: $recurrence, ')
          ..write('windowRule: $windowRule, ')
          ..write('paused: $paused, ')
          ..write('resumeOn: $resumeOn, ')
          ..write('createdAt: $createdAt, ')
          ..write('defaultLensId: $defaultLensId')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<int> templateId = GeneratedColumn<int>(
    'template_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES templates (id)',
    ),
  );
  static const VerificationMeta _occurrenceMeta = const VerificationMeta(
    'occurrence',
  );
  @override
  late final GeneratedColumn<DateTime> occurrence = GeneratedColumn<DateTime>(
    'occurrence',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<TaskStatus>($TasksTable.$converterstatus);
  static const VerificationMeta _windowStartMeta = const VerificationMeta(
    'windowStart',
  );
  @override
  late final GeneratedColumn<DateTime> windowStart = GeneratedColumn<DateTime>(
    'window_start',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _windowEndMeta = const VerificationMeta(
    'windowEnd',
  );
  @override
  late final GeneratedColumn<DateTime> windowEnd = GeneratedColumn<DateTime>(
    'window_end',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    occurrence,
    name,
    note,
    status,
    windowStart,
    windowEnd,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    }
    if (data.containsKey('occurrence')) {
      context.handle(
        _occurrenceMeta,
        occurrence.isAcceptableOrUnknown(data['occurrence']!, _occurrenceMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('window_start')) {
      context.handle(
        _windowStartMeta,
        windowStart.isAcceptableOrUnknown(
          data['window_start']!,
          _windowStartMeta,
        ),
      );
    }
    if (data.containsKey('window_end')) {
      context.handle(
        _windowEndMeta,
        windowEnd.isAcceptableOrUnknown(data['window_end']!, _windowEndMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_id'],
      ),
      occurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurrence'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      status: $TasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      windowStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}window_start'],
      ),
      windowEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}window_end'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TaskStatus, int, int> $converterstatus =
      const EnumIndexConverter<TaskStatus>(TaskStatus.values);
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final int id;
  final int? templateId;
  final DateTime? occurrence;
  final String name;
  final String? note;
  final TaskStatus status;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const TaskRow({
    required this.id,
    this.templateId,
    this.occurrence,
    required this.name,
    this.note,
    required this.status,
    this.windowStart,
    this.windowEnd,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<int>(templateId);
    }
    if (!nullToAbsent || occurrence != null) {
      map['occurrence'] = Variable<DateTime>(occurrence);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['status'] = Variable<int>($TasksTable.$converterstatus.toSql(status));
    }
    if (!nullToAbsent || windowStart != null) {
      map['window_start'] = Variable<DateTime>(windowStart);
    }
    if (!nullToAbsent || windowEnd != null) {
      map['window_end'] = Variable<DateTime>(windowEnd);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      occurrence: occurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrence),
      name: Value(name),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      status: Value(status),
      windowStart: windowStart == null && nullToAbsent
          ? const Value.absent()
          : Value(windowStart),
      windowEnd: windowEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(windowEnd),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<int>(json['id']),
      templateId: serializer.fromJson<int?>(json['templateId']),
      occurrence: serializer.fromJson<DateTime?>(json['occurrence']),
      name: serializer.fromJson<String>(json['name']),
      note: serializer.fromJson<String?>(json['note']),
      status: $TasksTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      windowStart: serializer.fromJson<DateTime?>(json['windowStart']),
      windowEnd: serializer.fromJson<DateTime?>(json['windowEnd']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'templateId': serializer.toJson<int?>(templateId),
      'occurrence': serializer.toJson<DateTime?>(occurrence),
      'name': serializer.toJson<String>(name),
      'note': serializer.toJson<String?>(note),
      'status': serializer.toJson<int>(
        $TasksTable.$converterstatus.toJson(status),
      ),
      'windowStart': serializer.toJson<DateTime?>(windowStart),
      'windowEnd': serializer.toJson<DateTime?>(windowEnd),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  TaskRow copyWith({
    int? id,
    Value<int?> templateId = const Value.absent(),
    Value<DateTime?> occurrence = const Value.absent(),
    String? name,
    Value<String?> note = const Value.absent(),
    TaskStatus? status,
    Value<DateTime?> windowStart = const Value.absent(),
    Value<DateTime?> windowEnd = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => TaskRow(
    id: id ?? this.id,
    templateId: templateId.present ? templateId.value : this.templateId,
    occurrence: occurrence.present ? occurrence.value : this.occurrence,
    name: name ?? this.name,
    note: note.present ? note.value : this.note,
    status: status ?? this.status,
    windowStart: windowStart.present ? windowStart.value : this.windowStart,
    windowEnd: windowEnd.present ? windowEnd.value : this.windowEnd,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      occurrence: data.occurrence.present
          ? data.occurrence.value
          : this.occurrence,
      name: data.name.present ? data.name.value : this.name,
      note: data.note.present ? data.note.value : this.note,
      status: data.status.present ? data.status.value : this.status,
      windowStart: data.windowStart.present
          ? data.windowStart.value
          : this.windowStart,
      windowEnd: data.windowEnd.present ? data.windowEnd.value : this.windowEnd,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('occurrence: $occurrence, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('windowStart: $windowStart, ')
          ..write('windowEnd: $windowEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    occurrence,
    name,
    note,
    status,
    windowStart,
    windowEnd,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.occurrence == this.occurrence &&
          other.name == this.name &&
          other.note == this.note &&
          other.status == this.status &&
          other.windowStart == this.windowStart &&
          other.windowEnd == this.windowEnd &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<int> id;
  final Value<int?> templateId;
  final Value<DateTime?> occurrence;
  final Value<String> name;
  final Value<String?> note;
  final Value<TaskStatus> status;
  final Value<DateTime?> windowStart;
  final Value<DateTime?> windowEnd;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.occurrence = const Value.absent(),
    this.name = const Value.absent(),
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    this.windowStart = const Value.absent(),
    this.windowEnd = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  TasksCompanion.insert({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.occurrence = const Value.absent(),
    required String name,
    this.note = const Value.absent(),
    required TaskStatus status,
    this.windowStart = const Value.absent(),
    this.windowEnd = const Value.absent(),
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
  }) : name = Value(name),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<TaskRow> custom({
    Expression<int>? id,
    Expression<int>? templateId,
    Expression<DateTime>? occurrence,
    Expression<String>? name,
    Expression<String>? note,
    Expression<int>? status,
    Expression<DateTime>? windowStart,
    Expression<DateTime>? windowEnd,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (occurrence != null) 'occurrence': occurrence,
      if (name != null) 'name': name,
      if (note != null) 'note': note,
      if (status != null) 'status': status,
      if (windowStart != null) 'window_start': windowStart,
      if (windowEnd != null) 'window_end': windowEnd,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
    });
  }

  TasksCompanion copyWith({
    Value<int>? id,
    Value<int?>? templateId,
    Value<DateTime?>? occurrence,
    Value<String>? name,
    Value<String?>? note,
    Value<TaskStatus>? status,
    Value<DateTime?>? windowStart,
    Value<DateTime?>? windowEnd,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      occurrence: occurrence ?? this.occurrence,
      name: name ?? this.name,
      note: note ?? this.note,
      status: status ?? this.status,
      windowStart: windowStart ?? this.windowStart,
      windowEnd: windowEnd ?? this.windowEnd,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<int>(templateId.value);
    }
    if (occurrence.present) {
      map['occurrence'] = Variable<DateTime>(occurrence.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $TasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (windowStart.present) {
      map['window_start'] = Variable<DateTime>(windowStart.value);
    }
    if (windowEnd.present) {
      map['window_end'] = Variable<DateTime>(windowEnd.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('occurrence: $occurrence, ')
          ..write('name: $name, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('windowStart: $windowStart, ')
          ..write('windowEnd: $windowEnd, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }
}

class $ViewsTable extends Views with TableInfo<$ViewsTable, ViewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ViewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'views';
  @override
  VerificationContext validateIntegrity(
    Insertable<ViewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ViewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ViewRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
    );
  }

  @override
  $ViewsTable createAlias(String alias) {
    return $ViewsTable(attachedDatabase, alias);
  }
}

class ViewRow extends DataClass implements Insertable<ViewRow> {
  final int id;
  final String name;
  final int sortIndex;
  const ViewRow({
    required this.id,
    required this.name,
    required this.sortIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_index'] = Variable<int>(sortIndex);
    return map;
  }

  ViewsCompanion toCompanion(bool nullToAbsent) {
    return ViewsCompanion(
      id: Value(id),
      name: Value(name),
      sortIndex: Value(sortIndex),
    );
  }

  factory ViewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ViewRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortIndex': serializer.toJson<int>(sortIndex),
    };
  }

  ViewRow copyWith({int? id, String? name, int? sortIndex}) => ViewRow(
    id: id ?? this.id,
    name: name ?? this.name,
    sortIndex: sortIndex ?? this.sortIndex,
  );
  ViewRow copyWithCompanion(ViewsCompanion data) {
    return ViewRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ViewRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ViewRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortIndex == this.sortIndex);
}

class ViewsCompanion extends UpdateCompanion<ViewRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortIndex;
  const ViewsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortIndex = const Value.absent(),
  });
  ViewsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sortIndex = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ViewRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortIndex != null) 'sort_index': sortIndex,
    });
  }

  ViewsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortIndex,
  }) {
    return ViewsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ViewsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortIndex: $sortIndex')
          ..write(')'))
        .toString();
  }
}

class $TaskLensTable extends TaskLens
    with TableInfo<$TaskLensTable, TaskLensRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskLensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lensIdMeta = const VerificationMeta('lensId');
  @override
  late final GeneratedColumn<int> lensId = GeneratedColumn<int>(
    'lens_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lenses (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _surfacedAtMeta = const VerificationMeta(
    'surfacedAt',
  );
  @override
  late final GeneratedColumn<DateTime> surfacedAt = GeneratedColumn<DateTime>(
    'surfaced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _passedThisPeriodMeta = const VerificationMeta(
    'passedThisPeriod',
  );
  @override
  late final GeneratedColumn<bool> passedThisPeriod = GeneratedColumn<bool>(
    'passed_this_period',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("passed_this_period" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    taskId,
    lensId,
    sortOrder,
    surfacedAt,
    passedThisPeriod,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_lens';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskLensRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('lens_id')) {
      context.handle(
        _lensIdMeta,
        lensId.isAcceptableOrUnknown(data['lens_id']!, _lensIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lensIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('surfaced_at')) {
      context.handle(
        _surfacedAtMeta,
        surfacedAt.isAcceptableOrUnknown(data['surfaced_at']!, _surfacedAtMeta),
      );
    }
    if (data.containsKey('passed_this_period')) {
      context.handle(
        _passedThisPeriodMeta,
        passedThisPeriod.isAcceptableOrUnknown(
          data['passed_this_period']!,
          _passedThisPeriodMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, lensId};
  @override
  TaskLensRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskLensRow(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      lensId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lens_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      surfacedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}surfaced_at'],
      ),
      passedThisPeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}passed_this_period'],
      )!,
    );
  }

  @override
  $TaskLensTable createAlias(String alias) {
    return $TaskLensTable(attachedDatabase, alias);
  }
}

class TaskLensRow extends DataClass implements Insertable<TaskLensRow> {
  final int taskId;
  final int lensId;
  final int sortOrder;
  final DateTime? surfacedAt;
  final bool passedThisPeriod;
  const TaskLensRow({
    required this.taskId,
    required this.lensId,
    required this.sortOrder,
    this.surfacedAt,
    required this.passedThisPeriod,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<int>(taskId);
    map['lens_id'] = Variable<int>(lensId);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || surfacedAt != null) {
      map['surfaced_at'] = Variable<DateTime>(surfacedAt);
    }
    map['passed_this_period'] = Variable<bool>(passedThisPeriod);
    return map;
  }

  TaskLensCompanion toCompanion(bool nullToAbsent) {
    return TaskLensCompanion(
      taskId: Value(taskId),
      lensId: Value(lensId),
      sortOrder: Value(sortOrder),
      surfacedAt: surfacedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(surfacedAt),
      passedThisPeriod: Value(passedThisPeriod),
    );
  }

  factory TaskLensRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskLensRow(
      taskId: serializer.fromJson<int>(json['taskId']),
      lensId: serializer.fromJson<int>(json['lensId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      surfacedAt: serializer.fromJson<DateTime?>(json['surfacedAt']),
      passedThisPeriod: serializer.fromJson<bool>(json['passedThisPeriod']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<int>(taskId),
      'lensId': serializer.toJson<int>(lensId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'surfacedAt': serializer.toJson<DateTime?>(surfacedAt),
      'passedThisPeriod': serializer.toJson<bool>(passedThisPeriod),
    };
  }

  TaskLensRow copyWith({
    int? taskId,
    int? lensId,
    int? sortOrder,
    Value<DateTime?> surfacedAt = const Value.absent(),
    bool? passedThisPeriod,
  }) => TaskLensRow(
    taskId: taskId ?? this.taskId,
    lensId: lensId ?? this.lensId,
    sortOrder: sortOrder ?? this.sortOrder,
    surfacedAt: surfacedAt.present ? surfacedAt.value : this.surfacedAt,
    passedThisPeriod: passedThisPeriod ?? this.passedThisPeriod,
  );
  TaskLensRow copyWithCompanion(TaskLensCompanion data) {
    return TaskLensRow(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      lensId: data.lensId.present ? data.lensId.value : this.lensId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      surfacedAt: data.surfacedAt.present
          ? data.surfacedAt.value
          : this.surfacedAt,
      passedThisPeriod: data.passedThisPeriod.present
          ? data.passedThisPeriod.value
          : this.passedThisPeriod,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskLensRow(')
          ..write('taskId: $taskId, ')
          ..write('lensId: $lensId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('surfacedAt: $surfacedAt, ')
          ..write('passedThisPeriod: $passedThisPeriod')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(taskId, lensId, sortOrder, surfacedAt, passedThisPeriod);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskLensRow &&
          other.taskId == this.taskId &&
          other.lensId == this.lensId &&
          other.sortOrder == this.sortOrder &&
          other.surfacedAt == this.surfacedAt &&
          other.passedThisPeriod == this.passedThisPeriod);
}

class TaskLensCompanion extends UpdateCompanion<TaskLensRow> {
  final Value<int> taskId;
  final Value<int> lensId;
  final Value<int> sortOrder;
  final Value<DateTime?> surfacedAt;
  final Value<bool> passedThisPeriod;
  final Value<int> rowid;
  const TaskLensCompanion({
    this.taskId = const Value.absent(),
    this.lensId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.surfacedAt = const Value.absent(),
    this.passedThisPeriod = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskLensCompanion.insert({
    required int taskId,
    required int lensId,
    this.sortOrder = const Value.absent(),
    this.surfacedAt = const Value.absent(),
    this.passedThisPeriod = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       lensId = Value(lensId);
  static Insertable<TaskLensRow> custom({
    Expression<int>? taskId,
    Expression<int>? lensId,
    Expression<int>? sortOrder,
    Expression<DateTime>? surfacedAt,
    Expression<bool>? passedThisPeriod,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (lensId != null) 'lens_id': lensId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (surfacedAt != null) 'surfaced_at': surfacedAt,
      if (passedThisPeriod != null) 'passed_this_period': passedThisPeriod,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskLensCompanion copyWith({
    Value<int>? taskId,
    Value<int>? lensId,
    Value<int>? sortOrder,
    Value<DateTime?>? surfacedAt,
    Value<bool>? passedThisPeriod,
    Value<int>? rowid,
  }) {
    return TaskLensCompanion(
      taskId: taskId ?? this.taskId,
      lensId: lensId ?? this.lensId,
      sortOrder: sortOrder ?? this.sortOrder,
      surfacedAt: surfacedAt ?? this.surfacedAt,
      passedThisPeriod: passedThisPeriod ?? this.passedThisPeriod,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (lensId.present) {
      map['lens_id'] = Variable<int>(lensId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (surfacedAt.present) {
      map['surfaced_at'] = Variable<DateTime>(surfacedAt.value);
    }
    if (passedThisPeriod.present) {
      map['passed_this_period'] = Variable<bool>(passedThisPeriod.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskLensCompanion(')
          ..write('taskId: $taskId, ')
          ..write('lensId: $lensId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('surfacedAt: $surfacedAt, ')
          ..write('passedThisPeriod: $passedThisPeriod, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ViewLensTable extends ViewLens
    with TableInfo<$ViewLensTable, ViewLensRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ViewLensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _viewIdMeta = const VerificationMeta('viewId');
  @override
  late final GeneratedColumn<int> viewId = GeneratedColumn<int>(
    'view_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES views (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lensIdMeta = const VerificationMeta('lensId');
  @override
  late final GeneratedColumn<int> lensId = GeneratedColumn<int>(
    'lens_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lenses (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusFilterMeta = const VerificationMeta(
    'statusFilter',
  );
  @override
  late final GeneratedColumn<int> statusFilter = GeneratedColumn<int>(
    'status_filter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    viewId,
    lensId,
    sortOrder,
    statusFilter,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'view_lens';
  @override
  VerificationContext validateIntegrity(
    Insertable<ViewLensRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('view_id')) {
      context.handle(
        _viewIdMeta,
        viewId.isAcceptableOrUnknown(data['view_id']!, _viewIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viewIdMeta);
    }
    if (data.containsKey('lens_id')) {
      context.handle(
        _lensIdMeta,
        lensId.isAcceptableOrUnknown(data['lens_id']!, _lensIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lensIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('status_filter')) {
      context.handle(
        _statusFilterMeta,
        statusFilter.isAcceptableOrUnknown(
          data['status_filter']!,
          _statusFilterMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {viewId, lensId};
  @override
  ViewLensRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ViewLensRow(
      viewId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}view_id'],
      )!,
      lensId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lens_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      statusFilter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status_filter'],
      )!,
    );
  }

  @override
  $ViewLensTable createAlias(String alias) {
    return $ViewLensTable(attachedDatabase, alias);
  }
}

class ViewLensRow extends DataClass implements Insertable<ViewLensRow> {
  final int viewId;
  final int lensId;
  final int sortOrder;
  final int statusFilter;
  const ViewLensRow({
    required this.viewId,
    required this.lensId,
    required this.sortOrder,
    required this.statusFilter,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['view_id'] = Variable<int>(viewId);
    map['lens_id'] = Variable<int>(lensId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['status_filter'] = Variable<int>(statusFilter);
    return map;
  }

  ViewLensCompanion toCompanion(bool nullToAbsent) {
    return ViewLensCompanion(
      viewId: Value(viewId),
      lensId: Value(lensId),
      sortOrder: Value(sortOrder),
      statusFilter: Value(statusFilter),
    );
  }

  factory ViewLensRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ViewLensRow(
      viewId: serializer.fromJson<int>(json['viewId']),
      lensId: serializer.fromJson<int>(json['lensId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      statusFilter: serializer.fromJson<int>(json['statusFilter']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'viewId': serializer.toJson<int>(viewId),
      'lensId': serializer.toJson<int>(lensId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'statusFilter': serializer.toJson<int>(statusFilter),
    };
  }

  ViewLensRow copyWith({
    int? viewId,
    int? lensId,
    int? sortOrder,
    int? statusFilter,
  }) => ViewLensRow(
    viewId: viewId ?? this.viewId,
    lensId: lensId ?? this.lensId,
    sortOrder: sortOrder ?? this.sortOrder,
    statusFilter: statusFilter ?? this.statusFilter,
  );
  ViewLensRow copyWithCompanion(ViewLensCompanion data) {
    return ViewLensRow(
      viewId: data.viewId.present ? data.viewId.value : this.viewId,
      lensId: data.lensId.present ? data.lensId.value : this.lensId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      statusFilter: data.statusFilter.present
          ? data.statusFilter.value
          : this.statusFilter,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ViewLensRow(')
          ..write('viewId: $viewId, ')
          ..write('lensId: $lensId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('statusFilter: $statusFilter')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(viewId, lensId, sortOrder, statusFilter);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ViewLensRow &&
          other.viewId == this.viewId &&
          other.lensId == this.lensId &&
          other.sortOrder == this.sortOrder &&
          other.statusFilter == this.statusFilter);
}

class ViewLensCompanion extends UpdateCompanion<ViewLensRow> {
  final Value<int> viewId;
  final Value<int> lensId;
  final Value<int> sortOrder;
  final Value<int> statusFilter;
  final Value<int> rowid;
  const ViewLensCompanion({
    this.viewId = const Value.absent(),
    this.lensId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.statusFilter = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ViewLensCompanion.insert({
    required int viewId,
    required int lensId,
    this.sortOrder = const Value.absent(),
    this.statusFilter = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : viewId = Value(viewId),
       lensId = Value(lensId);
  static Insertable<ViewLensRow> custom({
    Expression<int>? viewId,
    Expression<int>? lensId,
    Expression<int>? sortOrder,
    Expression<int>? statusFilter,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (viewId != null) 'view_id': viewId,
      if (lensId != null) 'lens_id': lensId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (statusFilter != null) 'status_filter': statusFilter,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ViewLensCompanion copyWith({
    Value<int>? viewId,
    Value<int>? lensId,
    Value<int>? sortOrder,
    Value<int>? statusFilter,
    Value<int>? rowid,
  }) {
    return ViewLensCompanion(
      viewId: viewId ?? this.viewId,
      lensId: lensId ?? this.lensId,
      sortOrder: sortOrder ?? this.sortOrder,
      statusFilter: statusFilter ?? this.statusFilter,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (viewId.present) {
      map['view_id'] = Variable<int>(viewId.value);
    }
    if (lensId.present) {
      map['lens_id'] = Variable<int>(lensId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (statusFilter.present) {
      map['status_filter'] = Variable<int>(statusFilter.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ViewLensCompanion(')
          ..write('viewId: $viewId, ')
          ..write('lensId: $lensId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('statusFilter: $statusFilter, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VacationsTable extends Vacations
    with TableInfo<$VacationsTable, VacationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VacationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<DateTime> end = GeneratedColumn<DateTime>(
    'end',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, start, end];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vacations';
  @override
  VerificationContext validateIntegrity(
    Insertable<VacationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('end')) {
      context.handle(
        _endMeta,
        end.isAcceptableOrUnknown(data['end']!, _endMeta),
      );
    } else if (isInserting) {
      context.missing(_endMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VacationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VacationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start'],
      )!,
      end: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end'],
      )!,
    );
  }

  @override
  $VacationsTable createAlias(String alias) {
    return $VacationsTable(attachedDatabase, alias);
  }
}

class VacationRow extends DataClass implements Insertable<VacationRow> {
  final int id;
  final DateTime start;
  final DateTime end;
  const VacationRow({required this.id, required this.start, required this.end});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['start'] = Variable<DateTime>(start);
    map['end'] = Variable<DateTime>(end);
    return map;
  }

  VacationsCompanion toCompanion(bool nullToAbsent) {
    return VacationsCompanion(
      id: Value(id),
      start: Value(start),
      end: Value(end),
    );
  }

  factory VacationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VacationRow(
      id: serializer.fromJson<int>(json['id']),
      start: serializer.fromJson<DateTime>(json['start']),
      end: serializer.fromJson<DateTime>(json['end']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'start': serializer.toJson<DateTime>(start),
      'end': serializer.toJson<DateTime>(end),
    };
  }

  VacationRow copyWith({int? id, DateTime? start, DateTime? end}) =>
      VacationRow(
        id: id ?? this.id,
        start: start ?? this.start,
        end: end ?? this.end,
      );
  VacationRow copyWithCompanion(VacationsCompanion data) {
    return VacationRow(
      id: data.id.present ? data.id.value : this.id,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VacationRow(')
          ..write('id: $id, ')
          ..write('start: $start, ')
          ..write('end: $end')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, start, end);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VacationRow &&
          other.id == this.id &&
          other.start == this.start &&
          other.end == this.end);
}

class VacationsCompanion extends UpdateCompanion<VacationRow> {
  final Value<int> id;
  final Value<DateTime> start;
  final Value<DateTime> end;
  const VacationsCompanion({
    this.id = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
  });
  VacationsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime start,
    required DateTime end,
  }) : start = Value(start),
       end = Value(end);
  static Insertable<VacationRow> custom({
    Expression<int>? id,
    Expression<DateTime>? start,
    Expression<DateTime>? end,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    });
  }

  VacationsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? start,
    Value<DateTime>? end,
  }) {
    return VacationsCompanion(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<DateTime>(end.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VacationsCompanion(')
          ..write('id: $id, ')
          ..write('start: $start, ')
          ..write('end: $end')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _themeModeIndexMeta = const VerificationMeta(
    'themeModeIndex',
  );
  @override
  late final GeneratedColumn<int> themeModeIndex = GeneratedColumn<int>(
    'theme_mode_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fontIndexMeta = const VerificationMeta(
    'fontIndex',
  );
  @override
  late final GeneratedColumn<int> fontIndex = GeneratedColumn<int>(
    'font_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, themeModeIndex, fontIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('theme_mode_index')) {
      context.handle(
        _themeModeIndexMeta,
        themeModeIndex.isAcceptableOrUnknown(
          data['theme_mode_index']!,
          _themeModeIndexMeta,
        ),
      );
    }
    if (data.containsKey('font_index')) {
      context.handle(
        _fontIndexMeta,
        fontIndex.isAcceptableOrUnknown(data['font_index']!, _fontIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      themeModeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}theme_mode_index'],
      )!,
      fontIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}font_index'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingsRow extends DataClass implements Insertable<AppSettingsRow> {
  final int id;
  final int themeModeIndex;
  final int fontIndex;
  const AppSettingsRow({
    required this.id,
    required this.themeModeIndex,
    required this.fontIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['theme_mode_index'] = Variable<int>(themeModeIndex);
    map['font_index'] = Variable<int>(fontIndex);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      themeModeIndex: Value(themeModeIndex),
      fontIndex: Value(fontIndex),
    );
  }

  factory AppSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsRow(
      id: serializer.fromJson<int>(json['id']),
      themeModeIndex: serializer.fromJson<int>(json['themeModeIndex']),
      fontIndex: serializer.fromJson<int>(json['fontIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeModeIndex': serializer.toJson<int>(themeModeIndex),
      'fontIndex': serializer.toJson<int>(fontIndex),
    };
  }

  AppSettingsRow copyWith({int? id, int? themeModeIndex, int? fontIndex}) =>
      AppSettingsRow(
        id: id ?? this.id,
        themeModeIndex: themeModeIndex ?? this.themeModeIndex,
        fontIndex: fontIndex ?? this.fontIndex,
      );
  AppSettingsRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      themeModeIndex: data.themeModeIndex.present
          ? data.themeModeIndex.value
          : this.themeModeIndex,
      fontIndex: data.fontIndex.present ? data.fontIndex.value : this.fontIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRow(')
          ..write('id: $id, ')
          ..write('themeModeIndex: $themeModeIndex, ')
          ..write('fontIndex: $fontIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, themeModeIndex, fontIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsRow &&
          other.id == this.id &&
          other.themeModeIndex == this.themeModeIndex &&
          other.fontIndex == this.fontIndex);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingsRow> {
  final Value<int> id;
  final Value<int> themeModeIndex;
  final Value<int> fontIndex;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.themeModeIndex = const Value.absent(),
    this.fontIndex = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.themeModeIndex = const Value.absent(),
    this.fontIndex = const Value.absent(),
  });
  static Insertable<AppSettingsRow> custom({
    Expression<int>? id,
    Expression<int>? themeModeIndex,
    Expression<int>? fontIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeModeIndex != null) 'theme_mode_index': themeModeIndex,
      if (fontIndex != null) 'font_index': fontIndex,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<int>? themeModeIndex,
    Value<int>? fontIndex,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      fontIndex: fontIndex ?? this.fontIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeModeIndex.present) {
      map['theme_mode_index'] = Variable<int>(themeModeIndex.value);
    }
    if (fontIndex.present) {
      map['font_index'] = Variable<int>(fontIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('themeModeIndex: $themeModeIndex, ')
          ..write('fontIndex: $fontIndex')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LensesTable lenses = $LensesTable(this);
  late final $TemplatesTable templates = $TemplatesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $ViewsTable views = $ViewsTable(this);
  late final $TaskLensTable taskLens = $TaskLensTable(this);
  late final $ViewLensTable viewLens = $ViewLensTable(this);
  late final $VacationsTable vacations = $VacationsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lenses,
    templates,
    tasks,
    views,
    taskLens,
    viewLens,
    vacations,
    appSettings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lenses',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('templates', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_lens', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lenses',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_lens', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'views',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('view_lens', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lenses',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('view_lens', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LensesTableCreateCompanionBuilder =
    LensesCompanion Function({
      Value<int> id,
      required String name,
      Value<int> showCount,
      required LensOrdering ordering,
      required LensSelection selection,
      Value<Recurrence?> period,
      Value<int?> dormantAfter,
      Value<int> sortIndex,
    });
typedef $$LensesTableUpdateCompanionBuilder =
    LensesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> showCount,
      Value<LensOrdering> ordering,
      Value<LensSelection> selection,
      Value<Recurrence?> period,
      Value<int?> dormantAfter,
      Value<int> sortIndex,
    });

final class $$LensesTableReferences
    extends BaseReferences<_$AppDatabase, $LensesTable, LensRow> {
  $$LensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TemplatesTable, List<TemplateRow>>
  _templatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.templates,
    aliasName: 'lenses__id__templates__default_lens_id',
  );

  $$TemplatesTableProcessedTableManager get templatesRefs {
    final manager = $$TemplatesTableTableManager(
      $_db,
      $_db.templates,
    ).filter((f) => f.defaultLensId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_templatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskLensTable, List<TaskLensRow>>
  _taskLensRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskLens,
    aliasName: 'lenses__id__task_lens__lens_id',
  );

  $$TaskLensTableProcessedTableManager get taskLensRefs {
    final manager = $$TaskLensTableTableManager(
      $_db,
      $_db.taskLens,
    ).filter((f) => f.lensId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskLensRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ViewLensTable, List<ViewLensRow>>
  _viewLensRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.viewLens,
    aliasName: 'lenses__id__view_lens__lens_id',
  );

  $$ViewLensTableProcessedTableManager get viewLensRefs {
    final manager = $$ViewLensTableTableManager(
      $_db,
      $_db.viewLens,
    ).filter((f) => f.lensId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_viewLensRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LensesTableFilterComposer
    extends Composer<_$AppDatabase, $LensesTable> {
  $$LensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get showCount => $composableBuilder(
    column: $table.showCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LensOrdering, LensOrdering, int>
  get ordering => $composableBuilder(
    column: $table.ordering,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<LensSelection, LensSelection, int>
  get selection => $composableBuilder(
    column: $table.selection,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<Recurrence?, Recurrence, String> get period =>
      $composableBuilder(
        column: $table.period,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get dormantAfter => $composableBuilder(
    column: $table.dormantAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> templatesRefs(
    Expression<bool> Function($$TemplatesTableFilterComposer f) f,
  ) {
    final $$TemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.defaultLensId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableFilterComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskLensRefs(
    Expression<bool> Function($$TaskLensTableFilterComposer f) f,
  ) {
    final $$TaskLensTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLens,
      getReferencedColumn: (t) => t.lensId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskLensTableFilterComposer(
            $db: $db,
            $table: $db.taskLens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> viewLensRefs(
    Expression<bool> Function($$ViewLensTableFilterComposer f) f,
  ) {
    final $$ViewLensTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.viewLens,
      getReferencedColumn: (t) => t.lensId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewLensTableFilterComposer(
            $db: $db,
            $table: $db.viewLens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LensesTableOrderingComposer
    extends Composer<_$AppDatabase, $LensesTable> {
  $$LensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get showCount => $composableBuilder(
    column: $table.showCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordering => $composableBuilder(
    column: $table.ordering,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get selection => $composableBuilder(
    column: $table.selection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dormantAfter => $composableBuilder(
    column: $table.dormantAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LensesTable> {
  $$LensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get showCount =>
      $composableBuilder(column: $table.showCount, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LensOrdering, int> get ordering =>
      $composableBuilder(column: $table.ordering, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LensSelection, int> get selection =>
      $composableBuilder(column: $table.selection, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Recurrence?, String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get dormantAfter => $composableBuilder(
    column: $table.dormantAfter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  Expression<T> templatesRefs<T extends Object>(
    Expression<T> Function($$TemplatesTableAnnotationComposer a) f,
  ) {
    final $$TemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.defaultLensId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskLensRefs<T extends Object>(
    Expression<T> Function($$TaskLensTableAnnotationComposer a) f,
  ) {
    final $$TaskLensTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLens,
      getReferencedColumn: (t) => t.lensId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskLensTableAnnotationComposer(
            $db: $db,
            $table: $db.taskLens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> viewLensRefs<T extends Object>(
    Expression<T> Function($$ViewLensTableAnnotationComposer a) f,
  ) {
    final $$ViewLensTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.viewLens,
      getReferencedColumn: (t) => t.lensId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewLensTableAnnotationComposer(
            $db: $db,
            $table: $db.viewLens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LensesTable,
          LensRow,
          $$LensesTableFilterComposer,
          $$LensesTableOrderingComposer,
          $$LensesTableAnnotationComposer,
          $$LensesTableCreateCompanionBuilder,
          $$LensesTableUpdateCompanionBuilder,
          (LensRow, $$LensesTableReferences),
          LensRow,
          PrefetchHooks Function({
            bool templatesRefs,
            bool taskLensRefs,
            bool viewLensRefs,
          })
        > {
  $$LensesTableTableManager(_$AppDatabase db, $LensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> showCount = const Value.absent(),
                Value<LensOrdering> ordering = const Value.absent(),
                Value<LensSelection> selection = const Value.absent(),
                Value<Recurrence?> period = const Value.absent(),
                Value<int?> dormantAfter = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
              }) => LensesCompanion(
                id: id,
                name: name,
                showCount: showCount,
                ordering: ordering,
                selection: selection,
                period: period,
                dormantAfter: dormantAfter,
                sortIndex: sortIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> showCount = const Value.absent(),
                required LensOrdering ordering,
                required LensSelection selection,
                Value<Recurrence?> period = const Value.absent(),
                Value<int?> dormantAfter = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
              }) => LensesCompanion.insert(
                id: id,
                name: name,
                showCount: showCount,
                ordering: ordering,
                selection: selection,
                period: period,
                dormantAfter: dormantAfter,
                sortIndex: sortIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$LensesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                templatesRefs = false,
                taskLensRefs = false,
                viewLensRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (templatesRefs) db.templates,
                    if (taskLensRefs) db.taskLens,
                    if (viewLensRefs) db.viewLens,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (templatesRefs)
                        await $_getPrefetchedData<
                          LensRow,
                          $LensesTable,
                          TemplateRow
                        >(
                          currentTable: table,
                          referencedTable: $$LensesTableReferences
                              ._templatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LensesTableReferences(
                                db,
                                table,
                                p0,
                              ).templatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.defaultLensId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskLensRefs)
                        await $_getPrefetchedData<
                          LensRow,
                          $LensesTable,
                          TaskLensRow
                        >(
                          currentTable: table,
                          referencedTable: $$LensesTableReferences
                              ._taskLensRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LensesTableReferences(
                                db,
                                table,
                                p0,
                              ).taskLensRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lensId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (viewLensRefs)
                        await $_getPrefetchedData<
                          LensRow,
                          $LensesTable,
                          ViewLensRow
                        >(
                          currentTable: table,
                          referencedTable: $$LensesTableReferences
                              ._viewLensRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LensesTableReferences(
                                db,
                                table,
                                p0,
                              ).viewLensRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.lensId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LensesTable,
      LensRow,
      $$LensesTableFilterComposer,
      $$LensesTableOrderingComposer,
      $$LensesTableAnnotationComposer,
      $$LensesTableCreateCompanionBuilder,
      $$LensesTableUpdateCompanionBuilder,
      (LensRow, $$LensesTableReferences),
      LensRow,
      PrefetchHooks Function({
        bool templatesRefs,
        bool taskLensRefs,
        bool viewLensRefs,
      })
    >;
typedef $$TemplatesTableCreateCompanionBuilder =
    TemplatesCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> note,
      required Recurrence recurrence,
      required WindowRule windowRule,
      Value<bool> paused,
      Value<DateTime?> resumeOn,
      required DateTime createdAt,
      Value<int?> defaultLensId,
    });
typedef $$TemplatesTableUpdateCompanionBuilder =
    TemplatesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> note,
      Value<Recurrence> recurrence,
      Value<WindowRule> windowRule,
      Value<bool> paused,
      Value<DateTime?> resumeOn,
      Value<DateTime> createdAt,
      Value<int?> defaultLensId,
    });

final class $$TemplatesTableReferences
    extends BaseReferences<_$AppDatabase, $TemplatesTable, TemplateRow> {
  $$TemplatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LensesTable _defaultLensIdTable(_$AppDatabase db) =>
      db.lenses.createAlias('templates__default_lens_id__lenses__id');

  $$LensesTableProcessedTableManager? get defaultLensId {
    final $_column = $_itemColumn<int>('default_lens_id');
    if ($_column == null) return null;
    final manager = $$LensesTableTableManager(
      $_db,
      $_db.lenses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_defaultLensIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<TaskRow>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'templates__id__tasks__template_id',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Recurrence, Recurrence, String>
  get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<WindowRule, WindowRule, String>
  get windowRule => $composableBuilder(
    column: $table.windowRule,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resumeOn => $composableBuilder(
    column: $table.resumeOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LensesTableFilterComposer get defaultLensId {
    final $$LensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultLensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableFilterComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get windowRule => $composableBuilder(
    column: $table.windowRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resumeOn => $composableBuilder(
    column: $table.resumeOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LensesTableOrderingComposer get defaultLensId {
    final $$LensesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultLensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableOrderingComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TemplatesTable> {
  $$TemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Recurrence, String> get recurrence =>
      $composableBuilder(
        column: $table.recurrence,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<WindowRule, String> get windowRule =>
      $composableBuilder(
        column: $table.windowRule,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get paused =>
      $composableBuilder(column: $table.paused, builder: (column) => column);

  GeneratedColumn<DateTime> get resumeOn =>
      $composableBuilder(column: $table.resumeOn, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LensesTableAnnotationComposer get defaultLensId {
    final $$LensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultLensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableAnnotationComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TemplatesTable,
          TemplateRow,
          $$TemplatesTableFilterComposer,
          $$TemplatesTableOrderingComposer,
          $$TemplatesTableAnnotationComposer,
          $$TemplatesTableCreateCompanionBuilder,
          $$TemplatesTableUpdateCompanionBuilder,
          (TemplateRow, $$TemplatesTableReferences),
          TemplateRow,
          PrefetchHooks Function({bool defaultLensId, bool tasksRefs})
        > {
  $$TemplatesTableTableManager(_$AppDatabase db, $TemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<Recurrence> recurrence = const Value.absent(),
                Value<WindowRule> windowRule = const Value.absent(),
                Value<bool> paused = const Value.absent(),
                Value<DateTime?> resumeOn = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> defaultLensId = const Value.absent(),
              }) => TemplatesCompanion(
                id: id,
                name: name,
                note: note,
                recurrence: recurrence,
                windowRule: windowRule,
                paused: paused,
                resumeOn: resumeOn,
                createdAt: createdAt,
                defaultLensId: defaultLensId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> note = const Value.absent(),
                required Recurrence recurrence,
                required WindowRule windowRule,
                Value<bool> paused = const Value.absent(),
                Value<DateTime?> resumeOn = const Value.absent(),
                required DateTime createdAt,
                Value<int?> defaultLensId = const Value.absent(),
              }) => TemplatesCompanion.insert(
                id: id,
                name: name,
                note: note,
                recurrence: recurrence,
                windowRule: windowRule,
                paused: paused,
                resumeOn: resumeOn,
                createdAt: createdAt,
                defaultLensId: defaultLensId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({defaultLensId = false, tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (defaultLensId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.defaultLensId,
                                referencedTable: $$TemplatesTableReferences
                                    ._defaultLensIdTable(db),
                                referencedColumn: $$TemplatesTableReferences
                                    ._defaultLensIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedData<
                      TemplateRow,
                      $TemplatesTable,
                      TaskRow
                    >(
                      currentTable: table,
                      referencedTable: $$TemplatesTableReferences
                          ._tasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TemplatesTableReferences(db, table, p0).tasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.templateId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TemplatesTable,
      TemplateRow,
      $$TemplatesTableFilterComposer,
      $$TemplatesTableOrderingComposer,
      $$TemplatesTableAnnotationComposer,
      $$TemplatesTableCreateCompanionBuilder,
      $$TemplatesTableUpdateCompanionBuilder,
      (TemplateRow, $$TemplatesTableReferences),
      TemplateRow,
      PrefetchHooks Function({bool defaultLensId, bool tasksRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      Value<int?> templateId,
      Value<DateTime?> occurrence,
      required String name,
      Value<String?> note,
      required TaskStatus status,
      Value<DateTime?> windowStart,
      Value<DateTime?> windowEnd,
      required DateTime createdAt,
      Value<DateTime?> resolvedAt,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<int> id,
      Value<int?> templateId,
      Value<DateTime?> occurrence,
      Value<String> name,
      Value<String?> note,
      Value<TaskStatus> status,
      Value<DateTime?> windowStart,
      Value<DateTime?> windowEnd,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, TaskRow> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TemplatesTable _templateIdTable(_$AppDatabase db) =>
      db.templates.createAlias('tasks__template_id__templates__id');

  $$TemplatesTableProcessedTableManager? get templateId {
    final $_column = $_itemColumn<int>('template_id');
    if ($_column == null) return null;
    final manager = $$TemplatesTableTableManager(
      $_db,
      $_db.templates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TaskLensTable, List<TaskLensRow>>
  _taskLensRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskLens,
    aliasName: 'tasks__id__task_lens__task_id',
  );

  $$TaskLensTableProcessedTableManager get taskLensRefs {
    final manager = $$TaskLensTableTableManager(
      $_db,
      $_db.taskLens,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskLensRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurrence => $composableBuilder(
    column: $table.occurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskStatus, TaskStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get windowStart => $composableBuilder(
    column: $table.windowStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get windowEnd => $composableBuilder(
    column: $table.windowEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TemplatesTableFilterComposer get templateId {
    final $$TemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableFilterComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> taskLensRefs(
    Expression<bool> Function($$TaskLensTableFilterComposer f) f,
  ) {
    final $$TaskLensTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLens,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskLensTableFilterComposer(
            $db: $db,
            $table: $db.taskLens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurrence => $composableBuilder(
    column: $table.occurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get windowStart => $composableBuilder(
    column: $table.windowStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get windowEnd => $composableBuilder(
    column: $table.windowEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TemplatesTableOrderingComposer get templateId {
    final $$TemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get occurrence => $composableBuilder(
    column: $table.occurrence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get windowStart => $composableBuilder(
    column: $table.windowStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get windowEnd =>
      $composableBuilder(column: $table.windowEnd, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  $$TemplatesTableAnnotationComposer get templateId {
    final $$TemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.templates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.templates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> taskLensRefs<T extends Object>(
    Expression<T> Function($$TaskLensTableAnnotationComposer a) f,
  ) {
    final $$TaskLensTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskLens,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskLensTableAnnotationComposer(
            $db: $db,
            $table: $db.taskLens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, $$TasksTableReferences),
          TaskRow,
          PrefetchHooks Function({bool templateId, bool taskLensRefs})
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> templateId = const Value.absent(),
                Value<DateTime?> occurrence = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<DateTime?> windowStart = const Value.absent(),
                Value<DateTime?> windowEnd = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                templateId: templateId,
                occurrence: occurrence,
                name: name,
                note: note,
                status: status,
                windowStart: windowStart,
                windowEnd: windowEnd,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> templateId = const Value.absent(),
                Value<DateTime?> occurrence = const Value.absent(),
                required String name,
                Value<String?> note = const Value.absent(),
                required TaskStatus status,
                Value<DateTime?> windowStart = const Value.absent(),
                Value<DateTime?> windowEnd = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                templateId: templateId,
                occurrence: occurrence,
                name: name,
                note: note,
                status: status,
                windowStart: windowStart,
                windowEnd: windowEnd,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({templateId = false, taskLensRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (taskLensRefs) db.taskLens],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (templateId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.templateId,
                                referencedTable: $$TasksTableReferences
                                    ._templateIdTable(db),
                                referencedColumn: $$TasksTableReferences
                                    ._templateIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskLensRefs)
                    await $_getPrefetchedData<
                      TaskRow,
                      $TasksTable,
                      TaskLensRow
                    >(
                      currentTable: table,
                      referencedTable: $$TasksTableReferences
                          ._taskLensRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TasksTableReferences(db, table, p0).taskLensRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.taskId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, $$TasksTableReferences),
      TaskRow,
      PrefetchHooks Function({bool templateId, bool taskLensRefs})
    >;
typedef $$ViewsTableCreateCompanionBuilder =
    ViewsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> sortIndex,
    });
typedef $$ViewsTableUpdateCompanionBuilder =
    ViewsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> sortIndex,
    });

final class $$ViewsTableReferences
    extends BaseReferences<_$AppDatabase, $ViewsTable, ViewRow> {
  $$ViewsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ViewLensTable, List<ViewLensRow>>
  _viewLensRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.viewLens,
    aliasName: 'views__id__view_lens__view_id',
  );

  $$ViewLensTableProcessedTableManager get viewLensRefs {
    final manager = $$ViewLensTableTableManager(
      $_db,
      $_db.viewLens,
    ).filter((f) => f.viewId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_viewLensRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ViewsTableFilterComposer extends Composer<_$AppDatabase, $ViewsTable> {
  $$ViewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> viewLensRefs(
    Expression<bool> Function($$ViewLensTableFilterComposer f) f,
  ) {
    final $$ViewLensTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.viewLens,
      getReferencedColumn: (t) => t.viewId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewLensTableFilterComposer(
            $db: $db,
            $table: $db.viewLens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ViewsTableOrderingComposer
    extends Composer<_$AppDatabase, $ViewsTable> {
  $$ViewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ViewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ViewsTable> {
  $$ViewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  Expression<T> viewLensRefs<T extends Object>(
    Expression<T> Function($$ViewLensTableAnnotationComposer a) f,
  ) {
    final $$ViewLensTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.viewLens,
      getReferencedColumn: (t) => t.viewId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewLensTableAnnotationComposer(
            $db: $db,
            $table: $db.viewLens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ViewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ViewsTable,
          ViewRow,
          $$ViewsTableFilterComposer,
          $$ViewsTableOrderingComposer,
          $$ViewsTableAnnotationComposer,
          $$ViewsTableCreateCompanionBuilder,
          $$ViewsTableUpdateCompanionBuilder,
          (ViewRow, $$ViewsTableReferences),
          ViewRow,
          PrefetchHooks Function({bool viewLensRefs})
        > {
  $$ViewsTableTableManager(_$AppDatabase db, $ViewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ViewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ViewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ViewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
              }) => ViewsCompanion(id: id, name: name, sortIndex: sortIndex),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> sortIndex = const Value.absent(),
              }) => ViewsCompanion.insert(
                id: id,
                name: name,
                sortIndex: sortIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ViewsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({viewLensRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (viewLensRefs) db.viewLens],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (viewLensRefs)
                    await $_getPrefetchedData<
                      ViewRow,
                      $ViewsTable,
                      ViewLensRow
                    >(
                      currentTable: table,
                      referencedTable: $$ViewsTableReferences
                          ._viewLensRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ViewsTableReferences(db, table, p0).viewLensRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.viewId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ViewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ViewsTable,
      ViewRow,
      $$ViewsTableFilterComposer,
      $$ViewsTableOrderingComposer,
      $$ViewsTableAnnotationComposer,
      $$ViewsTableCreateCompanionBuilder,
      $$ViewsTableUpdateCompanionBuilder,
      (ViewRow, $$ViewsTableReferences),
      ViewRow,
      PrefetchHooks Function({bool viewLensRefs})
    >;
typedef $$TaskLensTableCreateCompanionBuilder =
    TaskLensCompanion Function({
      required int taskId,
      required int lensId,
      Value<int> sortOrder,
      Value<DateTime?> surfacedAt,
      Value<bool> passedThisPeriod,
      Value<int> rowid,
    });
typedef $$TaskLensTableUpdateCompanionBuilder =
    TaskLensCompanion Function({
      Value<int> taskId,
      Value<int> lensId,
      Value<int> sortOrder,
      Value<DateTime?> surfacedAt,
      Value<bool> passedThisPeriod,
      Value<int> rowid,
    });

final class $$TaskLensTableReferences
    extends BaseReferences<_$AppDatabase, $TaskLensTable, TaskLensRow> {
  $$TaskLensTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) =>
      db.tasks.createAlias('task_lens__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<int>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LensesTable _lensIdTable(_$AppDatabase db) =>
      db.lenses.createAlias('task_lens__lens_id__lenses__id');

  $$LensesTableProcessedTableManager get lensId {
    final $_column = $_itemColumn<int>('lens_id')!;

    final manager = $$LensesTableTableManager(
      $_db,
      $_db.lenses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lensIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskLensTableFilterComposer
    extends Composer<_$AppDatabase, $TaskLensTable> {
  $$TaskLensTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get surfacedAt => $composableBuilder(
    column: $table.surfacedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get passedThisPeriod => $composableBuilder(
    column: $table.passedThisPeriod,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableFilterComposer get lensId {
    final $$LensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableFilterComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskLensTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskLensTable> {
  $$TaskLensTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get surfacedAt => $composableBuilder(
    column: $table.surfacedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get passedThisPeriod => $composableBuilder(
    column: $table.passedThisPeriod,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableOrderingComposer get lensId {
    final $$LensesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableOrderingComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskLensTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskLensTable> {
  $$TaskLensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get surfacedAt => $composableBuilder(
    column: $table.surfacedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get passedThisPeriod => $composableBuilder(
    column: $table.passedThisPeriod,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableAnnotationComposer get lensId {
    final $$LensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableAnnotationComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskLensTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskLensTable,
          TaskLensRow,
          $$TaskLensTableFilterComposer,
          $$TaskLensTableOrderingComposer,
          $$TaskLensTableAnnotationComposer,
          $$TaskLensTableCreateCompanionBuilder,
          $$TaskLensTableUpdateCompanionBuilder,
          (TaskLensRow, $$TaskLensTableReferences),
          TaskLensRow,
          PrefetchHooks Function({bool taskId, bool lensId})
        > {
  $$TaskLensTableTableManager(_$AppDatabase db, $TaskLensTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskLensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskLensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskLensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> taskId = const Value.absent(),
                Value<int> lensId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> surfacedAt = const Value.absent(),
                Value<bool> passedThisPeriod = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskLensCompanion(
                taskId: taskId,
                lensId: lensId,
                sortOrder: sortOrder,
                surfacedAt: surfacedAt,
                passedThisPeriod: passedThisPeriod,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int taskId,
                required int lensId,
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> surfacedAt = const Value.absent(),
                Value<bool> passedThisPeriod = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskLensCompanion.insert(
                taskId: taskId,
                lensId: lensId,
                sortOrder: sortOrder,
                surfacedAt: surfacedAt,
                passedThisPeriod: passedThisPeriod,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskLensTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, lensId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$TaskLensTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$TaskLensTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (lensId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.lensId,
                                referencedTable: $$TaskLensTableReferences
                                    ._lensIdTable(db),
                                referencedColumn: $$TaskLensTableReferences
                                    ._lensIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskLensTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskLensTable,
      TaskLensRow,
      $$TaskLensTableFilterComposer,
      $$TaskLensTableOrderingComposer,
      $$TaskLensTableAnnotationComposer,
      $$TaskLensTableCreateCompanionBuilder,
      $$TaskLensTableUpdateCompanionBuilder,
      (TaskLensRow, $$TaskLensTableReferences),
      TaskLensRow,
      PrefetchHooks Function({bool taskId, bool lensId})
    >;
typedef $$ViewLensTableCreateCompanionBuilder =
    ViewLensCompanion Function({
      required int viewId,
      required int lensId,
      Value<int> sortOrder,
      Value<int> statusFilter,
      Value<int> rowid,
    });
typedef $$ViewLensTableUpdateCompanionBuilder =
    ViewLensCompanion Function({
      Value<int> viewId,
      Value<int> lensId,
      Value<int> sortOrder,
      Value<int> statusFilter,
      Value<int> rowid,
    });

final class $$ViewLensTableReferences
    extends BaseReferences<_$AppDatabase, $ViewLensTable, ViewLensRow> {
  $$ViewLensTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ViewsTable _viewIdTable(_$AppDatabase db) =>
      db.views.createAlias('view_lens__view_id__views__id');

  $$ViewsTableProcessedTableManager get viewId {
    final $_column = $_itemColumn<int>('view_id')!;

    final manager = $$ViewsTableTableManager(
      $_db,
      $_db.views,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_viewIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LensesTable _lensIdTable(_$AppDatabase db) =>
      db.lenses.createAlias('view_lens__lens_id__lenses__id');

  $$LensesTableProcessedTableManager get lensId {
    final $_column = $_itemColumn<int>('lens_id')!;

    final manager = $$LensesTableTableManager(
      $_db,
      $_db.lenses,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_lensIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ViewLensTableFilterComposer
    extends Composer<_$AppDatabase, $ViewLensTable> {
  $$ViewLensTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statusFilter => $composableBuilder(
    column: $table.statusFilter,
    builder: (column) => ColumnFilters(column),
  );

  $$ViewsTableFilterComposer get viewId {
    final $$ViewsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.viewId,
      referencedTable: $db.views,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewsTableFilterComposer(
            $db: $db,
            $table: $db.views,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableFilterComposer get lensId {
    final $$LensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableFilterComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewLensTableOrderingComposer
    extends Composer<_$AppDatabase, $ViewLensTable> {
  $$ViewLensTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statusFilter => $composableBuilder(
    column: $table.statusFilter,
    builder: (column) => ColumnOrderings(column),
  );

  $$ViewsTableOrderingComposer get viewId {
    final $$ViewsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.viewId,
      referencedTable: $db.views,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewsTableOrderingComposer(
            $db: $db,
            $table: $db.views,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableOrderingComposer get lensId {
    final $$LensesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableOrderingComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewLensTableAnnotationComposer
    extends Composer<_$AppDatabase, $ViewLensTable> {
  $$ViewLensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get statusFilter => $composableBuilder(
    column: $table.statusFilter,
    builder: (column) => column,
  );

  $$ViewsTableAnnotationComposer get viewId {
    final $$ViewsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.viewId,
      referencedTable: $db.views,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ViewsTableAnnotationComposer(
            $db: $db,
            $table: $db.views,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LensesTableAnnotationComposer get lensId {
    final $$LensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.lensId,
      referencedTable: $db.lenses,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LensesTableAnnotationComposer(
            $db: $db,
            $table: $db.lenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ViewLensTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ViewLensTable,
          ViewLensRow,
          $$ViewLensTableFilterComposer,
          $$ViewLensTableOrderingComposer,
          $$ViewLensTableAnnotationComposer,
          $$ViewLensTableCreateCompanionBuilder,
          $$ViewLensTableUpdateCompanionBuilder,
          (ViewLensRow, $$ViewLensTableReferences),
          ViewLensRow,
          PrefetchHooks Function({bool viewId, bool lensId})
        > {
  $$ViewLensTableTableManager(_$AppDatabase db, $ViewLensTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ViewLensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ViewLensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ViewLensTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> viewId = const Value.absent(),
                Value<int> lensId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> statusFilter = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ViewLensCompanion(
                viewId: viewId,
                lensId: lensId,
                sortOrder: sortOrder,
                statusFilter: statusFilter,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int viewId,
                required int lensId,
                Value<int> sortOrder = const Value.absent(),
                Value<int> statusFilter = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ViewLensCompanion.insert(
                viewId: viewId,
                lensId: lensId,
                sortOrder: sortOrder,
                statusFilter: statusFilter,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ViewLensTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({viewId = false, lensId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (viewId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.viewId,
                                referencedTable: $$ViewLensTableReferences
                                    ._viewIdTable(db),
                                referencedColumn: $$ViewLensTableReferences
                                    ._viewIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (lensId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.lensId,
                                referencedTable: $$ViewLensTableReferences
                                    ._lensIdTable(db),
                                referencedColumn: $$ViewLensTableReferences
                                    ._lensIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ViewLensTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ViewLensTable,
      ViewLensRow,
      $$ViewLensTableFilterComposer,
      $$ViewLensTableOrderingComposer,
      $$ViewLensTableAnnotationComposer,
      $$ViewLensTableCreateCompanionBuilder,
      $$ViewLensTableUpdateCompanionBuilder,
      (ViewLensRow, $$ViewLensTableReferences),
      ViewLensRow,
      PrefetchHooks Function({bool viewId, bool lensId})
    >;
typedef $$VacationsTableCreateCompanionBuilder =
    VacationsCompanion Function({
      Value<int> id,
      required DateTime start,
      required DateTime end,
    });
typedef $$VacationsTableUpdateCompanionBuilder =
    VacationsCompanion Function({
      Value<int> id,
      Value<DateTime> start,
      Value<DateTime> end,
    });

class $$VacationsTableFilterComposer
    extends Composer<_$AppDatabase, $VacationsTable> {
  $$VacationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VacationsTableOrderingComposer
    extends Composer<_$AppDatabase, $VacationsTable> {
  $$VacationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VacationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $VacationsTable> {
  $$VacationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);
}

class $$VacationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VacationsTable,
          VacationRow,
          $$VacationsTableFilterComposer,
          $$VacationsTableOrderingComposer,
          $$VacationsTableAnnotationComposer,
          $$VacationsTableCreateCompanionBuilder,
          $$VacationsTableUpdateCompanionBuilder,
          (
            VacationRow,
            BaseReferences<_$AppDatabase, $VacationsTable, VacationRow>,
          ),
          VacationRow,
          PrefetchHooks Function()
        > {
  $$VacationsTableTableManager(_$AppDatabase db, $VacationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VacationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VacationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VacationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> start = const Value.absent(),
                Value<DateTime> end = const Value.absent(),
              }) => VacationsCompanion(id: id, start: start, end: end),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime start,
                required DateTime end,
              }) => VacationsCompanion.insert(id: id, start: start, end: end),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VacationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VacationsTable,
      VacationRow,
      $$VacationsTableFilterComposer,
      $$VacationsTableOrderingComposer,
      $$VacationsTableAnnotationComposer,
      $$VacationsTableCreateCompanionBuilder,
      $$VacationsTableUpdateCompanionBuilder,
      (
        VacationRow,
        BaseReferences<_$AppDatabase, $VacationsTable, VacationRow>,
      ),
      VacationRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<int> themeModeIndex,
      Value<int> fontIndex,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<int> themeModeIndex,
      Value<int> fontIndex,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get themeModeIndex => $composableBuilder(
    column: $table.themeModeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fontIndex => $composableBuilder(
    column: $table.fontIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get themeModeIndex => $composableBuilder(
    column: $table.themeModeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fontIndex => $composableBuilder(
    column: $table.fontIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get themeModeIndex => $composableBuilder(
    column: $table.themeModeIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fontIndex =>
      $composableBuilder(column: $table.fontIndex, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingsRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingsRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>,
          ),
          AppSettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> themeModeIndex = const Value.absent(),
                Value<int> fontIndex = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                themeModeIndex: themeModeIndex,
                fontIndex: fontIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> themeModeIndex = const Value.absent(),
                Value<int> fontIndex = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                themeModeIndex: themeModeIndex,
                fontIndex: fontIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingsRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingsRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingsRow>,
      ),
      AppSettingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LensesTableTableManager get lenses =>
      $$LensesTableTableManager(_db, _db.lenses);
  $$TemplatesTableTableManager get templates =>
      $$TemplatesTableTableManager(_db, _db.templates);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$ViewsTableTableManager get views =>
      $$ViewsTableTableManager(_db, _db.views);
  $$TaskLensTableTableManager get taskLens =>
      $$TaskLensTableTableManager(_db, _db.taskLens);
  $$ViewLensTableTableManager get viewLens =>
      $$ViewLensTableTableManager(_db, _db.viewLens);
  $$VacationsTableTableManager get vacations =>
      $$VacationsTableTableManager(_db, _db.vacations);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
