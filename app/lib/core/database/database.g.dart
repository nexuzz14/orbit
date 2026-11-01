// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalAccountsTable extends LocalAccounts
    with TableInfo<$LocalAccountsTable, LocalAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _initialBalanceMeta =
      const VerificationMeta('initialBalance');
  @override
  late final GeneratedColumn<double> initialBalance = GeneratedColumn<double>(
      'initial_balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _currentBalanceMeta =
      const VerificationMeta('currentBalance');
  @override
  late final GeneratedColumn<double> currentBalance = GeneratedColumn<double>(
      'current_balance', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _isLiquidMeta =
      const VerificationMeta('isLiquid');
  @override
  late final GeneratedColumn<bool> isLiquid = GeneratedColumn<bool>(
      'is_liquid', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_liquid" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _visibilityMeta =
      const VerificationMeta('visibility');
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
      'visibility', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('shared'));
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        name,
        type,
        currency,
        initialBalance,
        currentBalance,
        isLiquid,
        visibility,
        archived,
        sortOrder
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_accounts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAccount> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('initial_balance')) {
      context.handle(
          _initialBalanceMeta,
          initialBalance.isAcceptableOrUnknown(
              data['initial_balance']!, _initialBalanceMeta));
    }
    if (data.containsKey('current_balance')) {
      context.handle(
          _currentBalanceMeta,
          currentBalance.isAcceptableOrUnknown(
              data['current_balance']!, _currentBalanceMeta));
    }
    if (data.containsKey('is_liquid')) {
      context.handle(_isLiquidMeta,
          isLiquid.isAcceptableOrUnknown(data['is_liquid']!, _isLiquidMeta));
    }
    if (data.containsKey('visibility')) {
      context.handle(
          _visibilityMeta,
          visibility.isAcceptableOrUnknown(
              data['visibility']!, _visibilityMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAccount(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      initialBalance: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}initial_balance'])!,
      currentBalance: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}current_balance'])!,
      isLiquid: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_liquid'])!,
      visibility: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}visibility'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $LocalAccountsTable createAlias(String alias) {
    return $LocalAccountsTable(attachedDatabase, alias);
  }
}

class LocalAccount extends DataClass implements Insertable<LocalAccount> {
  final String id;
  final String workspaceId;
  final String name;
  final String type;
  final String currency;
  final double initialBalance;
  final double currentBalance;
  final bool isLiquid;
  final String visibility;
  final bool archived;
  final int sortOrder;
  const LocalAccount(
      {required this.id,
      required this.workspaceId,
      required this.name,
      required this.type,
      required this.currency,
      required this.initialBalance,
      required this.currentBalance,
      required this.isLiquid,
      required this.visibility,
      required this.archived,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['currency'] = Variable<String>(currency);
    map['initial_balance'] = Variable<double>(initialBalance);
    map['current_balance'] = Variable<double>(currentBalance);
    map['is_liquid'] = Variable<bool>(isLiquid);
    map['visibility'] = Variable<String>(visibility);
    map['archived'] = Variable<bool>(archived);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  LocalAccountsCompanion toCompanion(bool nullToAbsent) {
    return LocalAccountsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      name: Value(name),
      type: Value(type),
      currency: Value(currency),
      initialBalance: Value(initialBalance),
      currentBalance: Value(currentBalance),
      isLiquid: Value(isLiquid),
      visibility: Value(visibility),
      archived: Value(archived),
      sortOrder: Value(sortOrder),
    );
  }

  factory LocalAccount.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAccount(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      currency: serializer.fromJson<String>(json['currency']),
      initialBalance: serializer.fromJson<double>(json['initialBalance']),
      currentBalance: serializer.fromJson<double>(json['currentBalance']),
      isLiquid: serializer.fromJson<bool>(json['isLiquid']),
      visibility: serializer.fromJson<String>(json['visibility']),
      archived: serializer.fromJson<bool>(json['archived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'currency': serializer.toJson<String>(currency),
      'initialBalance': serializer.toJson<double>(initialBalance),
      'currentBalance': serializer.toJson<double>(currentBalance),
      'isLiquid': serializer.toJson<bool>(isLiquid),
      'visibility': serializer.toJson<String>(visibility),
      'archived': serializer.toJson<bool>(archived),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  LocalAccount copyWith(
          {String? id,
          String? workspaceId,
          String? name,
          String? type,
          String? currency,
          double? initialBalance,
          double? currentBalance,
          bool? isLiquid,
          String? visibility,
          bool? archived,
          int? sortOrder}) =>
      LocalAccount(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        initialBalance: initialBalance ?? this.initialBalance,
        currentBalance: currentBalance ?? this.currentBalance,
        isLiquid: isLiquid ?? this.isLiquid,
        visibility: visibility ?? this.visibility,
        archived: archived ?? this.archived,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  LocalAccount copyWithCompanion(LocalAccountsCompanion data) {
    return LocalAccount(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currency: data.currency.present ? data.currency.value : this.currency,
      initialBalance: data.initialBalance.present
          ? data.initialBalance.value
          : this.initialBalance,
      currentBalance: data.currentBalance.present
          ? data.currentBalance.value
          : this.currentBalance,
      isLiquid: data.isLiquid.present ? data.isLiquid.value : this.isLiquid,
      visibility:
          data.visibility.present ? data.visibility.value : this.visibility,
      archived: data.archived.present ? data.archived.value : this.archived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccount(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('currentBalance: $currentBalance, ')
          ..write('isLiquid: $isLiquid, ')
          ..write('visibility: $visibility, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      name,
      type,
      currency,
      initialBalance,
      currentBalance,
      isLiquid,
      visibility,
      archived,
      sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAccount &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.name == this.name &&
          other.type == this.type &&
          other.currency == this.currency &&
          other.initialBalance == this.initialBalance &&
          other.currentBalance == this.currentBalance &&
          other.isLiquid == this.isLiquid &&
          other.visibility == this.visibility &&
          other.archived == this.archived &&
          other.sortOrder == this.sortOrder);
}

class LocalAccountsCompanion extends UpdateCompanion<LocalAccount> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> name;
  final Value<String> type;
  final Value<String> currency;
  final Value<double> initialBalance;
  final Value<double> currentBalance;
  final Value<bool> isLiquid;
  final Value<String> visibility;
  final Value<bool> archived;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const LocalAccountsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currency = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.currentBalance = const Value.absent(),
    this.isLiquid = const Value.absent(),
    this.visibility = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAccountsCompanion.insert({
    required String id,
    required String workspaceId,
    required String name,
    required String type,
    required String currency,
    this.initialBalance = const Value.absent(),
    this.currentBalance = const Value.absent(),
    this.isLiquid = const Value.absent(),
    this.visibility = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        name = Value(name),
        type = Value(type),
        currency = Value(currency);
  static Insertable<LocalAccount> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currency,
    Expression<double>? initialBalance,
    Expression<double>? currentBalance,
    Expression<bool>? isLiquid,
    Expression<String>? visibility,
    Expression<bool>? archived,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currency != null) 'currency': currency,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (currentBalance != null) 'current_balance': currentBalance,
      if (isLiquid != null) 'is_liquid': isLiquid,
      if (visibility != null) 'visibility': visibility,
      if (archived != null) 'archived': archived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAccountsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? name,
      Value<String>? type,
      Value<String>? currency,
      Value<double>? initialBalance,
      Value<double>? currentBalance,
      Value<bool>? isLiquid,
      Value<String>? visibility,
      Value<bool>? archived,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return LocalAccountsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      isLiquid: isLiquid ?? this.isLiquid,
      visibility: visibility ?? this.visibility,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (initialBalance.present) {
      map['initial_balance'] = Variable<double>(initialBalance.value);
    }
    if (currentBalance.present) {
      map['current_balance'] = Variable<double>(currentBalance.value);
    }
    if (isLiquid.present) {
      map['is_liquid'] = Variable<bool>(isLiquid.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccountsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currency: $currency, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('currentBalance: $currentBalance, ')
          ..write('isLiquid: $isLiquid, ')
          ..write('visibility: $visibility, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCategoriesTable extends LocalCategories
    with TableInfo<$LocalCategoriesTable, LocalCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _systemKeyMeta =
      const VerificationMeta('systemKey');
  @override
  late final GeneratedColumn<String> systemKey = GeneratedColumn<String>(
      'system_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, workspaceId, name, type, parentId, systemKey, archived, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_categories';
  @override
  VerificationContext validateIntegrity(Insertable<LocalCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('system_key')) {
      context.handle(_systemKeyMeta,
          systemKey.isAcceptableOrUnknown(data['system_key']!, _systemKeyMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCategory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      systemKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}system_key']),
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $LocalCategoriesTable createAlias(String alias) {
    return $LocalCategoriesTable(attachedDatabase, alias);
  }
}

class LocalCategory extends DataClass implements Insertable<LocalCategory> {
  final String id;
  final String workspaceId;
  final String name;
  final String type;
  final String? parentId;
  final String? systemKey;
  final bool archived;
  final int sortOrder;
  const LocalCategory(
      {required this.id,
      required this.workspaceId,
      required this.name,
      required this.type,
      this.parentId,
      this.systemKey,
      required this.archived,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || systemKey != null) {
      map['system_key'] = Variable<String>(systemKey);
    }
    map['archived'] = Variable<bool>(archived);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  LocalCategoriesCompanion toCompanion(bool nullToAbsent) {
    return LocalCategoriesCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      name: Value(name),
      type: Value(type),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      systemKey: systemKey == null && nullToAbsent
          ? const Value.absent()
          : Value(systemKey),
      archived: Value(archived),
      sortOrder: Value(sortOrder),
    );
  }

  factory LocalCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCategory(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      systemKey: serializer.fromJson<String?>(json['systemKey']),
      archived: serializer.fromJson<bool>(json['archived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'parentId': serializer.toJson<String?>(parentId),
      'systemKey': serializer.toJson<String?>(systemKey),
      'archived': serializer.toJson<bool>(archived),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  LocalCategory copyWith(
          {String? id,
          String? workspaceId,
          String? name,
          String? type,
          Value<String?> parentId = const Value.absent(),
          Value<String?> systemKey = const Value.absent(),
          bool? archived,
          int? sortOrder}) =>
      LocalCategory(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        name: name ?? this.name,
        type: type ?? this.type,
        parentId: parentId.present ? parentId.value : this.parentId,
        systemKey: systemKey.present ? systemKey.value : this.systemKey,
        archived: archived ?? this.archived,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  LocalCategory copyWithCompanion(LocalCategoriesCompanion data) {
    return LocalCategory(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      systemKey: data.systemKey.present ? data.systemKey.value : this.systemKey,
      archived: data.archived.present ? data.archived.value : this.archived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCategory(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('parentId: $parentId, ')
          ..write('systemKey: $systemKey, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, workspaceId, name, type, parentId, systemKey, archived, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCategory &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.name == this.name &&
          other.type == this.type &&
          other.parentId == this.parentId &&
          other.systemKey == this.systemKey &&
          other.archived == this.archived &&
          other.sortOrder == this.sortOrder);
}

class LocalCategoriesCompanion extends UpdateCompanion<LocalCategory> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> parentId;
  final Value<String?> systemKey;
  final Value<bool> archived;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const LocalCategoriesCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.parentId = const Value.absent(),
    this.systemKey = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCategoriesCompanion.insert({
    required String id,
    required String workspaceId,
    required String name,
    required String type,
    this.parentId = const Value.absent(),
    this.systemKey = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        name = Value(name),
        type = Value(type);
  static Insertable<LocalCategory> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? parentId,
    Expression<String>? systemKey,
    Expression<bool>? archived,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (parentId != null) 'parent_id': parentId,
      if (systemKey != null) 'system_key': systemKey,
      if (archived != null) 'archived': archived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCategoriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? name,
      Value<String>? type,
      Value<String?>? parentId,
      Value<String?>? systemKey,
      Value<bool>? archived,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return LocalCategoriesCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      systemKey: systemKey ?? this.systemKey,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (systemKey.present) {
      map['system_key'] = Variable<String>(systemKey.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('parentId: $parentId, ')
          ..write('systemKey: $systemKey, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTransactionsTable extends LocalTransactions
    with TableInfo<$LocalTransactionsTable, LocalTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _draftStateMeta =
      const VerificationMeta('draftState');
  @override
  late final GeneratedColumn<String> draftState = GeneratedColumn<String>(
      'draft_state', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _merchantMeta =
      const VerificationMeta('merchant');
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
      'merchant', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _transferGroupIdMeta =
      const VerificationMeta('transferGroupId');
  @override
  late final GeneratedColumn<String> transferGroupId = GeneratedColumn<String>(
      'transfer_group_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transferDirectionMeta =
      const VerificationMeta('transferDirection');
  @override
  late final GeneratedColumn<String> transferDirection =
      GeneratedColumn<String>('transfer_direction', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
      'origin', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('manual'));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        accountId,
        categoryId,
        type,
        status,
        draftState,
        amount,
        currency,
        source,
        merchant,
        note,
        occurredAt,
        transferGroupId,
        transferDirection,
        origin,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_transactions';
  @override
  VerificationContext validateIntegrity(Insertable<LocalTransaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('draft_state')) {
      context.handle(
          _draftStateMeta,
          draftState.isAcceptableOrUnknown(
              data['draft_state']!, _draftStateMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('merchant')) {
      context.handle(_merchantMeta,
          merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('transfer_group_id')) {
      context.handle(
          _transferGroupIdMeta,
          transferGroupId.isAcceptableOrUnknown(
              data['transfer_group_id']!, _transferGroupIdMeta));
    }
    if (data.containsKey('transfer_direction')) {
      context.handle(
          _transferDirectionMeta,
          transferDirection.isAcceptableOrUnknown(
              data['transfer_direction']!, _transferDirectionMeta));
    }
    if (data.containsKey('origin')) {
      context.handle(_originMeta,
          origin.isAcceptableOrUnknown(data['origin']!, _originMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTransaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      draftState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}draft_state']),
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source']),
      merchant: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}merchant']),
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      transferGroupId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}transfer_group_id']),
      transferDirection: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}transfer_direction']),
      origin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}origin'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalTransactionsTable createAlias(String alias) {
    return $LocalTransactionsTable(attachedDatabase, alias);
  }
}

class LocalTransaction extends DataClass
    implements Insertable<LocalTransaction> {
  final String id;
  final String workspaceId;
  final String accountId;
  final String? categoryId;
  final String type;
  final String status;
  final String? draftState;
  final double amount;
  final String currency;
  final String? source;
  final String? merchant;
  final String? note;
  final DateTime occurredAt;
  final String? transferGroupId;
  final String? transferDirection;
  final String origin;
  final DateTime? deletedAt;
  const LocalTransaction(
      {required this.id,
      required this.workspaceId,
      required this.accountId,
      this.categoryId,
      required this.type,
      required this.status,
      this.draftState,
      required this.amount,
      required this.currency,
      this.source,
      this.merchant,
      this.note,
      required this.occurredAt,
      this.transferGroupId,
      this.transferDirection,
      required this.origin,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['type'] = Variable<String>(type);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || draftState != null) {
      map['draft_state'] = Variable<String>(draftState);
    }
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || transferGroupId != null) {
      map['transfer_group_id'] = Variable<String>(transferGroupId);
    }
    if (!nullToAbsent || transferDirection != null) {
      map['transfer_direction'] = Variable<String>(transferDirection);
    }
    map['origin'] = Variable<String>(origin);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalTransactionsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      accountId: Value(accountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      type: Value(type),
      status: Value(status),
      draftState: draftState == null && nullToAbsent
          ? const Value.absent()
          : Value(draftState),
      amount: Value(amount),
      currency: Value(currency),
      source:
          source == null && nullToAbsent ? const Value.absent() : Value(source),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      transferGroupId: transferGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferGroupId),
      transferDirection: transferDirection == null && nullToAbsent
          ? const Value.absent()
          : Value(transferDirection),
      origin: Value(origin),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalTransaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTransaction(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String>(json['status']),
      draftState: serializer.fromJson<String?>(json['draftState']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      source: serializer.fromJson<String?>(json['source']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      transferGroupId: serializer.fromJson<String?>(json['transferGroupId']),
      transferDirection:
          serializer.fromJson<String?>(json['transferDirection']),
      origin: serializer.fromJson<String>(json['origin']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'accountId': serializer.toJson<String>(accountId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String>(status),
      'draftState': serializer.toJson<String?>(draftState),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'source': serializer.toJson<String?>(source),
      'merchant': serializer.toJson<String?>(merchant),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'transferGroupId': serializer.toJson<String?>(transferGroupId),
      'transferDirection': serializer.toJson<String?>(transferDirection),
      'origin': serializer.toJson<String>(origin),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalTransaction copyWith(
          {String? id,
          String? workspaceId,
          String? accountId,
          Value<String?> categoryId = const Value.absent(),
          String? type,
          String? status,
          Value<String?> draftState = const Value.absent(),
          double? amount,
          String? currency,
          Value<String?> source = const Value.absent(),
          Value<String?> merchant = const Value.absent(),
          Value<String?> note = const Value.absent(),
          DateTime? occurredAt,
          Value<String?> transferGroupId = const Value.absent(),
          Value<String?> transferDirection = const Value.absent(),
          String? origin,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalTransaction(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        accountId: accountId ?? this.accountId,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        type: type ?? this.type,
        status: status ?? this.status,
        draftState: draftState.present ? draftState.value : this.draftState,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        source: source.present ? source.value : this.source,
        merchant: merchant.present ? merchant.value : this.merchant,
        note: note.present ? note.value : this.note,
        occurredAt: occurredAt ?? this.occurredAt,
        transferGroupId: transferGroupId.present
            ? transferGroupId.value
            : this.transferGroupId,
        transferDirection: transferDirection.present
            ? transferDirection.value
            : this.transferDirection,
        origin: origin ?? this.origin,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalTransaction copyWithCompanion(LocalTransactionsCompanion data) {
    return LocalTransaction(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      draftState:
          data.draftState.present ? data.draftState.value : this.draftState,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      source: data.source.present ? data.source.value : this.source,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      note: data.note.present ? data.note.value : this.note,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      transferGroupId: data.transferGroupId.present
          ? data.transferGroupId.value
          : this.transferGroupId,
      transferDirection: data.transferDirection.present
          ? data.transferDirection.value
          : this.transferDirection,
      origin: data.origin.present ? data.origin.value : this.origin,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransaction(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('draftState: $draftState, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('source: $source, ')
          ..write('merchant: $merchant, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('transferGroupId: $transferGroupId, ')
          ..write('transferDirection: $transferDirection, ')
          ..write('origin: $origin, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      accountId,
      categoryId,
      type,
      status,
      draftState,
      amount,
      currency,
      source,
      merchant,
      note,
      occurredAt,
      transferGroupId,
      transferDirection,
      origin,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTransaction &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.type == this.type &&
          other.status == this.status &&
          other.draftState == this.draftState &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.source == this.source &&
          other.merchant == this.merchant &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.transferGroupId == this.transferGroupId &&
          other.transferDirection == this.transferDirection &&
          other.origin == this.origin &&
          other.deletedAt == this.deletedAt);
}

class LocalTransactionsCompanion extends UpdateCompanion<LocalTransaction> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> accountId;
  final Value<String?> categoryId;
  final Value<String> type;
  final Value<String> status;
  final Value<String?> draftState;
  final Value<double> amount;
  final Value<String> currency;
  final Value<String?> source;
  final Value<String?> merchant;
  final Value<String?> note;
  final Value<DateTime> occurredAt;
  final Value<String?> transferGroupId;
  final Value<String?> transferDirection;
  final Value<String> origin;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalTransactionsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.draftState = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.source = const Value.absent(),
    this.merchant = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.transferGroupId = const Value.absent(),
    this.transferDirection = const Value.absent(),
    this.origin = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTransactionsCompanion.insert({
    required String id,
    required String workspaceId,
    required String accountId,
    this.categoryId = const Value.absent(),
    required String type,
    required String status,
    this.draftState = const Value.absent(),
    required double amount,
    required String currency,
    this.source = const Value.absent(),
    this.merchant = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime occurredAt,
    this.transferGroupId = const Value.absent(),
    this.transferDirection = const Value.absent(),
    this.origin = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        accountId = Value(accountId),
        type = Value(type),
        status = Value(status),
        amount = Value(amount),
        currency = Value(currency),
        occurredAt = Value(occurredAt);
  static Insertable<LocalTransaction> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? accountId,
    Expression<String>? categoryId,
    Expression<String>? type,
    Expression<String>? status,
    Expression<String>? draftState,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<String>? source,
    Expression<String>? merchant,
    Expression<String>? note,
    Expression<DateTime>? occurredAt,
    Expression<String>? transferGroupId,
    Expression<String>? transferDirection,
    Expression<String>? origin,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (draftState != null) 'draft_state': draftState,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (source != null) 'source': source,
      if (merchant != null) 'merchant': merchant,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (transferGroupId != null) 'transfer_group_id': transferGroupId,
      if (transferDirection != null) 'transfer_direction': transferDirection,
      if (origin != null) 'origin': origin,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTransactionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? accountId,
      Value<String?>? categoryId,
      Value<String>? type,
      Value<String>? status,
      Value<String?>? draftState,
      Value<double>? amount,
      Value<String>? currency,
      Value<String?>? source,
      Value<String?>? merchant,
      Value<String?>? note,
      Value<DateTime>? occurredAt,
      Value<String?>? transferGroupId,
      Value<String?>? transferDirection,
      Value<String>? origin,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalTransactionsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      status: status ?? this.status,
      draftState: draftState ?? this.draftState,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      source: source ?? this.source,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      transferGroupId: transferGroupId ?? this.transferGroupId,
      transferDirection: transferDirection ?? this.transferDirection,
      origin: origin ?? this.origin,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (draftState.present) {
      map['draft_state'] = Variable<String>(draftState.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (transferGroupId.present) {
      map['transfer_group_id'] = Variable<String>(transferGroupId.value);
    }
    if (transferDirection.present) {
      map['transfer_direction'] = Variable<String>(transferDirection.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('draftState: $draftState, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('source: $source, ')
          ..write('merchant: $merchant, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('transferGroupId: $transferGroupId, ')
          ..write('transferDirection: $transferDirection, ')
          ..write('origin: $origin, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetTableMeta =
      const VerificationMeta('targetTable');
  @override
  late final GeneratedColumn<String> targetTable = GeneratedColumn<String>(
      'target_table', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
      'action', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        targetTable,
        recordId,
        action,
        payload,
        createdAt,
        status,
        attempts,
        lastError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(Insertable<SyncOutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('target_table')) {
      context.handle(
          _targetTableMeta,
          targetTable.isAcceptableOrUnknown(
              data['target_table']!, _targetTableMeta));
    } else if (isInserting) {
      context.missing(_targetTableMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(_actionMeta,
          action.isAcceptableOrUnknown(data['action']!, _actionMeta));
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      targetTable: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_table'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      action: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String id;
  final String targetTable;
  final String recordId;
  final String action;
  final String payload;
  final DateTime createdAt;
  final String status;
  final int attempts;
  final String? lastError;
  const SyncOutboxData(
      {required this.id,
      required this.targetTable,
      required this.recordId,
      required this.action,
      required this.payload,
      required this.createdAt,
      required this.status,
      required this.attempts,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['target_table'] = Variable<String>(targetTable);
    map['record_id'] = Variable<String>(recordId);
    map['action'] = Variable<String>(action);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      targetTable: Value(targetTable),
      recordId: Value(recordId),
      action: Value(action),
      payload: Value(payload),
      createdAt: Value(createdAt),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncOutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      id: serializer.fromJson<String>(json['id']),
      targetTable: serializer.fromJson<String>(json['targetTable']),
      recordId: serializer.fromJson<String>(json['recordId']),
      action: serializer.fromJson<String>(json['action']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'targetTable': serializer.toJson<String>(targetTable),
      'recordId': serializer.toJson<String>(recordId),
      'action': serializer.toJson<String>(action),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncOutboxData copyWith(
          {String? id,
          String? targetTable,
          String? recordId,
          String? action,
          String? payload,
          DateTime? createdAt,
          String? status,
          int? attempts,
          Value<String?> lastError = const Value.absent()}) =>
      SyncOutboxData(
        id: id ?? this.id,
        targetTable: targetTable ?? this.targetTable,
        recordId: recordId ?? this.recordId,
        action: action ?? this.action,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      id: data.id.present ? data.id.value : this.id,
      targetTable:
          data.targetTable.present ? data.targetTable.value : this.targetTable,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      action: data.action.present ? data.action.value : this.action,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('recordId: $recordId, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, targetTable, recordId, action, payload,
      createdAt, status, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.id == this.id &&
          other.targetTable == this.targetTable &&
          other.recordId == this.recordId &&
          other.action == this.action &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> id;
  final Value<String> targetTable;
  final Value<String> recordId;
  final Value<String> action;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.targetTable = const Value.absent(),
    this.recordId = const Value.absent(),
    this.action = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String id,
    required String targetTable,
    required String recordId,
    required String action,
    required String payload,
    required DateTime createdAt,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        targetTable = Value(targetTable),
        recordId = Value(recordId),
        action = Value(action),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? id,
    Expression<String>? targetTable,
    Expression<String>? recordId,
    Expression<String>? action,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetTable != null) 'target_table': targetTable,
      if (recordId != null) 'record_id': recordId,
      if (action != null) 'action': action,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith(
      {Value<String>? id,
      Value<String>? targetTable,
      Value<String>? recordId,
      Value<String>? action,
      Value<String>? payload,
      Value<DateTime>? createdAt,
      Value<String>? status,
      Value<int>? attempts,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      targetTable: targetTable ?? this.targetTable,
      recordId: recordId ?? this.recordId,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (targetTable.present) {
      map['target_table'] = Variable<String>(targetTable.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('targetTable: $targetTable, ')
          ..write('recordId: $recordId, ')
          ..write('action: $action, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProjectsTable extends LocalProjects
    with TableInfo<$LocalProjectsTable, LocalProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('berjalan'));
  static const VerificationMeta _startedOnMeta =
      const VerificationMeta('startedOn');
  @override
  late final GeneratedColumn<DateTime> startedOn = GeneratedColumn<DateTime>(
      'started_on', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _deadlineMeta =
      const VerificationMeta('deadline');
  @override
  late final GeneratedColumn<DateTime> deadline = GeneratedColumn<DateTime>(
      'deadline', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _clientNameMeta =
      const VerificationMeta('clientName');
  @override
  late final GeneratedColumn<String> clientName = GeneratedColumn<String>(
      'client_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contractValueMeta =
      const VerificationMeta('contractValue');
  @override
  late final GeneratedColumn<double> contractValue = GeneratedColumn<double>(
      'contract_value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _platformFeePercentMeta =
      const VerificationMeta('platformFeePercent');
  @override
  late final GeneratedColumn<double> platformFeePercent =
      GeneratedColumn<double>('platform_fee_percent', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _feeModeMeta =
      const VerificationMeta('feeMode');
  @override
  late final GeneratedColumn<String> feeMode = GeneratedColumn<String>(
      'fee_mode', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _semesterMeta =
      const VerificationMeta('semester');
  @override
  late final GeneratedColumn<int> semester = GeneratedColumn<int>(
      'semester', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _courseCodeMeta =
      const VerificationMeta('courseCode');
  @override
  late final GeneratedColumn<String> courseCode = GeneratedColumn<String>(
      'course_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _creditsMeta =
      const VerificationMeta('credits');
  @override
  late final GeneratedColumn<int> credits = GeneratedColumn<int>(
      'credits', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _stipendAmountMeta =
      const VerificationMeta('stipendAmount');
  @override
  late final GeneratedColumn<double> stipendAmount = GeneratedColumn<double>(
      'stipend_amount', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _stipendDayMeta =
      const VerificationMeta('stipendDay');
  @override
  late final GeneratedColumn<int> stipendDay = GeneratedColumn<int>(
      'stipend_day', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        kind,
        name,
        description,
        status,
        startedOn,
        deadline,
        color,
        clientName,
        contractValue,
        currency,
        platformFeePercent,
        feeMode,
        semester,
        courseCode,
        credits,
        stipendAmount,
        stipendDay,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_projects';
  @override
  VerificationContext validateIntegrity(Insertable<LocalProject> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('started_on')) {
      context.handle(_startedOnMeta,
          startedOn.isAcceptableOrUnknown(data['started_on']!, _startedOnMeta));
    }
    if (data.containsKey('deadline')) {
      context.handle(_deadlineMeta,
          deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('client_name')) {
      context.handle(
          _clientNameMeta,
          clientName.isAcceptableOrUnknown(
              data['client_name']!, _clientNameMeta));
    }
    if (data.containsKey('contract_value')) {
      context.handle(
          _contractValueMeta,
          contractValue.isAcceptableOrUnknown(
              data['contract_value']!, _contractValueMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('platform_fee_percent')) {
      context.handle(
          _platformFeePercentMeta,
          platformFeePercent.isAcceptableOrUnknown(
              data['platform_fee_percent']!, _platformFeePercentMeta));
    }
    if (data.containsKey('fee_mode')) {
      context.handle(_feeModeMeta,
          feeMode.isAcceptableOrUnknown(data['fee_mode']!, _feeModeMeta));
    }
    if (data.containsKey('semester')) {
      context.handle(_semesterMeta,
          semester.isAcceptableOrUnknown(data['semester']!, _semesterMeta));
    }
    if (data.containsKey('course_code')) {
      context.handle(
          _courseCodeMeta,
          courseCode.isAcceptableOrUnknown(
              data['course_code']!, _courseCodeMeta));
    }
    if (data.containsKey('credits')) {
      context.handle(_creditsMeta,
          credits.isAcceptableOrUnknown(data['credits']!, _creditsMeta));
    }
    if (data.containsKey('stipend_amount')) {
      context.handle(
          _stipendAmountMeta,
          stipendAmount.isAcceptableOrUnknown(
              data['stipend_amount']!, _stipendAmountMeta));
    }
    if (data.containsKey('stipend_day')) {
      context.handle(
          _stipendDayMeta,
          stipendDay.isAcceptableOrUnknown(
              data['stipend_day']!, _stipendDayMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProject(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      startedOn: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_on']),
      deadline: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deadline']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color']),
      clientName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_name']),
      contractValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}contract_value']),
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency']),
      platformFeePercent: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}platform_fee_percent']),
      feeMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fee_mode']),
      semester: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}semester']),
      courseCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_code']),
      credits: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}credits']),
      stipendAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}stipend_amount']),
      stipendDay: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}stipend_day']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalProjectsTable createAlias(String alias) {
    return $LocalProjectsTable(attachedDatabase, alias);
  }
}

class LocalProject extends DataClass implements Insertable<LocalProject> {
  final String id;
  final String workspaceId;
  final String kind;
  final String name;
  final String? description;
  final String status;
  final DateTime? startedOn;
  final DateTime? deadline;
  final String? color;
  final String? clientName;
  final double? contractValue;
  final String? currency;
  final double? platformFeePercent;
  final String? feeMode;
  final int? semester;
  final String? courseCode;
  final int? credits;
  final double? stipendAmount;
  final int? stipendDay;
  final DateTime? deletedAt;
  const LocalProject(
      {required this.id,
      required this.workspaceId,
      required this.kind,
      required this.name,
      this.description,
      required this.status,
      this.startedOn,
      this.deadline,
      this.color,
      this.clientName,
      this.contractValue,
      this.currency,
      this.platformFeePercent,
      this.feeMode,
      this.semester,
      this.courseCode,
      this.credits,
      this.stipendAmount,
      this.stipendDay,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || startedOn != null) {
      map['started_on'] = Variable<DateTime>(startedOn);
    }
    if (!nullToAbsent || deadline != null) {
      map['deadline'] = Variable<DateTime>(deadline);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || clientName != null) {
      map['client_name'] = Variable<String>(clientName);
    }
    if (!nullToAbsent || contractValue != null) {
      map['contract_value'] = Variable<double>(contractValue);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || platformFeePercent != null) {
      map['platform_fee_percent'] = Variable<double>(platformFeePercent);
    }
    if (!nullToAbsent || feeMode != null) {
      map['fee_mode'] = Variable<String>(feeMode);
    }
    if (!nullToAbsent || semester != null) {
      map['semester'] = Variable<int>(semester);
    }
    if (!nullToAbsent || courseCode != null) {
      map['course_code'] = Variable<String>(courseCode);
    }
    if (!nullToAbsent || credits != null) {
      map['credits'] = Variable<int>(credits);
    }
    if (!nullToAbsent || stipendAmount != null) {
      map['stipend_amount'] = Variable<double>(stipendAmount);
    }
    if (!nullToAbsent || stipendDay != null) {
      map['stipend_day'] = Variable<int>(stipendDay);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalProjectsCompanion toCompanion(bool nullToAbsent) {
    return LocalProjectsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      kind: Value(kind),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      startedOn: startedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(startedOn),
      deadline: deadline == null && nullToAbsent
          ? const Value.absent()
          : Value(deadline),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      clientName: clientName == null && nullToAbsent
          ? const Value.absent()
          : Value(clientName),
      contractValue: contractValue == null && nullToAbsent
          ? const Value.absent()
          : Value(contractValue),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      platformFeePercent: platformFeePercent == null && nullToAbsent
          ? const Value.absent()
          : Value(platformFeePercent),
      feeMode: feeMode == null && nullToAbsent
          ? const Value.absent()
          : Value(feeMode),
      semester: semester == null && nullToAbsent
          ? const Value.absent()
          : Value(semester),
      courseCode: courseCode == null && nullToAbsent
          ? const Value.absent()
          : Value(courseCode),
      credits: credits == null && nullToAbsent
          ? const Value.absent()
          : Value(credits),
      stipendAmount: stipendAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(stipendAmount),
      stipendDay: stipendDay == null && nullToAbsent
          ? const Value.absent()
          : Value(stipendDay),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalProject.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProject(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      startedOn: serializer.fromJson<DateTime?>(json['startedOn']),
      deadline: serializer.fromJson<DateTime?>(json['deadline']),
      color: serializer.fromJson<String?>(json['color']),
      clientName: serializer.fromJson<String?>(json['clientName']),
      contractValue: serializer.fromJson<double?>(json['contractValue']),
      currency: serializer.fromJson<String?>(json['currency']),
      platformFeePercent:
          serializer.fromJson<double?>(json['platformFeePercent']),
      feeMode: serializer.fromJson<String?>(json['feeMode']),
      semester: serializer.fromJson<int?>(json['semester']),
      courseCode: serializer.fromJson<String?>(json['courseCode']),
      credits: serializer.fromJson<int?>(json['credits']),
      stipendAmount: serializer.fromJson<double?>(json['stipendAmount']),
      stipendDay: serializer.fromJson<int?>(json['stipendDay']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
      'startedOn': serializer.toJson<DateTime?>(startedOn),
      'deadline': serializer.toJson<DateTime?>(deadline),
      'color': serializer.toJson<String?>(color),
      'clientName': serializer.toJson<String?>(clientName),
      'contractValue': serializer.toJson<double?>(contractValue),
      'currency': serializer.toJson<String?>(currency),
      'platformFeePercent': serializer.toJson<double?>(platformFeePercent),
      'feeMode': serializer.toJson<String?>(feeMode),
      'semester': serializer.toJson<int?>(semester),
      'courseCode': serializer.toJson<String?>(courseCode),
      'credits': serializer.toJson<int?>(credits),
      'stipendAmount': serializer.toJson<double?>(stipendAmount),
      'stipendDay': serializer.toJson<int?>(stipendDay),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalProject copyWith(
          {String? id,
          String? workspaceId,
          String? kind,
          String? name,
          Value<String?> description = const Value.absent(),
          String? status,
          Value<DateTime?> startedOn = const Value.absent(),
          Value<DateTime?> deadline = const Value.absent(),
          Value<String?> color = const Value.absent(),
          Value<String?> clientName = const Value.absent(),
          Value<double?> contractValue = const Value.absent(),
          Value<String?> currency = const Value.absent(),
          Value<double?> platformFeePercent = const Value.absent(),
          Value<String?> feeMode = const Value.absent(),
          Value<int?> semester = const Value.absent(),
          Value<String?> courseCode = const Value.absent(),
          Value<int?> credits = const Value.absent(),
          Value<double?> stipendAmount = const Value.absent(),
          Value<int?> stipendDay = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalProject(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        kind: kind ?? this.kind,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        status: status ?? this.status,
        startedOn: startedOn.present ? startedOn.value : this.startedOn,
        deadline: deadline.present ? deadline.value : this.deadline,
        color: color.present ? color.value : this.color,
        clientName: clientName.present ? clientName.value : this.clientName,
        contractValue:
            contractValue.present ? contractValue.value : this.contractValue,
        currency: currency.present ? currency.value : this.currency,
        platformFeePercent: platformFeePercent.present
            ? platformFeePercent.value
            : this.platformFeePercent,
        feeMode: feeMode.present ? feeMode.value : this.feeMode,
        semester: semester.present ? semester.value : this.semester,
        courseCode: courseCode.present ? courseCode.value : this.courseCode,
        credits: credits.present ? credits.value : this.credits,
        stipendAmount:
            stipendAmount.present ? stipendAmount.value : this.stipendAmount,
        stipendDay: stipendDay.present ? stipendDay.value : this.stipendDay,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalProject copyWithCompanion(LocalProjectsCompanion data) {
    return LocalProject(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      status: data.status.present ? data.status.value : this.status,
      startedOn: data.startedOn.present ? data.startedOn.value : this.startedOn,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      color: data.color.present ? data.color.value : this.color,
      clientName:
          data.clientName.present ? data.clientName.value : this.clientName,
      contractValue: data.contractValue.present
          ? data.contractValue.value
          : this.contractValue,
      currency: data.currency.present ? data.currency.value : this.currency,
      platformFeePercent: data.platformFeePercent.present
          ? data.platformFeePercent.value
          : this.platformFeePercent,
      feeMode: data.feeMode.present ? data.feeMode.value : this.feeMode,
      semester: data.semester.present ? data.semester.value : this.semester,
      courseCode:
          data.courseCode.present ? data.courseCode.value : this.courseCode,
      credits: data.credits.present ? data.credits.value : this.credits,
      stipendAmount: data.stipendAmount.present
          ? data.stipendAmount.value
          : this.stipendAmount,
      stipendDay:
          data.stipendDay.present ? data.stipendDay.value : this.stipendDay,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProject(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('startedOn: $startedOn, ')
          ..write('deadline: $deadline, ')
          ..write('color: $color, ')
          ..write('clientName: $clientName, ')
          ..write('contractValue: $contractValue, ')
          ..write('currency: $currency, ')
          ..write('platformFeePercent: $platformFeePercent, ')
          ..write('feeMode: $feeMode, ')
          ..write('semester: $semester, ')
          ..write('courseCode: $courseCode, ')
          ..write('credits: $credits, ')
          ..write('stipendAmount: $stipendAmount, ')
          ..write('stipendDay: $stipendDay, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      kind,
      name,
      description,
      status,
      startedOn,
      deadline,
      color,
      clientName,
      contractValue,
      currency,
      platformFeePercent,
      feeMode,
      semester,
      courseCode,
      credits,
      stipendAmount,
      stipendDay,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProject &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.description == this.description &&
          other.status == this.status &&
          other.startedOn == this.startedOn &&
          other.deadline == this.deadline &&
          other.color == this.color &&
          other.clientName == this.clientName &&
          other.contractValue == this.contractValue &&
          other.currency == this.currency &&
          other.platformFeePercent == this.platformFeePercent &&
          other.feeMode == this.feeMode &&
          other.semester == this.semester &&
          other.courseCode == this.courseCode &&
          other.credits == this.credits &&
          other.stipendAmount == this.stipendAmount &&
          other.stipendDay == this.stipendDay &&
          other.deletedAt == this.deletedAt);
}

class LocalProjectsCompanion extends UpdateCompanion<LocalProject> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> status;
  final Value<DateTime?> startedOn;
  final Value<DateTime?> deadline;
  final Value<String?> color;
  final Value<String?> clientName;
  final Value<double?> contractValue;
  final Value<String?> currency;
  final Value<double?> platformFeePercent;
  final Value<String?> feeMode;
  final Value<int?> semester;
  final Value<String?> courseCode;
  final Value<int?> credits;
  final Value<double?> stipendAmount;
  final Value<int?> stipendDay;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalProjectsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.deadline = const Value.absent(),
    this.color = const Value.absent(),
    this.clientName = const Value.absent(),
    this.contractValue = const Value.absent(),
    this.currency = const Value.absent(),
    this.platformFeePercent = const Value.absent(),
    this.feeMode = const Value.absent(),
    this.semester = const Value.absent(),
    this.courseCode = const Value.absent(),
    this.credits = const Value.absent(),
    this.stipendAmount = const Value.absent(),
    this.stipendDay = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProjectsCompanion.insert({
    required String id,
    required String workspaceId,
    required String kind,
    required String name,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.deadline = const Value.absent(),
    this.color = const Value.absent(),
    this.clientName = const Value.absent(),
    this.contractValue = const Value.absent(),
    this.currency = const Value.absent(),
    this.platformFeePercent = const Value.absent(),
    this.feeMode = const Value.absent(),
    this.semester = const Value.absent(),
    this.courseCode = const Value.absent(),
    this.credits = const Value.absent(),
    this.stipendAmount = const Value.absent(),
    this.stipendDay = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        kind = Value(kind),
        name = Value(name);
  static Insertable<LocalProject> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? status,
    Expression<DateTime>? startedOn,
    Expression<DateTime>? deadline,
    Expression<String>? color,
    Expression<String>? clientName,
    Expression<double>? contractValue,
    Expression<String>? currency,
    Expression<double>? platformFeePercent,
    Expression<String>? feeMode,
    Expression<int>? semester,
    Expression<String>? courseCode,
    Expression<int>? credits,
    Expression<double>? stipendAmount,
    Expression<int>? stipendDay,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (startedOn != null) 'started_on': startedOn,
      if (deadline != null) 'deadline': deadline,
      if (color != null) 'color': color,
      if (clientName != null) 'client_name': clientName,
      if (contractValue != null) 'contract_value': contractValue,
      if (currency != null) 'currency': currency,
      if (platformFeePercent != null)
        'platform_fee_percent': platformFeePercent,
      if (feeMode != null) 'fee_mode': feeMode,
      if (semester != null) 'semester': semester,
      if (courseCode != null) 'course_code': courseCode,
      if (credits != null) 'credits': credits,
      if (stipendAmount != null) 'stipend_amount': stipendAmount,
      if (stipendDay != null) 'stipend_day': stipendDay,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProjectsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? kind,
      Value<String>? name,
      Value<String?>? description,
      Value<String>? status,
      Value<DateTime?>? startedOn,
      Value<DateTime?>? deadline,
      Value<String?>? color,
      Value<String?>? clientName,
      Value<double?>? contractValue,
      Value<String?>? currency,
      Value<double?>? platformFeePercent,
      Value<String?>? feeMode,
      Value<int?>? semester,
      Value<String?>? courseCode,
      Value<int?>? credits,
      Value<double?>? stipendAmount,
      Value<int?>? stipendDay,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalProjectsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      startedOn: startedOn ?? this.startedOn,
      deadline: deadline ?? this.deadline,
      color: color ?? this.color,
      clientName: clientName ?? this.clientName,
      contractValue: contractValue ?? this.contractValue,
      currency: currency ?? this.currency,
      platformFeePercent: platformFeePercent ?? this.platformFeePercent,
      feeMode: feeMode ?? this.feeMode,
      semester: semester ?? this.semester,
      courseCode: courseCode ?? this.courseCode,
      credits: credits ?? this.credits,
      stipendAmount: stipendAmount ?? this.stipendAmount,
      stipendDay: stipendDay ?? this.stipendDay,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedOn.present) {
      map['started_on'] = Variable<DateTime>(startedOn.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<DateTime>(deadline.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (clientName.present) {
      map['client_name'] = Variable<String>(clientName.value);
    }
    if (contractValue.present) {
      map['contract_value'] = Variable<double>(contractValue.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (platformFeePercent.present) {
      map['platform_fee_percent'] = Variable<double>(platformFeePercent.value);
    }
    if (feeMode.present) {
      map['fee_mode'] = Variable<String>(feeMode.value);
    }
    if (semester.present) {
      map['semester'] = Variable<int>(semester.value);
    }
    if (courseCode.present) {
      map['course_code'] = Variable<String>(courseCode.value);
    }
    if (credits.present) {
      map['credits'] = Variable<int>(credits.value);
    }
    if (stipendAmount.present) {
      map['stipend_amount'] = Variable<double>(stipendAmount.value);
    }
    if (stipendDay.present) {
      map['stipend_day'] = Variable<int>(stipendDay.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProjectsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('startedOn: $startedOn, ')
          ..write('deadline: $deadline, ')
          ..write('color: $color, ')
          ..write('clientName: $clientName, ')
          ..write('contractValue: $contractValue, ')
          ..write('currency: $currency, ')
          ..write('platformFeePercent: $platformFeePercent, ')
          ..write('feeMode: $feeMode, ')
          ..write('semester: $semester, ')
          ..write('courseCode: $courseCode, ')
          ..write('credits: $credits, ')
          ..write('stipendAmount: $stipendAmount, ')
          ..write('stipendDay: $stipendDay, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTasksTable extends LocalTasks
    with TableInfo<$LocalTasksTable, LocalTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('todo'));
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('sedang'));
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
      'due_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _dueIsDateOnlyMeta =
      const VerificationMeta('dueIsDateOnly');
  @override
  late final GeneratedColumn<bool> dueIsDateOnly = GeneratedColumn<bool>(
      'due_is_date_only', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("due_is_date_only" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _milestonePaymentIdMeta =
      const VerificationMeta('milestonePaymentId');
  @override
  late final GeneratedColumn<String> milestonePaymentId =
      GeneratedColumn<String>('milestone_payment_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        projectId,
        kind,
        title,
        description,
        status,
        priority,
        dueAt,
        dueIsDateOnly,
        completedAt,
        milestonePaymentId,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_tasks';
  @override
  VerificationContext validateIntegrity(Insertable<LocalTask> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('due_at')) {
      context.handle(
          _dueAtMeta, dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta));
    }
    if (data.containsKey('due_is_date_only')) {
      context.handle(
          _dueIsDateOnlyMeta,
          dueIsDateOnly.isAcceptableOrUnknown(
              data['due_is_date_only']!, _dueIsDateOnlyMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('milestone_payment_id')) {
      context.handle(
          _milestonePaymentIdMeta,
          milestonePaymentId.isAcceptableOrUnknown(
              data['milestone_payment_id']!, _milestonePaymentIdMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTask(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id']),
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority'])!,
      dueAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}due_at']),
      dueIsDateOnly: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}due_is_date_only'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      milestonePaymentId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}milestone_payment_id']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalTasksTable createAlias(String alias) {
    return $LocalTasksTable(attachedDatabase, alias);
  }
}

class LocalTask extends DataClass implements Insertable<LocalTask> {
  final String id;
  final String workspaceId;
  final String? projectId;
  final String kind;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? dueAt;
  final bool dueIsDateOnly;
  final DateTime? completedAt;
  final String? milestonePaymentId;
  final DateTime? deletedAt;
  const LocalTask(
      {required this.id,
      required this.workspaceId,
      this.projectId,
      required this.kind,
      required this.title,
      this.description,
      required this.status,
      required this.priority,
      this.dueAt,
      required this.dueIsDateOnly,
      this.completedAt,
      this.milestonePaymentId,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['due_is_date_only'] = Variable<bool>(dueIsDateOnly);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || milestonePaymentId != null) {
      map['milestone_payment_id'] = Variable<String>(milestonePaymentId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalTasksCompanion toCompanion(bool nullToAbsent) {
    return LocalTasksCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      kind: Value(kind),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      priority: Value(priority),
      dueAt:
          dueAt == null && nullToAbsent ? const Value.absent() : Value(dueAt),
      dueIsDateOnly: Value(dueIsDateOnly),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      milestonePaymentId: milestonePaymentId == null && nullToAbsent
          ? const Value.absent()
          : Value(milestonePaymentId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalTask.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTask(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<String>(json['priority']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      dueIsDateOnly: serializer.fromJson<bool>(json['dueIsDateOnly']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      milestonePaymentId:
          serializer.fromJson<String?>(json['milestonePaymentId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'projectId': serializer.toJson<String?>(projectId),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<String>(priority),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'dueIsDateOnly': serializer.toJson<bool>(dueIsDateOnly),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'milestonePaymentId': serializer.toJson<String?>(milestonePaymentId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalTask copyWith(
          {String? id,
          String? workspaceId,
          Value<String?> projectId = const Value.absent(),
          String? kind,
          String? title,
          Value<String?> description = const Value.absent(),
          String? status,
          String? priority,
          Value<DateTime?> dueAt = const Value.absent(),
          bool? dueIsDateOnly,
          Value<DateTime?> completedAt = const Value.absent(),
          Value<String?> milestonePaymentId = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalTask(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        projectId: projectId.present ? projectId.value : this.projectId,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        dueAt: dueAt.present ? dueAt.value : this.dueAt,
        dueIsDateOnly: dueIsDateOnly ?? this.dueIsDateOnly,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        milestonePaymentId: milestonePaymentId.present
            ? milestonePaymentId.value
            : this.milestonePaymentId,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalTask copyWithCompanion(LocalTasksCompanion data) {
    return LocalTask(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      dueIsDateOnly: data.dueIsDateOnly.present
          ? data.dueIsDateOnly.value
          : this.dueIsDateOnly,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      milestonePaymentId: data.milestonePaymentId.present
          ? data.milestonePaymentId.value
          : this.milestonePaymentId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTask(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('dueAt: $dueAt, ')
          ..write('dueIsDateOnly: $dueIsDateOnly, ')
          ..write('completedAt: $completedAt, ')
          ..write('milestonePaymentId: $milestonePaymentId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      projectId,
      kind,
      title,
      description,
      status,
      priority,
      dueAt,
      dueIsDateOnly,
      completedAt,
      milestonePaymentId,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTask &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.projectId == this.projectId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.description == this.description &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.dueAt == this.dueAt &&
          other.dueIsDateOnly == this.dueIsDateOnly &&
          other.completedAt == this.completedAt &&
          other.milestonePaymentId == this.milestonePaymentId &&
          other.deletedAt == this.deletedAt);
}

class LocalTasksCompanion extends UpdateCompanion<LocalTask> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String?> projectId;
  final Value<String> kind;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> status;
  final Value<String> priority;
  final Value<DateTime?> dueAt;
  final Value<bool> dueIsDateOnly;
  final Value<DateTime?> completedAt;
  final Value<String?> milestonePaymentId;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalTasksCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.dueIsDateOnly = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.milestonePaymentId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTasksCompanion.insert({
    required String id,
    required String workspaceId,
    this.projectId = const Value.absent(),
    required String kind,
    required String title,
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.dueIsDateOnly = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.milestonePaymentId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        kind = Value(kind),
        title = Value(title);
  static Insertable<LocalTask> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? projectId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? status,
    Expression<String>? priority,
    Expression<DateTime>? dueAt,
    Expression<bool>? dueIsDateOnly,
    Expression<DateTime>? completedAt,
    Expression<String>? milestonePaymentId,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (projectId != null) 'project_id': projectId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (dueAt != null) 'due_at': dueAt,
      if (dueIsDateOnly != null) 'due_is_date_only': dueIsDateOnly,
      if (completedAt != null) 'completed_at': completedAt,
      if (milestonePaymentId != null)
        'milestone_payment_id': milestonePaymentId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTasksCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String?>? projectId,
      Value<String>? kind,
      Value<String>? title,
      Value<String?>? description,
      Value<String>? status,
      Value<String>? priority,
      Value<DateTime?>? dueAt,
      Value<bool>? dueIsDateOnly,
      Value<DateTime?>? completedAt,
      Value<String?>? milestonePaymentId,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalTasksCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      projectId: projectId ?? this.projectId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      dueIsDateOnly: dueIsDateOnly ?? this.dueIsDateOnly,
      completedAt: completedAt ?? this.completedAt,
      milestonePaymentId: milestonePaymentId ?? this.milestonePaymentId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (dueIsDateOnly.present) {
      map['due_is_date_only'] = Variable<bool>(dueIsDateOnly.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (milestonePaymentId.present) {
      map['milestone_payment_id'] = Variable<String>(milestonePaymentId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTasksCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('dueAt: $dueAt, ')
          ..write('dueIsDateOnly: $dueIsDateOnly, ')
          ..write('completedAt: $completedAt, ')
          ..write('milestonePaymentId: $milestonePaymentId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTaskChecklistItemsTable extends LocalTaskChecklistItems
    with TableInfo<$LocalTaskChecklistItemsTable, LocalTaskChecklistItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTaskChecklistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _textContentMeta =
      const VerificationMeta('textContent');
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
      'text_content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
      'done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("done" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, taskId, textContent, done, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_task_checklist_items';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalTaskChecklistItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('text_content')) {
      context.handle(
          _textContentMeta,
          textContent.isAcceptableOrUnknown(
              data['text_content']!, _textContentMeta));
    } else if (isInserting) {
      context.missing(_textContentMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
          _doneMeta, done.isAcceptableOrUnknown(data['done']!, _doneMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTaskChecklistItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTaskChecklistItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      textContent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text_content'])!,
      done: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}done'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
    );
  }

  @override
  $LocalTaskChecklistItemsTable createAlias(String alias) {
    return $LocalTaskChecklistItemsTable(attachedDatabase, alias);
  }
}

class LocalTaskChecklistItem extends DataClass
    implements Insertable<LocalTaskChecklistItem> {
  final String id;
  final String taskId;
  final String textContent;
  final bool done;
  final int sortOrder;
  const LocalTaskChecklistItem(
      {required this.id,
      required this.taskId,
      required this.textContent,
      required this.done,
      required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['text_content'] = Variable<String>(textContent);
    map['done'] = Variable<bool>(done);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  LocalTaskChecklistItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalTaskChecklistItemsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      textContent: Value(textContent),
      done: Value(done),
      sortOrder: Value(sortOrder),
    );
  }

  factory LocalTaskChecklistItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTaskChecklistItem(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      textContent: serializer.fromJson<String>(json['textContent']),
      done: serializer.fromJson<bool>(json['done']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'textContent': serializer.toJson<String>(textContent),
      'done': serializer.toJson<bool>(done),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  LocalTaskChecklistItem copyWith(
          {String? id,
          String? taskId,
          String? textContent,
          bool? done,
          int? sortOrder}) =>
      LocalTaskChecklistItem(
        id: id ?? this.id,
        taskId: taskId ?? this.taskId,
        textContent: textContent ?? this.textContent,
        done: done ?? this.done,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  LocalTaskChecklistItem copyWithCompanion(
      LocalTaskChecklistItemsCompanion data) {
    return LocalTaskChecklistItem(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      textContent:
          data.textContent.present ? data.textContent.value : this.textContent,
      done: data.done.present ? data.done.value : this.done,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTaskChecklistItem(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('textContent: $textContent, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taskId, textContent, done, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTaskChecklistItem &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.textContent == this.textContent &&
          other.done == this.done &&
          other.sortOrder == this.sortOrder);
}

class LocalTaskChecklistItemsCompanion
    extends UpdateCompanion<LocalTaskChecklistItem> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> textContent;
  final Value<bool> done;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const LocalTaskChecklistItemsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.textContent = const Value.absent(),
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTaskChecklistItemsCompanion.insert({
    required String id,
    required String taskId,
    required String textContent,
    this.done = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        taskId = Value(taskId),
        textContent = Value(textContent);
  static Insertable<LocalTaskChecklistItem> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? textContent,
    Expression<bool>? done,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (textContent != null) 'text_content': textContent,
      if (done != null) 'done': done,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTaskChecklistItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? taskId,
      Value<String>? textContent,
      Value<bool>? done,
      Value<int>? sortOrder,
      Value<int>? rowid}) {
    return LocalTaskChecklistItemsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      textContent: textContent ?? this.textContent,
      done: done ?? this.done,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTaskChecklistItemsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('textContent: $textContent, ')
          ..write('done: $done, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEventsTable extends LocalEvents
    with TableInfo<$LocalEventsTable, LocalEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startsAtMeta =
      const VerificationMeta('startsAt');
  @override
  late final GeneratedColumn<DateTime> startsAt = GeneratedColumn<DateTime>(
      'starts_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
      'ends_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
      'all_day', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("all_day" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _timezoneMeta =
      const VerificationMeta('timezone');
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
      'timezone', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Asia/Jakarta'));
  static const VerificationMeta _recurrenceMeta =
      const VerificationMeta('recurrence');
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
      'recurrence', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        projectId,
        kind,
        title,
        description,
        location,
        startsAt,
        endsAt,
        allDay,
        timezone,
        recurrence,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_events';
  @override
  VerificationContext validateIntegrity(Insertable<LocalEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('starts_at')) {
      context.handle(_startsAtMeta,
          startsAt.isAcceptableOrUnknown(data['starts_at']!, _startsAtMeta));
    } else if (isInserting) {
      context.missing(_startsAtMeta);
    }
    if (data.containsKey('ends_at')) {
      context.handle(_endsAtMeta,
          endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta));
    } else if (isInserting) {
      context.missing(_endsAtMeta);
    }
    if (data.containsKey('all_day')) {
      context.handle(_allDayMeta,
          allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta));
    }
    if (data.containsKey('timezone')) {
      context.handle(_timezoneMeta,
          timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta));
    }
    if (data.containsKey('recurrence')) {
      context.handle(
          _recurrenceMeta,
          recurrence.isAcceptableOrUnknown(
              data['recurrence']!, _recurrenceMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id']),
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      startsAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}starts_at'])!,
      endsAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ends_at'])!,
      allDay: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}all_day'])!,
      timezone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timezone'])!,
      recurrence: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recurrence']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalEventsTable createAlias(String alias) {
    return $LocalEventsTable(attachedDatabase, alias);
  }
}

class LocalEvent extends DataClass implements Insertable<LocalEvent> {
  final String id;
  final String workspaceId;
  final String? projectId;
  final String kind;
  final String title;
  final String? description;
  final String? location;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String timezone;
  final String? recurrence;
  final DateTime? deletedAt;
  const LocalEvent(
      {required this.id,
      required this.workspaceId,
      this.projectId,
      required this.kind,
      required this.title,
      this.description,
      this.location,
      required this.startsAt,
      required this.endsAt,
      required this.allDay,
      required this.timezone,
      this.recurrence,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['starts_at'] = Variable<DateTime>(startsAt);
    map['ends_at'] = Variable<DateTime>(endsAt);
    map['all_day'] = Variable<bool>(allDay);
    map['timezone'] = Variable<String>(timezone);
    if (!nullToAbsent || recurrence != null) {
      map['recurrence'] = Variable<String>(recurrence);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalEventsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      kind: Value(kind),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      startsAt: Value(startsAt),
      endsAt: Value(endsAt),
      allDay: Value(allDay),
      timezone: Value(timezone),
      recurrence: recurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrence),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEvent(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      location: serializer.fromJson<String?>(json['location']),
      startsAt: serializer.fromJson<DateTime>(json['startsAt']),
      endsAt: serializer.fromJson<DateTime>(json['endsAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      timezone: serializer.fromJson<String>(json['timezone']),
      recurrence: serializer.fromJson<String?>(json['recurrence']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'projectId': serializer.toJson<String?>(projectId),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'location': serializer.toJson<String?>(location),
      'startsAt': serializer.toJson<DateTime>(startsAt),
      'endsAt': serializer.toJson<DateTime>(endsAt),
      'allDay': serializer.toJson<bool>(allDay),
      'timezone': serializer.toJson<String>(timezone),
      'recurrence': serializer.toJson<String?>(recurrence),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalEvent copyWith(
          {String? id,
          String? workspaceId,
          Value<String?> projectId = const Value.absent(),
          String? kind,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<String?> location = const Value.absent(),
          DateTime? startsAt,
          DateTime? endsAt,
          bool? allDay,
          String? timezone,
          Value<String?> recurrence = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalEvent(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        projectId: projectId.present ? projectId.value : this.projectId,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        location: location.present ? location.value : this.location,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        allDay: allDay ?? this.allDay,
        timezone: timezone ?? this.timezone,
        recurrence: recurrence.present ? recurrence.value : this.recurrence,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalEvent copyWithCompanion(LocalEventsCompanion data) {
    return LocalEvent(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      location: data.location.present ? data.location.value : this.location,
      startsAt: data.startsAt.present ? data.startsAt.value : this.startsAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      recurrence:
          data.recurrence.present ? data.recurrence.value : this.recurrence,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEvent(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('location: $location, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('allDay: $allDay, ')
          ..write('timezone: $timezone, ')
          ..write('recurrence: $recurrence, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      projectId,
      kind,
      title,
      description,
      location,
      startsAt,
      endsAt,
      allDay,
      timezone,
      recurrence,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEvent &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.projectId == this.projectId &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.description == this.description &&
          other.location == this.location &&
          other.startsAt == this.startsAt &&
          other.endsAt == this.endsAt &&
          other.allDay == this.allDay &&
          other.timezone == this.timezone &&
          other.recurrence == this.recurrence &&
          other.deletedAt == this.deletedAt);
}

class LocalEventsCompanion extends UpdateCompanion<LocalEvent> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String?> projectId;
  final Value<String> kind;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> location;
  final Value<DateTime> startsAt;
  final Value<DateTime> endsAt;
  final Value<bool> allDay;
  final Value<String> timezone;
  final Value<String?> recurrence;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalEventsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.location = const Value.absent(),
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.timezone = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEventsCompanion.insert({
    required String id,
    required String workspaceId,
    this.projectId = const Value.absent(),
    required String kind,
    required String title,
    this.description = const Value.absent(),
    this.location = const Value.absent(),
    required DateTime startsAt,
    required DateTime endsAt,
    this.allDay = const Value.absent(),
    this.timezone = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        kind = Value(kind),
        title = Value(title),
        startsAt = Value(startsAt),
        endsAt = Value(endsAt);
  static Insertable<LocalEvent> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? projectId,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? location,
    Expression<DateTime>? startsAt,
    Expression<DateTime>? endsAt,
    Expression<bool>? allDay,
    Expression<String>? timezone,
    Expression<String>? recurrence,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (projectId != null) 'project_id': projectId,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (location != null) 'location': location,
      if (startsAt != null) 'starts_at': startsAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (allDay != null) 'all_day': allDay,
      if (timezone != null) 'timezone': timezone,
      if (recurrence != null) 'recurrence': recurrence,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String?>? projectId,
      Value<String>? kind,
      Value<String>? title,
      Value<String?>? description,
      Value<String?>? location,
      Value<DateTime>? startsAt,
      Value<DateTime>? endsAt,
      Value<bool>? allDay,
      Value<String>? timezone,
      Value<String?>? recurrence,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalEventsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      projectId: projectId ?? this.projectId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      allDay: allDay ?? this.allDay,
      timezone: timezone ?? this.timezone,
      recurrence: recurrence ?? this.recurrence,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (startsAt.present) {
      map['starts_at'] = Variable<DateTime>(startsAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEventsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('location: $location, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('allDay: $allDay, ')
          ..write('timezone: $timezone, ')
          ..write('recurrence: $recurrence, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProjectPaymentsTable extends LocalProjectPayments
    with TableInfo<$LocalProjectPaymentsTable, LocalProjectPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProjectPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _dueDateMeta =
      const VerificationMeta('dueDate');
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
      'due_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _paidAmountMeta =
      const VerificationMeta('paidAmount');
  @override
  late final GeneratedColumn<double> paidAmount = GeneratedColumn<double>(
      'paid_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
      'paid_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _transactionIdMeta =
      const VerificationMeta('transactionId');
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
      'transaction_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        projectId,
        label,
        amount,
        dueDate,
        status,
        paidAmount,
        paidAt,
        accountId,
        transactionId,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_project_payments';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalProjectPayment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(_dueDateMeta,
          dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('paid_amount')) {
      context.handle(
          _paidAmountMeta,
          paidAmount.isAcceptableOrUnknown(
              data['paid_amount']!, _paidAmountMeta));
    }
    if (data.containsKey('paid_at')) {
      context.handle(_paidAtMeta,
          paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
          _transactionIdMeta,
          transactionId.isAcceptableOrUnknown(
              data['transaction_id']!, _transactionIdMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProjectPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProjectPayment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      dueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}due_date']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      paidAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}paid_amount'])!,
      paidAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}paid_at']),
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id']),
      transactionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}transaction_id']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalProjectPaymentsTable createAlias(String alias) {
    return $LocalProjectPaymentsTable(attachedDatabase, alias);
  }
}

class LocalProjectPayment extends DataClass
    implements Insertable<LocalProjectPayment> {
  final String id;
  final String workspaceId;
  final String projectId;
  final String label;
  final double amount;
  final DateTime? dueDate;
  final String status;
  final double paidAmount;
  final DateTime? paidAt;
  final String? accountId;
  final String? transactionId;
  final DateTime? deletedAt;
  const LocalProjectPayment(
      {required this.id,
      required this.workspaceId,
      required this.projectId,
      required this.label,
      required this.amount,
      this.dueDate,
      required this.status,
      required this.paidAmount,
      this.paidAt,
      this.accountId,
      this.transactionId,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['project_id'] = Variable<String>(projectId);
    map['label'] = Variable<String>(label);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['status'] = Variable<String>(status);
    map['paid_amount'] = Variable<double>(paidAmount);
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<DateTime>(paidAt);
    }
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalProjectPaymentsCompanion toCompanion(bool nullToAbsent) {
    return LocalProjectPaymentsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      projectId: Value(projectId),
      label: Value(label),
      amount: Value(amount),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      status: Value(status),
      paidAmount: Value(paidAmount),
      paidAt:
          paidAt == null && nullToAbsent ? const Value.absent() : Value(paidAt),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalProjectPayment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProjectPayment(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      label: serializer.fromJson<String>(json['label']),
      amount: serializer.fromJson<double>(json['amount']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      status: serializer.fromJson<String>(json['status']),
      paidAmount: serializer.fromJson<double>(json['paidAmount']),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'projectId': serializer.toJson<String>(projectId),
      'label': serializer.toJson<String>(label),
      'amount': serializer.toJson<double>(amount),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'status': serializer.toJson<String>(status),
      'paidAmount': serializer.toJson<double>(paidAmount),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
      'accountId': serializer.toJson<String?>(accountId),
      'transactionId': serializer.toJson<String?>(transactionId),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalProjectPayment copyWith(
          {String? id,
          String? workspaceId,
          String? projectId,
          String? label,
          double? amount,
          Value<DateTime?> dueDate = const Value.absent(),
          String? status,
          double? paidAmount,
          Value<DateTime?> paidAt = const Value.absent(),
          Value<String?> accountId = const Value.absent(),
          Value<String?> transactionId = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalProjectPayment(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        projectId: projectId ?? this.projectId,
        label: label ?? this.label,
        amount: amount ?? this.amount,
        dueDate: dueDate.present ? dueDate.value : this.dueDate,
        status: status ?? this.status,
        paidAmount: paidAmount ?? this.paidAmount,
        paidAt: paidAt.present ? paidAt.value : this.paidAt,
        accountId: accountId.present ? accountId.value : this.accountId,
        transactionId:
            transactionId.present ? transactionId.value : this.transactionId,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalProjectPayment copyWithCompanion(LocalProjectPaymentsCompanion data) {
    return LocalProjectPayment(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      label: data.label.present ? data.label.value : this.label,
      amount: data.amount.present ? data.amount.value : this.amount,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      status: data.status.present ? data.status.value : this.status,
      paidAmount:
          data.paidAmount.present ? data.paidAmount.value : this.paidAmount,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProjectPayment(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('projectId: $projectId, ')
          ..write('label: $label, ')
          ..write('amount: $amount, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('paidAmount: $paidAmount, ')
          ..write('paidAt: $paidAt, ')
          ..write('accountId: $accountId, ')
          ..write('transactionId: $transactionId, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, projectId, label, amount,
      dueDate, status, paidAmount, paidAt, accountId, transactionId, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProjectPayment &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.projectId == this.projectId &&
          other.label == this.label &&
          other.amount == this.amount &&
          other.dueDate == this.dueDate &&
          other.status == this.status &&
          other.paidAmount == this.paidAmount &&
          other.paidAt == this.paidAt &&
          other.accountId == this.accountId &&
          other.transactionId == this.transactionId &&
          other.deletedAt == this.deletedAt);
}

class LocalProjectPaymentsCompanion
    extends UpdateCompanion<LocalProjectPayment> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> projectId;
  final Value<String> label;
  final Value<double> amount;
  final Value<DateTime?> dueDate;
  final Value<String> status;
  final Value<double> paidAmount;
  final Value<DateTime?> paidAt;
  final Value<String?> accountId;
  final Value<String?> transactionId;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalProjectPaymentsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.label = const Value.absent(),
    this.amount = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.paidAmount = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.accountId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProjectPaymentsCompanion.insert({
    required String id,
    required String workspaceId,
    required String projectId,
    required String label,
    required double amount,
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.paidAmount = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.accountId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        projectId = Value(projectId),
        label = Value(label),
        amount = Value(amount);
  static Insertable<LocalProjectPayment> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? projectId,
    Expression<String>? label,
    Expression<double>? amount,
    Expression<DateTime>? dueDate,
    Expression<String>? status,
    Expression<double>? paidAmount,
    Expression<DateTime>? paidAt,
    Expression<String>? accountId,
    Expression<String>? transactionId,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (projectId != null) 'project_id': projectId,
      if (label != null) 'label': label,
      if (amount != null) 'amount': amount,
      if (dueDate != null) 'due_date': dueDate,
      if (status != null) 'status': status,
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (paidAt != null) 'paid_at': paidAt,
      if (accountId != null) 'account_id': accountId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProjectPaymentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? projectId,
      Value<String>? label,
      Value<double>? amount,
      Value<DateTime?>? dueDate,
      Value<String>? status,
      Value<double>? paidAmount,
      Value<DateTime?>? paidAt,
      Value<String?>? accountId,
      Value<String?>? transactionId,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalProjectPaymentsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      projectId: projectId ?? this.projectId,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      paidAmount: paidAmount ?? this.paidAmount,
      paidAt: paidAt ?? this.paidAt,
      accountId: accountId ?? this.accountId,
      transactionId: transactionId ?? this.transactionId,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (paidAmount.present) {
      map['paid_amount'] = Variable<double>(paidAmount.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProjectPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('projectId: $projectId, ')
          ..write('label: $label, ')
          ..write('amount: $amount, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('paidAmount: $paidAmount, ')
          ..write('paidAt: $paidAt, ')
          ..write('accountId: $accountId, ')
          ..write('transactionId: $transactionId, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAgendaCacheTable extends LocalAgendaCache
    with TableInfo<$LocalAgendaCacheTable, LocalAgendaCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAgendaCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemTypeMeta =
      const VerificationMeta('itemType');
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
      'item_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _projectNameMeta =
      const VerificationMeta('projectName');
  @override
  late final GeneratedColumn<String> projectName = GeneratedColumn<String>(
      'project_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startsAtMeta =
      const VerificationMeta('startsAt');
  @override
  late final GeneratedColumn<DateTime> startsAt = GeneratedColumn<DateTime>(
      'starts_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
      'ends_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
      'all_day', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("all_day" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _locationMeta =
      const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
      'location', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
      'due_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _dueIsDateOnlyMeta =
      const VerificationMeta('dueIsDateOnly');
  @override
  late final GeneratedColumn<bool> dueIsDateOnly = GeneratedColumn<bool>(
      'due_is_date_only', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("due_is_date_only" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isOverdueMeta =
      const VerificationMeta('isOverdue');
  @override
  late final GeneratedColumn<bool> isOverdue = GeneratedColumn<bool>(
      'is_overdue', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_overdue" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _checklistTotalMeta =
      const VerificationMeta('checklistTotal');
  @override
  late final GeneratedColumn<int> checklistTotal = GeneratedColumn<int>(
      'checklist_total', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _checklistDoneMeta =
      const VerificationMeta('checklistDone');
  @override
  late final GeneratedColumn<int> checklistDone = GeneratedColumn<int>(
      'checklist_done', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _eventIdMeta =
      const VerificationMeta('eventId');
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
      'event_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isRecurringMeta =
      const VerificationMeta('isRecurring');
  @override
  late final GeneratedColumn<bool> isRecurring = GeneratedColumn<bool>(
      'is_recurring', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_recurring" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _milestonePaymentIdMeta =
      const VerificationMeta('milestonePaymentId');
  @override
  late final GeneratedColumn<String> milestonePaymentId =
      GeneratedColumn<String>('milestone_payment_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cachedDateMeta =
      const VerificationMeta('cachedDate');
  @override
  late final GeneratedColumn<String> cachedDate = GeneratedColumn<String>(
      'cached_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        itemType,
        kind,
        title,
        description,
        projectId,
        projectName,
        startsAt,
        endsAt,
        allDay,
        location,
        status,
        priority,
        dueAt,
        dueIsDateOnly,
        isOverdue,
        checklistTotal,
        checklistDone,
        eventId,
        isRecurring,
        milestonePaymentId,
        cachedDate
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_agenda_cache';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalAgendaCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(_itemTypeMeta,
          itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta));
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    }
    if (data.containsKey('project_name')) {
      context.handle(
          _projectNameMeta,
          projectName.isAcceptableOrUnknown(
              data['project_name']!, _projectNameMeta));
    }
    if (data.containsKey('starts_at')) {
      context.handle(_startsAtMeta,
          startsAt.isAcceptableOrUnknown(data['starts_at']!, _startsAtMeta));
    }
    if (data.containsKey('ends_at')) {
      context.handle(_endsAtMeta,
          endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta));
    }
    if (data.containsKey('all_day')) {
      context.handle(_allDayMeta,
          allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta,
          location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('due_at')) {
      context.handle(
          _dueAtMeta, dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta));
    }
    if (data.containsKey('due_is_date_only')) {
      context.handle(
          _dueIsDateOnlyMeta,
          dueIsDateOnly.isAcceptableOrUnknown(
              data['due_is_date_only']!, _dueIsDateOnlyMeta));
    }
    if (data.containsKey('is_overdue')) {
      context.handle(_isOverdueMeta,
          isOverdue.isAcceptableOrUnknown(data['is_overdue']!, _isOverdueMeta));
    }
    if (data.containsKey('checklist_total')) {
      context.handle(
          _checklistTotalMeta,
          checklistTotal.isAcceptableOrUnknown(
              data['checklist_total']!, _checklistTotalMeta));
    }
    if (data.containsKey('checklist_done')) {
      context.handle(
          _checklistDoneMeta,
          checklistDone.isAcceptableOrUnknown(
              data['checklist_done']!, _checklistDoneMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(_eventIdMeta,
          eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta));
    }
    if (data.containsKey('is_recurring')) {
      context.handle(
          _isRecurringMeta,
          isRecurring.isAcceptableOrUnknown(
              data['is_recurring']!, _isRecurringMeta));
    }
    if (data.containsKey('milestone_payment_id')) {
      context.handle(
          _milestonePaymentIdMeta,
          milestonePaymentId.isAcceptableOrUnknown(
              data['milestone_payment_id']!, _milestonePaymentIdMeta));
    }
    if (data.containsKey('cached_date')) {
      context.handle(
          _cachedDateMeta,
          cachedDate.isAcceptableOrUnknown(
              data['cached_date']!, _cachedDateMeta));
    } else if (isInserting) {
      context.missing(_cachedDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, cachedDate};
  @override
  LocalAgendaCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAgendaCacheData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      itemType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_type'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id']),
      projectName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_name']),
      startsAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}starts_at']),
      endsAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ends_at']),
      allDay: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}all_day'])!,
      location: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}location']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority']),
      dueAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}due_at']),
      dueIsDateOnly: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}due_is_date_only'])!,
      isOverdue: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_overdue'])!,
      checklistTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}checklist_total'])!,
      checklistDone: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}checklist_done'])!,
      eventId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_id']),
      isRecurring: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_recurring'])!,
      milestonePaymentId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}milestone_payment_id']),
      cachedDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cached_date'])!,
    );
  }

  @override
  $LocalAgendaCacheTable createAlias(String alias) {
    return $LocalAgendaCacheTable(attachedDatabase, alias);
  }
}

class LocalAgendaCacheData extends DataClass
    implements Insertable<LocalAgendaCacheData> {
  final String id;
  final String workspaceId;
  final String itemType;
  final String kind;
  final String title;
  final String? description;
  final String? projectId;
  final String? projectName;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final String? location;
  final String status;
  final String? priority;
  final DateTime? dueAt;
  final bool dueIsDateOnly;
  final bool isOverdue;
  final int checklistTotal;
  final int checklistDone;
  final String? eventId;
  final bool isRecurring;
  final String? milestonePaymentId;
  final String cachedDate;
  const LocalAgendaCacheData(
      {required this.id,
      required this.workspaceId,
      required this.itemType,
      required this.kind,
      required this.title,
      this.description,
      this.projectId,
      this.projectName,
      this.startsAt,
      this.endsAt,
      required this.allDay,
      this.location,
      required this.status,
      this.priority,
      this.dueAt,
      required this.dueIsDateOnly,
      required this.isOverdue,
      required this.checklistTotal,
      required this.checklistDone,
      this.eventId,
      required this.isRecurring,
      this.milestonePaymentId,
      required this.cachedDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['item_type'] = Variable<String>(itemType);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    if (!nullToAbsent || projectName != null) {
      map['project_name'] = Variable<String>(projectName);
    }
    if (!nullToAbsent || startsAt != null) {
      map['starts_at'] = Variable<DateTime>(startsAt);
    }
    if (!nullToAbsent || endsAt != null) {
      map['ends_at'] = Variable<DateTime>(endsAt);
    }
    map['all_day'] = Variable<bool>(allDay);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || priority != null) {
      map['priority'] = Variable<String>(priority);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['due_is_date_only'] = Variable<bool>(dueIsDateOnly);
    map['is_overdue'] = Variable<bool>(isOverdue);
    map['checklist_total'] = Variable<int>(checklistTotal);
    map['checklist_done'] = Variable<int>(checklistDone);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['is_recurring'] = Variable<bool>(isRecurring);
    if (!nullToAbsent || milestonePaymentId != null) {
      map['milestone_payment_id'] = Variable<String>(milestonePaymentId);
    }
    map['cached_date'] = Variable<String>(cachedDate);
    return map;
  }

  LocalAgendaCacheCompanion toCompanion(bool nullToAbsent) {
    return LocalAgendaCacheCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      itemType: Value(itemType),
      kind: Value(kind),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      projectName: projectName == null && nullToAbsent
          ? const Value.absent()
          : Value(projectName),
      startsAt: startsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startsAt),
      endsAt:
          endsAt == null && nullToAbsent ? const Value.absent() : Value(endsAt),
      allDay: Value(allDay),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      status: Value(status),
      priority: priority == null && nullToAbsent
          ? const Value.absent()
          : Value(priority),
      dueAt:
          dueAt == null && nullToAbsent ? const Value.absent() : Value(dueAt),
      dueIsDateOnly: Value(dueIsDateOnly),
      isOverdue: Value(isOverdue),
      checklistTotal: Value(checklistTotal),
      checklistDone: Value(checklistDone),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      isRecurring: Value(isRecurring),
      milestonePaymentId: milestonePaymentId == null && nullToAbsent
          ? const Value.absent()
          : Value(milestonePaymentId),
      cachedDate: Value(cachedDate),
    );
  }

  factory LocalAgendaCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAgendaCacheData(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      itemType: serializer.fromJson<String>(json['itemType']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      projectName: serializer.fromJson<String?>(json['projectName']),
      startsAt: serializer.fromJson<DateTime?>(json['startsAt']),
      endsAt: serializer.fromJson<DateTime?>(json['endsAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      location: serializer.fromJson<String?>(json['location']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<String?>(json['priority']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      dueIsDateOnly: serializer.fromJson<bool>(json['dueIsDateOnly']),
      isOverdue: serializer.fromJson<bool>(json['isOverdue']),
      checklistTotal: serializer.fromJson<int>(json['checklistTotal']),
      checklistDone: serializer.fromJson<int>(json['checklistDone']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      isRecurring: serializer.fromJson<bool>(json['isRecurring']),
      milestonePaymentId:
          serializer.fromJson<String?>(json['milestonePaymentId']),
      cachedDate: serializer.fromJson<String>(json['cachedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'itemType': serializer.toJson<String>(itemType),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'projectId': serializer.toJson<String?>(projectId),
      'projectName': serializer.toJson<String?>(projectName),
      'startsAt': serializer.toJson<DateTime?>(startsAt),
      'endsAt': serializer.toJson<DateTime?>(endsAt),
      'allDay': serializer.toJson<bool>(allDay),
      'location': serializer.toJson<String?>(location),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<String?>(priority),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'dueIsDateOnly': serializer.toJson<bool>(dueIsDateOnly),
      'isOverdue': serializer.toJson<bool>(isOverdue),
      'checklistTotal': serializer.toJson<int>(checklistTotal),
      'checklistDone': serializer.toJson<int>(checklistDone),
      'eventId': serializer.toJson<String?>(eventId),
      'isRecurring': serializer.toJson<bool>(isRecurring),
      'milestonePaymentId': serializer.toJson<String?>(milestonePaymentId),
      'cachedDate': serializer.toJson<String>(cachedDate),
    };
  }

  LocalAgendaCacheData copyWith(
          {String? id,
          String? workspaceId,
          String? itemType,
          String? kind,
          String? title,
          Value<String?> description = const Value.absent(),
          Value<String?> projectId = const Value.absent(),
          Value<String?> projectName = const Value.absent(),
          Value<DateTime?> startsAt = const Value.absent(),
          Value<DateTime?> endsAt = const Value.absent(),
          bool? allDay,
          Value<String?> location = const Value.absent(),
          String? status,
          Value<String?> priority = const Value.absent(),
          Value<DateTime?> dueAt = const Value.absent(),
          bool? dueIsDateOnly,
          bool? isOverdue,
          int? checklistTotal,
          int? checklistDone,
          Value<String?> eventId = const Value.absent(),
          bool? isRecurring,
          Value<String?> milestonePaymentId = const Value.absent(),
          String? cachedDate}) =>
      LocalAgendaCacheData(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        itemType: itemType ?? this.itemType,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        description: description.present ? description.value : this.description,
        projectId: projectId.present ? projectId.value : this.projectId,
        projectName: projectName.present ? projectName.value : this.projectName,
        startsAt: startsAt.present ? startsAt.value : this.startsAt,
        endsAt: endsAt.present ? endsAt.value : this.endsAt,
        allDay: allDay ?? this.allDay,
        location: location.present ? location.value : this.location,
        status: status ?? this.status,
        priority: priority.present ? priority.value : this.priority,
        dueAt: dueAt.present ? dueAt.value : this.dueAt,
        dueIsDateOnly: dueIsDateOnly ?? this.dueIsDateOnly,
        isOverdue: isOverdue ?? this.isOverdue,
        checklistTotal: checklistTotal ?? this.checklistTotal,
        checklistDone: checklistDone ?? this.checklistDone,
        eventId: eventId.present ? eventId.value : this.eventId,
        isRecurring: isRecurring ?? this.isRecurring,
        milestonePaymentId: milestonePaymentId.present
            ? milestonePaymentId.value
            : this.milestonePaymentId,
        cachedDate: cachedDate ?? this.cachedDate,
      );
  LocalAgendaCacheData copyWithCompanion(LocalAgendaCacheCompanion data) {
    return LocalAgendaCacheData(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      projectName:
          data.projectName.present ? data.projectName.value : this.projectName,
      startsAt: data.startsAt.present ? data.startsAt.value : this.startsAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      location: data.location.present ? data.location.value : this.location,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      dueIsDateOnly: data.dueIsDateOnly.present
          ? data.dueIsDateOnly.value
          : this.dueIsDateOnly,
      isOverdue: data.isOverdue.present ? data.isOverdue.value : this.isOverdue,
      checklistTotal: data.checklistTotal.present
          ? data.checklistTotal.value
          : this.checklistTotal,
      checklistDone: data.checklistDone.present
          ? data.checklistDone.value
          : this.checklistDone,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      isRecurring:
          data.isRecurring.present ? data.isRecurring.value : this.isRecurring,
      milestonePaymentId: data.milestonePaymentId.present
          ? data.milestonePaymentId.value
          : this.milestonePaymentId,
      cachedDate:
          data.cachedDate.present ? data.cachedDate.value : this.cachedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAgendaCacheData(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('itemType: $itemType, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('projectId: $projectId, ')
          ..write('projectName: $projectName, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('allDay: $allDay, ')
          ..write('location: $location, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('dueAt: $dueAt, ')
          ..write('dueIsDateOnly: $dueIsDateOnly, ')
          ..write('isOverdue: $isOverdue, ')
          ..write('checklistTotal: $checklistTotal, ')
          ..write('checklistDone: $checklistDone, ')
          ..write('eventId: $eventId, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('milestonePaymentId: $milestonePaymentId, ')
          ..write('cachedDate: $cachedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        workspaceId,
        itemType,
        kind,
        title,
        description,
        projectId,
        projectName,
        startsAt,
        endsAt,
        allDay,
        location,
        status,
        priority,
        dueAt,
        dueIsDateOnly,
        isOverdue,
        checklistTotal,
        checklistDone,
        eventId,
        isRecurring,
        milestonePaymentId,
        cachedDate
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAgendaCacheData &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.itemType == this.itemType &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.description == this.description &&
          other.projectId == this.projectId &&
          other.projectName == this.projectName &&
          other.startsAt == this.startsAt &&
          other.endsAt == this.endsAt &&
          other.allDay == this.allDay &&
          other.location == this.location &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.dueAt == this.dueAt &&
          other.dueIsDateOnly == this.dueIsDateOnly &&
          other.isOverdue == this.isOverdue &&
          other.checklistTotal == this.checklistTotal &&
          other.checklistDone == this.checklistDone &&
          other.eventId == this.eventId &&
          other.isRecurring == this.isRecurring &&
          other.milestonePaymentId == this.milestonePaymentId &&
          other.cachedDate == this.cachedDate);
}

class LocalAgendaCacheCompanion extends UpdateCompanion<LocalAgendaCacheData> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> itemType;
  final Value<String> kind;
  final Value<String> title;
  final Value<String?> description;
  final Value<String?> projectId;
  final Value<String?> projectName;
  final Value<DateTime?> startsAt;
  final Value<DateTime?> endsAt;
  final Value<bool> allDay;
  final Value<String?> location;
  final Value<String> status;
  final Value<String?> priority;
  final Value<DateTime?> dueAt;
  final Value<bool> dueIsDateOnly;
  final Value<bool> isOverdue;
  final Value<int> checklistTotal;
  final Value<int> checklistDone;
  final Value<String?> eventId;
  final Value<bool> isRecurring;
  final Value<String?> milestonePaymentId;
  final Value<String> cachedDate;
  final Value<int> rowid;
  const LocalAgendaCacheCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.itemType = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.projectId = const Value.absent(),
    this.projectName = const Value.absent(),
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.location = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.dueIsDateOnly = const Value.absent(),
    this.isOverdue = const Value.absent(),
    this.checklistTotal = const Value.absent(),
    this.checklistDone = const Value.absent(),
    this.eventId = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.milestonePaymentId = const Value.absent(),
    this.cachedDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAgendaCacheCompanion.insert({
    required String id,
    required String workspaceId,
    required String itemType,
    required String kind,
    required String title,
    this.description = const Value.absent(),
    this.projectId = const Value.absent(),
    this.projectName = const Value.absent(),
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.location = const Value.absent(),
    required String status,
    this.priority = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.dueIsDateOnly = const Value.absent(),
    this.isOverdue = const Value.absent(),
    this.checklistTotal = const Value.absent(),
    this.checklistDone = const Value.absent(),
    this.eventId = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.milestonePaymentId = const Value.absent(),
    required String cachedDate,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        itemType = Value(itemType),
        kind = Value(kind),
        title = Value(title),
        status = Value(status),
        cachedDate = Value(cachedDate);
  static Insertable<LocalAgendaCacheData> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? itemType,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? projectId,
    Expression<String>? projectName,
    Expression<DateTime>? startsAt,
    Expression<DateTime>? endsAt,
    Expression<bool>? allDay,
    Expression<String>? location,
    Expression<String>? status,
    Expression<String>? priority,
    Expression<DateTime>? dueAt,
    Expression<bool>? dueIsDateOnly,
    Expression<bool>? isOverdue,
    Expression<int>? checklistTotal,
    Expression<int>? checklistDone,
    Expression<String>? eventId,
    Expression<bool>? isRecurring,
    Expression<String>? milestonePaymentId,
    Expression<String>? cachedDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (itemType != null) 'item_type': itemType,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (projectId != null) 'project_id': projectId,
      if (projectName != null) 'project_name': projectName,
      if (startsAt != null) 'starts_at': startsAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (allDay != null) 'all_day': allDay,
      if (location != null) 'location': location,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (dueAt != null) 'due_at': dueAt,
      if (dueIsDateOnly != null) 'due_is_date_only': dueIsDateOnly,
      if (isOverdue != null) 'is_overdue': isOverdue,
      if (checklistTotal != null) 'checklist_total': checklistTotal,
      if (checklistDone != null) 'checklist_done': checklistDone,
      if (eventId != null) 'event_id': eventId,
      if (isRecurring != null) 'is_recurring': isRecurring,
      if (milestonePaymentId != null)
        'milestone_payment_id': milestonePaymentId,
      if (cachedDate != null) 'cached_date': cachedDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAgendaCacheCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? itemType,
      Value<String>? kind,
      Value<String>? title,
      Value<String?>? description,
      Value<String?>? projectId,
      Value<String?>? projectName,
      Value<DateTime?>? startsAt,
      Value<DateTime?>? endsAt,
      Value<bool>? allDay,
      Value<String?>? location,
      Value<String>? status,
      Value<String?>? priority,
      Value<DateTime?>? dueAt,
      Value<bool>? dueIsDateOnly,
      Value<bool>? isOverdue,
      Value<int>? checklistTotal,
      Value<int>? checklistDone,
      Value<String?>? eventId,
      Value<bool>? isRecurring,
      Value<String?>? milestonePaymentId,
      Value<String>? cachedDate,
      Value<int>? rowid}) {
    return LocalAgendaCacheCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      itemType: itemType ?? this.itemType,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      description: description ?? this.description,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      allDay: allDay ?? this.allDay,
      location: location ?? this.location,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      dueIsDateOnly: dueIsDateOnly ?? this.dueIsDateOnly,
      isOverdue: isOverdue ?? this.isOverdue,
      checklistTotal: checklistTotal ?? this.checklistTotal,
      checklistDone: checklistDone ?? this.checklistDone,
      eventId: eventId ?? this.eventId,
      isRecurring: isRecurring ?? this.isRecurring,
      milestonePaymentId: milestonePaymentId ?? this.milestonePaymentId,
      cachedDate: cachedDate ?? this.cachedDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (projectName.present) {
      map['project_name'] = Variable<String>(projectName.value);
    }
    if (startsAt.present) {
      map['starts_at'] = Variable<DateTime>(startsAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (dueIsDateOnly.present) {
      map['due_is_date_only'] = Variable<bool>(dueIsDateOnly.value);
    }
    if (isOverdue.present) {
      map['is_overdue'] = Variable<bool>(isOverdue.value);
    }
    if (checklistTotal.present) {
      map['checklist_total'] = Variable<int>(checklistTotal.value);
    }
    if (checklistDone.present) {
      map['checklist_done'] = Variable<int>(checklistDone.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (isRecurring.present) {
      map['is_recurring'] = Variable<bool>(isRecurring.value);
    }
    if (milestonePaymentId.present) {
      map['milestone_payment_id'] = Variable<String>(milestonePaymentId.value);
    }
    if (cachedDate.present) {
      map['cached_date'] = Variable<String>(cachedDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAgendaCacheCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('itemType: $itemType, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('projectId: $projectId, ')
          ..write('projectName: $projectName, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('allDay: $allDay, ')
          ..write('location: $location, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('dueAt: $dueAt, ')
          ..write('dueIsDateOnly: $dueIsDateOnly, ')
          ..write('isOverdue: $isOverdue, ')
          ..write('checklistTotal: $checklistTotal, ')
          ..write('checklistDone: $checklistDone, ')
          ..write('eventId: $eventId, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('milestonePaymentId: $milestonePaymentId, ')
          ..write('cachedDate: $cachedDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalBudgetsTable extends LocalBudgets
    with TableInfo<$LocalBudgetsTable, LocalBudget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
      'period', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('monthly'));
  static const VerificationMeta _rolloverMeta =
      const VerificationMeta('rollover');
  @override
  late final GeneratedColumn<bool> rollover = GeneratedColumn<bool>(
      'rollover', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("rollover" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _notifyAtPercentMeta =
      const VerificationMeta('notifyAtPercent');
  @override
  late final GeneratedColumn<double> notifyAtPercent = GeneratedColumn<double>(
      'notify_at_percent', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(80.0));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        categoryId,
        amount,
        period,
        rollover,
        notifyAtPercent,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_budgets';
  @override
  VerificationContext validateIntegrity(Insertable<LocalBudget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('period')) {
      context.handle(_periodMeta,
          period.isAcceptableOrUnknown(data['period']!, _periodMeta));
    }
    if (data.containsKey('rollover')) {
      context.handle(_rolloverMeta,
          rollover.isAcceptableOrUnknown(data['rollover']!, _rolloverMeta));
    }
    if (data.containsKey('notify_at_percent')) {
      context.handle(
          _notifyAtPercentMeta,
          notifyAtPercent.isAcceptableOrUnknown(
              data['notify_at_percent']!, _notifyAtPercentMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBudget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBudget(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      period: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}period'])!,
      rollover: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}rollover'])!,
      notifyAtPercent: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}notify_at_percent'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalBudgetsTable createAlias(String alias) {
    return $LocalBudgetsTable(attachedDatabase, alias);
  }
}

class LocalBudget extends DataClass implements Insertable<LocalBudget> {
  final String id;
  final String workspaceId;
  final String categoryId;
  final double amount;
  final String period;
  final bool rollover;
  final double notifyAtPercent;
  final DateTime? deletedAt;
  const LocalBudget(
      {required this.id,
      required this.workspaceId,
      required this.categoryId,
      required this.amount,
      required this.period,
      required this.rollover,
      required this.notifyAtPercent,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['category_id'] = Variable<String>(categoryId);
    map['amount'] = Variable<double>(amount);
    map['period'] = Variable<String>(period);
    map['rollover'] = Variable<bool>(rollover);
    map['notify_at_percent'] = Variable<double>(notifyAtPercent);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalBudgetsCompanion toCompanion(bool nullToAbsent) {
    return LocalBudgetsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      categoryId: Value(categoryId),
      amount: Value(amount),
      period: Value(period),
      rollover: Value(rollover),
      notifyAtPercent: Value(notifyAtPercent),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalBudget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBudget(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      period: serializer.fromJson<String>(json['period']),
      rollover: serializer.fromJson<bool>(json['rollover']),
      notifyAtPercent: serializer.fromJson<double>(json['notifyAtPercent']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'categoryId': serializer.toJson<String>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'period': serializer.toJson<String>(period),
      'rollover': serializer.toJson<bool>(rollover),
      'notifyAtPercent': serializer.toJson<double>(notifyAtPercent),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalBudget copyWith(
          {String? id,
          String? workspaceId,
          String? categoryId,
          double? amount,
          String? period,
          bool? rollover,
          double? notifyAtPercent,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalBudget(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        categoryId: categoryId ?? this.categoryId,
        amount: amount ?? this.amount,
        period: period ?? this.period,
        rollover: rollover ?? this.rollover,
        notifyAtPercent: notifyAtPercent ?? this.notifyAtPercent,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalBudget copyWithCompanion(LocalBudgetsCompanion data) {
    return LocalBudget(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      period: data.period.present ? data.period.value : this.period,
      rollover: data.rollover.present ? data.rollover.value : this.rollover,
      notifyAtPercent: data.notifyAtPercent.present
          ? data.notifyAtPercent.value
          : this.notifyAtPercent,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBudget(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('period: $period, ')
          ..write('rollover: $rollover, ')
          ..write('notifyAtPercent: $notifyAtPercent, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, categoryId, amount, period,
      rollover, notifyAtPercent, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBudget &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.period == this.period &&
          other.rollover == this.rollover &&
          other.notifyAtPercent == this.notifyAtPercent &&
          other.deletedAt == this.deletedAt);
}

class LocalBudgetsCompanion extends UpdateCompanion<LocalBudget> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> categoryId;
  final Value<double> amount;
  final Value<String> period;
  final Value<bool> rollover;
  final Value<double> notifyAtPercent;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalBudgetsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.period = const Value.absent(),
    this.rollover = const Value.absent(),
    this.notifyAtPercent = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalBudgetsCompanion.insert({
    required String id,
    required String workspaceId,
    required String categoryId,
    required double amount,
    this.period = const Value.absent(),
    this.rollover = const Value.absent(),
    this.notifyAtPercent = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        categoryId = Value(categoryId),
        amount = Value(amount);
  static Insertable<LocalBudget> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? categoryId,
    Expression<double>? amount,
    Expression<String>? period,
    Expression<bool>? rollover,
    Expression<double>? notifyAtPercent,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (period != null) 'period': period,
      if (rollover != null) 'rollover': rollover,
      if (notifyAtPercent != null) 'notify_at_percent': notifyAtPercent,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalBudgetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? categoryId,
      Value<double>? amount,
      Value<String>? period,
      Value<bool>? rollover,
      Value<double>? notifyAtPercent,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalBudgetsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      rollover: rollover ?? this.rollover,
      notifyAtPercent: notifyAtPercent ?? this.notifyAtPercent,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (rollover.present) {
      map['rollover'] = Variable<bool>(rollover.value);
    }
    if (notifyAtPercent.present) {
      map['notify_at_percent'] = Variable<double>(notifyAtPercent.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('period: $period, ')
          ..write('rollover: $rollover, ')
          ..write('notifyAtPercent: $notifyAtPercent, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalRecurringBillsTable extends LocalRecurringBills
    with TableInfo<$LocalRecurringBillsTable, LocalRecurringBill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalRecurringBillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
      'amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scheduleTypeMeta =
      const VerificationMeta('scheduleType');
  @override
  late final GeneratedColumn<String> scheduleType = GeneratedColumn<String>(
      'schedule_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('monthly'));
  static const VerificationMeta _scheduleValueMeta =
      const VerificationMeta('scheduleValue');
  @override
  late final GeneratedColumn<int> scheduleValue = GeneratedColumn<int>(
      'schedule_value', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _remindDaysBeforeMeta =
      const VerificationMeta('remindDaysBefore');
  @override
  late final GeneratedColumn<String> remindDaysBefore = GeneratedColumn<String>(
      'remind_days_before', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[3, 0]'));
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _autoCreateDraftMeta =
      const VerificationMeta('autoCreateDraft');
  @override
  late final GeneratedColumn<bool> autoCreateDraft = GeneratedColumn<bool>(
      'auto_create_draft', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_create_draft" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        name,
        amount,
        categoryId,
        accountId,
        scheduleType,
        scheduleValue,
        remindDaysBefore,
        active,
        autoCreateDraft,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_recurring_bills';
  @override
  VerificationContext validateIntegrity(Insertable<LocalRecurringBill> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta,
          amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('schedule_type')) {
      context.handle(
          _scheduleTypeMeta,
          scheduleType.isAcceptableOrUnknown(
              data['schedule_type']!, _scheduleTypeMeta));
    }
    if (data.containsKey('schedule_value')) {
      context.handle(
          _scheduleValueMeta,
          scheduleValue.isAcceptableOrUnknown(
              data['schedule_value']!, _scheduleValueMeta));
    }
    if (data.containsKey('remind_days_before')) {
      context.handle(
          _remindDaysBeforeMeta,
          remindDaysBefore.isAcceptableOrUnknown(
              data['remind_days_before']!, _remindDaysBeforeMeta));
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    }
    if (data.containsKey('auto_create_draft')) {
      context.handle(
          _autoCreateDraftMeta,
          autoCreateDraft.isAcceptableOrUnknown(
              data['auto_create_draft']!, _autoCreateDraftMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalRecurringBill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalRecurringBill(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      amount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}amount'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      scheduleType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}schedule_type'])!,
      scheduleValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}schedule_value'])!,
      remindDaysBefore: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}remind_days_before'])!,
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
      autoCreateDraft: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}auto_create_draft'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalRecurringBillsTable createAlias(String alias) {
    return $LocalRecurringBillsTable(attachedDatabase, alias);
  }
}

class LocalRecurringBill extends DataClass
    implements Insertable<LocalRecurringBill> {
  final String id;
  final String workspaceId;
  final String name;
  final double amount;
  final String categoryId;
  final String accountId;
  final String scheduleType;
  final int scheduleValue;
  final String remindDaysBefore;
  final bool active;
  final bool autoCreateDraft;
  final DateTime? deletedAt;
  const LocalRecurringBill(
      {required this.id,
      required this.workspaceId,
      required this.name,
      required this.amount,
      required this.categoryId,
      required this.accountId,
      required this.scheduleType,
      required this.scheduleValue,
      required this.remindDaysBefore,
      required this.active,
      required this.autoCreateDraft,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['name'] = Variable<String>(name);
    map['amount'] = Variable<double>(amount);
    map['category_id'] = Variable<String>(categoryId);
    map['account_id'] = Variable<String>(accountId);
    map['schedule_type'] = Variable<String>(scheduleType);
    map['schedule_value'] = Variable<int>(scheduleValue);
    map['remind_days_before'] = Variable<String>(remindDaysBefore);
    map['active'] = Variable<bool>(active);
    map['auto_create_draft'] = Variable<bool>(autoCreateDraft);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalRecurringBillsCompanion toCompanion(bool nullToAbsent) {
    return LocalRecurringBillsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      name: Value(name),
      amount: Value(amount),
      categoryId: Value(categoryId),
      accountId: Value(accountId),
      scheduleType: Value(scheduleType),
      scheduleValue: Value(scheduleValue),
      remindDaysBefore: Value(remindDaysBefore),
      active: Value(active),
      autoCreateDraft: Value(autoCreateDraft),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalRecurringBill.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalRecurringBill(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      name: serializer.fromJson<String>(json['name']),
      amount: serializer.fromJson<double>(json['amount']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      scheduleType: serializer.fromJson<String>(json['scheduleType']),
      scheduleValue: serializer.fromJson<int>(json['scheduleValue']),
      remindDaysBefore: serializer.fromJson<String>(json['remindDaysBefore']),
      active: serializer.fromJson<bool>(json['active']),
      autoCreateDraft: serializer.fromJson<bool>(json['autoCreateDraft']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'name': serializer.toJson<String>(name),
      'amount': serializer.toJson<double>(amount),
      'categoryId': serializer.toJson<String>(categoryId),
      'accountId': serializer.toJson<String>(accountId),
      'scheduleType': serializer.toJson<String>(scheduleType),
      'scheduleValue': serializer.toJson<int>(scheduleValue),
      'remindDaysBefore': serializer.toJson<String>(remindDaysBefore),
      'active': serializer.toJson<bool>(active),
      'autoCreateDraft': serializer.toJson<bool>(autoCreateDraft),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalRecurringBill copyWith(
          {String? id,
          String? workspaceId,
          String? name,
          double? amount,
          String? categoryId,
          String? accountId,
          String? scheduleType,
          int? scheduleValue,
          String? remindDaysBefore,
          bool? active,
          bool? autoCreateDraft,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalRecurringBill(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        scheduleType: scheduleType ?? this.scheduleType,
        scheduleValue: scheduleValue ?? this.scheduleValue,
        remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
        active: active ?? this.active,
        autoCreateDraft: autoCreateDraft ?? this.autoCreateDraft,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalRecurringBill copyWithCompanion(LocalRecurringBillsCompanion data) {
    return LocalRecurringBill(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      name: data.name.present ? data.name.value : this.name,
      amount: data.amount.present ? data.amount.value : this.amount,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      scheduleType: data.scheduleType.present
          ? data.scheduleType.value
          : this.scheduleType,
      scheduleValue: data.scheduleValue.present
          ? data.scheduleValue.value
          : this.scheduleValue,
      remindDaysBefore: data.remindDaysBefore.present
          ? data.remindDaysBefore.value
          : this.remindDaysBefore,
      active: data.active.present ? data.active.value : this.active,
      autoCreateDraft: data.autoCreateDraft.present
          ? data.autoCreateDraft.value
          : this.autoCreateDraft,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalRecurringBill(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('scheduleValue: $scheduleValue, ')
          ..write('remindDaysBefore: $remindDaysBefore, ')
          ..write('active: $active, ')
          ..write('autoCreateDraft: $autoCreateDraft, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      workspaceId,
      name,
      amount,
      categoryId,
      accountId,
      scheduleType,
      scheduleValue,
      remindDaysBefore,
      active,
      autoCreateDraft,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalRecurringBill &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.name == this.name &&
          other.amount == this.amount &&
          other.categoryId == this.categoryId &&
          other.accountId == this.accountId &&
          other.scheduleType == this.scheduleType &&
          other.scheduleValue == this.scheduleValue &&
          other.remindDaysBefore == this.remindDaysBefore &&
          other.active == this.active &&
          other.autoCreateDraft == this.autoCreateDraft &&
          other.deletedAt == this.deletedAt);
}

class LocalRecurringBillsCompanion extends UpdateCompanion<LocalRecurringBill> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> name;
  final Value<double> amount;
  final Value<String> categoryId;
  final Value<String> accountId;
  final Value<String> scheduleType;
  final Value<int> scheduleValue;
  final Value<String> remindDaysBefore;
  final Value<bool> active;
  final Value<bool> autoCreateDraft;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalRecurringBillsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.amount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.scheduleType = const Value.absent(),
    this.scheduleValue = const Value.absent(),
    this.remindDaysBefore = const Value.absent(),
    this.active = const Value.absent(),
    this.autoCreateDraft = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalRecurringBillsCompanion.insert({
    required String id,
    required String workspaceId,
    required String name,
    required double amount,
    required String categoryId,
    required String accountId,
    this.scheduleType = const Value.absent(),
    this.scheduleValue = const Value.absent(),
    this.remindDaysBefore = const Value.absent(),
    this.active = const Value.absent(),
    this.autoCreateDraft = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        name = Value(name),
        amount = Value(amount),
        categoryId = Value(categoryId),
        accountId = Value(accountId);
  static Insertable<LocalRecurringBill> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? name,
    Expression<double>? amount,
    Expression<String>? categoryId,
    Expression<String>? accountId,
    Expression<String>? scheduleType,
    Expression<int>? scheduleValue,
    Expression<String>? remindDaysBefore,
    Expression<bool>? active,
    Expression<bool>? autoCreateDraft,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      if (scheduleType != null) 'schedule_type': scheduleType,
      if (scheduleValue != null) 'schedule_value': scheduleValue,
      if (remindDaysBefore != null) 'remind_days_before': remindDaysBefore,
      if (active != null) 'active': active,
      if (autoCreateDraft != null) 'auto_create_draft': autoCreateDraft,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalRecurringBillsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? name,
      Value<double>? amount,
      Value<String>? categoryId,
      Value<String>? accountId,
      Value<String>? scheduleType,
      Value<int>? scheduleValue,
      Value<String>? remindDaysBefore,
      Value<bool>? active,
      Value<bool>? autoCreateDraft,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalRecurringBillsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduleValue: scheduleValue ?? this.scheduleValue,
      remindDaysBefore: remindDaysBefore ?? this.remindDaysBefore,
      active: active ?? this.active,
      autoCreateDraft: autoCreateDraft ?? this.autoCreateDraft,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (scheduleType.present) {
      map['schedule_type'] = Variable<String>(scheduleType.value);
    }
    if (scheduleValue.present) {
      map['schedule_value'] = Variable<int>(scheduleValue.value);
    }
    if (remindDaysBefore.present) {
      map['remind_days_before'] = Variable<String>(remindDaysBefore.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (autoCreateDraft.present) {
      map['auto_create_draft'] = Variable<bool>(autoCreateDraft.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalRecurringBillsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('accountId: $accountId, ')
          ..write('scheduleType: $scheduleType, ')
          ..write('scheduleValue: $scheduleValue, ')
          ..write('remindDaysBefore: $remindDaysBefore, ')
          ..write('active: $active, ')
          ..write('autoCreateDraft: $autoCreateDraft, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSavingsGoalsTable extends LocalSavingsGoals
    with TableInfo<$LocalSavingsGoalsTable, LocalSavingsGoal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSavingsGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetAmountMeta =
      const VerificationMeta('targetAmount');
  @override
  late final GeneratedColumn<double> targetAmount = GeneratedColumn<double>(
      'target_amount', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _currentAmountMeta =
      const VerificationMeta('currentAmount');
  @override
  late final GeneratedColumn<double> currentAmount = GeneratedColumn<double>(
      'current_amount', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0.0));
  static const VerificationMeta _targetDateMeta =
      const VerificationMeta('targetDate');
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
      'target_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        name,
        targetAmount,
        currentAmount,
        targetDate,
        isCompleted,
        notes,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_savings_goals';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSavingsGoal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('target_amount')) {
      context.handle(
          _targetAmountMeta,
          targetAmount.isAcceptableOrUnknown(
              data['target_amount']!, _targetAmountMeta));
    } else if (isInserting) {
      context.missing(_targetAmountMeta);
    }
    if (data.containsKey('current_amount')) {
      context.handle(
          _currentAmountMeta,
          currentAmount.isAcceptableOrUnknown(
              data['current_amount']!, _currentAmountMeta));
    }
    if (data.containsKey('target_date')) {
      context.handle(
          _targetDateMeta,
          targetDate.isAcceptableOrUnknown(
              data['target_date']!, _targetDateMeta));
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSavingsGoal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSavingsGoal(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      targetAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}target_amount'])!,
      currentAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}current_amount'])!,
      targetDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}target_date']),
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalSavingsGoalsTable createAlias(String alias) {
    return $LocalSavingsGoalsTable(attachedDatabase, alias);
  }
}

class LocalSavingsGoal extends DataClass
    implements Insertable<LocalSavingsGoal> {
  final String id;
  final String workspaceId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final bool isCompleted;
  final String? notes;
  final DateTime? deletedAt;
  const LocalSavingsGoal(
      {required this.id,
      required this.workspaceId,
      required this.name,
      required this.targetAmount,
      required this.currentAmount,
      this.targetDate,
      required this.isCompleted,
      this.notes,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['name'] = Variable<String>(name);
    map['target_amount'] = Variable<double>(targetAmount);
    map['current_amount'] = Variable<double>(currentAmount);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalSavingsGoalsCompanion toCompanion(bool nullToAbsent) {
    return LocalSavingsGoalsCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      name: Value(name),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      isCompleted: Value(isCompleted),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalSavingsGoal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSavingsGoal(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      name: serializer.fromJson<String>(json['name']),
      targetAmount: serializer.fromJson<double>(json['targetAmount']),
      currentAmount: serializer.fromJson<double>(json['currentAmount']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      notes: serializer.fromJson<String?>(json['notes']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'name': serializer.toJson<String>(name),
      'targetAmount': serializer.toJson<double>(targetAmount),
      'currentAmount': serializer.toJson<double>(currentAmount),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'notes': serializer.toJson<String?>(notes),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalSavingsGoal copyWith(
          {String? id,
          String? workspaceId,
          String? name,
          double? targetAmount,
          double? currentAmount,
          Value<DateTime?> targetDate = const Value.absent(),
          bool? isCompleted,
          Value<String?> notes = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalSavingsGoal(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        targetDate: targetDate.present ? targetDate.value : this.targetDate,
        isCompleted: isCompleted ?? this.isCompleted,
        notes: notes.present ? notes.value : this.notes,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalSavingsGoal copyWithCompanion(LocalSavingsGoalsCompanion data) {
    return LocalSavingsGoal(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      name: data.name.present ? data.name.value : this.name,
      targetAmount: data.targetAmount.present
          ? data.targetAmount.value
          : this.targetAmount,
      currentAmount: data.currentAmount.present
          ? data.currentAmount.value
          : this.currentAmount,
      targetDate:
          data.targetDate.present ? data.targetDate.value : this.targetDate,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      notes: data.notes.present ? data.notes.value : this.notes,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSavingsGoal(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('targetDate: $targetDate, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('notes: $notes, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, name, targetAmount,
      currentAmount, targetDate, isCompleted, notes, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSavingsGoal &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.name == this.name &&
          other.targetAmount == this.targetAmount &&
          other.currentAmount == this.currentAmount &&
          other.targetDate == this.targetDate &&
          other.isCompleted == this.isCompleted &&
          other.notes == this.notes &&
          other.deletedAt == this.deletedAt);
}

class LocalSavingsGoalsCompanion extends UpdateCompanion<LocalSavingsGoal> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> name;
  final Value<double> targetAmount;
  final Value<double> currentAmount;
  final Value<DateTime?> targetDate;
  final Value<bool> isCompleted;
  final Value<String?> notes;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalSavingsGoalsCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.name = const Value.absent(),
    this.targetAmount = const Value.absent(),
    this.currentAmount = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.notes = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSavingsGoalsCompanion.insert({
    required String id,
    required String workspaceId,
    required String name,
    required double targetAmount,
    this.currentAmount = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.notes = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        name = Value(name),
        targetAmount = Value(targetAmount);
  static Insertable<LocalSavingsGoal> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? name,
    Expression<double>? targetAmount,
    Expression<double>? currentAmount,
    Expression<DateTime>? targetDate,
    Expression<bool>? isCompleted,
    Expression<String>? notes,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (name != null) 'name': name,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (currentAmount != null) 'current_amount': currentAmount,
      if (targetDate != null) 'target_date': targetDate,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (notes != null) 'notes': notes,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSavingsGoalsCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? name,
      Value<double>? targetAmount,
      Value<double>? currentAmount,
      Value<DateTime?>? targetDate,
      Value<bool>? isCompleted,
      Value<String?>? notes,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalSavingsGoalsCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (targetAmount.present) {
      map['target_amount'] = Variable<double>(targetAmount.value);
    }
    if (currentAmount.present) {
      map['current_amount'] = Variable<double>(currentAmount.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSavingsGoalsCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('name: $name, ')
          ..write('targetAmount: $targetAmount, ')
          ..write('currentAmount: $currentAmount, ')
          ..write('targetDate: $targetDate, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('notes: $notes, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalIncomeSplitRulesTable extends LocalIncomeSplitRules
    with TableInfo<$LocalIncomeSplitRulesTable, LocalIncomeSplitRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalIncomeSplitRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _workspaceIdMeta =
      const VerificationMeta('workspaceId');
  @override
  late final GeneratedColumn<String> workspaceId = GeneratedColumn<String>(
      'workspace_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
      'goal_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _splitTypeMeta =
      const VerificationMeta('splitType');
  @override
  late final GeneratedColumn<String> splitType = GeneratedColumn<String>(
      'split_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('percentage'));
  static const VerificationMeta _splitValueMeta =
      const VerificationMeta('splitValue');
  @override
  late final GeneratedColumn<double> splitValue = GeneratedColumn<double>(
      'split_value', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
      'priority', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("active" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        workspaceId,
        source,
        goalId,
        splitType,
        splitValue,
        priority,
        active,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_income_split_rules';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalIncomeSplitRule> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workspace_id')) {
      context.handle(
          _workspaceIdMeta,
          workspaceId.isAcceptableOrUnknown(
              data['workspace_id']!, _workspaceIdMeta));
    } else if (isInserting) {
      context.missing(_workspaceIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(_goalIdMeta,
          goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta));
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('split_type')) {
      context.handle(_splitTypeMeta,
          splitType.isAcceptableOrUnknown(data['split_type']!, _splitTypeMeta));
    }
    if (data.containsKey('split_value')) {
      context.handle(
          _splitValueMeta,
          splitValue.isAcceptableOrUnknown(
              data['split_value']!, _splitValueMeta));
    } else if (isInserting) {
      context.missing(_splitValueMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('active')) {
      context.handle(_activeMeta,
          active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalIncomeSplitRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalIncomeSplitRule(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      workspaceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workspace_id'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      goalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}goal_id'])!,
      splitType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}split_type'])!,
      splitValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}split_value'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority'])!,
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $LocalIncomeSplitRulesTable createAlias(String alias) {
    return $LocalIncomeSplitRulesTable(attachedDatabase, alias);
  }
}

class LocalIncomeSplitRule extends DataClass
    implements Insertable<LocalIncomeSplitRule> {
  final String id;
  final String workspaceId;
  final String source;
  final String goalId;
  final String splitType;
  final double splitValue;
  final int priority;
  final bool active;
  final DateTime? deletedAt;
  const LocalIncomeSplitRule(
      {required this.id,
      required this.workspaceId,
      required this.source,
      required this.goalId,
      required this.splitType,
      required this.splitValue,
      required this.priority,
      required this.active,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workspace_id'] = Variable<String>(workspaceId);
    map['source'] = Variable<String>(source);
    map['goal_id'] = Variable<String>(goalId);
    map['split_type'] = Variable<String>(splitType);
    map['split_value'] = Variable<double>(splitValue);
    map['priority'] = Variable<int>(priority);
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  LocalIncomeSplitRulesCompanion toCompanion(bool nullToAbsent) {
    return LocalIncomeSplitRulesCompanion(
      id: Value(id),
      workspaceId: Value(workspaceId),
      source: Value(source),
      goalId: Value(goalId),
      splitType: Value(splitType),
      splitValue: Value(splitValue),
      priority: Value(priority),
      active: Value(active),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LocalIncomeSplitRule.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalIncomeSplitRule(
      id: serializer.fromJson<String>(json['id']),
      workspaceId: serializer.fromJson<String>(json['workspaceId']),
      source: serializer.fromJson<String>(json['source']),
      goalId: serializer.fromJson<String>(json['goalId']),
      splitType: serializer.fromJson<String>(json['splitType']),
      splitValue: serializer.fromJson<double>(json['splitValue']),
      priority: serializer.fromJson<int>(json['priority']),
      active: serializer.fromJson<bool>(json['active']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workspaceId': serializer.toJson<String>(workspaceId),
      'source': serializer.toJson<String>(source),
      'goalId': serializer.toJson<String>(goalId),
      'splitType': serializer.toJson<String>(splitType),
      'splitValue': serializer.toJson<double>(splitValue),
      'priority': serializer.toJson<int>(priority),
      'active': serializer.toJson<bool>(active),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  LocalIncomeSplitRule copyWith(
          {String? id,
          String? workspaceId,
          String? source,
          String? goalId,
          String? splitType,
          double? splitValue,
          int? priority,
          bool? active,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      LocalIncomeSplitRule(
        id: id ?? this.id,
        workspaceId: workspaceId ?? this.workspaceId,
        source: source ?? this.source,
        goalId: goalId ?? this.goalId,
        splitType: splitType ?? this.splitType,
        splitValue: splitValue ?? this.splitValue,
        priority: priority ?? this.priority,
        active: active ?? this.active,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  LocalIncomeSplitRule copyWithCompanion(LocalIncomeSplitRulesCompanion data) {
    return LocalIncomeSplitRule(
      id: data.id.present ? data.id.value : this.id,
      workspaceId:
          data.workspaceId.present ? data.workspaceId.value : this.workspaceId,
      source: data.source.present ? data.source.value : this.source,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      splitType: data.splitType.present ? data.splitType.value : this.splitType,
      splitValue:
          data.splitValue.present ? data.splitValue.value : this.splitValue,
      priority: data.priority.present ? data.priority.value : this.priority,
      active: data.active.present ? data.active.value : this.active,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalIncomeSplitRule(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('source: $source, ')
          ..write('goalId: $goalId, ')
          ..write('splitType: $splitType, ')
          ..write('splitValue: $splitValue, ')
          ..write('priority: $priority, ')
          ..write('active: $active, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, workspaceId, source, goalId, splitType,
      splitValue, priority, active, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalIncomeSplitRule &&
          other.id == this.id &&
          other.workspaceId == this.workspaceId &&
          other.source == this.source &&
          other.goalId == this.goalId &&
          other.splitType == this.splitType &&
          other.splitValue == this.splitValue &&
          other.priority == this.priority &&
          other.active == this.active &&
          other.deletedAt == this.deletedAt);
}

class LocalIncomeSplitRulesCompanion
    extends UpdateCompanion<LocalIncomeSplitRule> {
  final Value<String> id;
  final Value<String> workspaceId;
  final Value<String> source;
  final Value<String> goalId;
  final Value<String> splitType;
  final Value<double> splitValue;
  final Value<int> priority;
  final Value<bool> active;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const LocalIncomeSplitRulesCompanion({
    this.id = const Value.absent(),
    this.workspaceId = const Value.absent(),
    this.source = const Value.absent(),
    this.goalId = const Value.absent(),
    this.splitType = const Value.absent(),
    this.splitValue = const Value.absent(),
    this.priority = const Value.absent(),
    this.active = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalIncomeSplitRulesCompanion.insert({
    required String id,
    required String workspaceId,
    required String source,
    required String goalId,
    this.splitType = const Value.absent(),
    required double splitValue,
    this.priority = const Value.absent(),
    this.active = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        workspaceId = Value(workspaceId),
        source = Value(source),
        goalId = Value(goalId),
        splitValue = Value(splitValue);
  static Insertable<LocalIncomeSplitRule> custom({
    Expression<String>? id,
    Expression<String>? workspaceId,
    Expression<String>? source,
    Expression<String>? goalId,
    Expression<String>? splitType,
    Expression<double>? splitValue,
    Expression<int>? priority,
    Expression<bool>? active,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workspaceId != null) 'workspace_id': workspaceId,
      if (source != null) 'source': source,
      if (goalId != null) 'goal_id': goalId,
      if (splitType != null) 'split_type': splitType,
      if (splitValue != null) 'split_value': splitValue,
      if (priority != null) 'priority': priority,
      if (active != null) 'active': active,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalIncomeSplitRulesCompanion copyWith(
      {Value<String>? id,
      Value<String>? workspaceId,
      Value<String>? source,
      Value<String>? goalId,
      Value<String>? splitType,
      Value<double>? splitValue,
      Value<int>? priority,
      Value<bool>? active,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return LocalIncomeSplitRulesCompanion(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      source: source ?? this.source,
      goalId: goalId ?? this.goalId,
      splitType: splitType ?? this.splitType,
      splitValue: splitValue ?? this.splitValue,
      priority: priority ?? this.priority,
      active: active ?? this.active,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workspaceId.present) {
      map['workspace_id'] = Variable<String>(workspaceId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (splitType.present) {
      map['split_type'] = Variable<String>(splitType.value);
    }
    if (splitValue.present) {
      map['split_value'] = Variable<double>(splitValue.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalIncomeSplitRulesCompanion(')
          ..write('id: $id, ')
          ..write('workspaceId: $workspaceId, ')
          ..write('source: $source, ')
          ..write('goalId: $goalId, ')
          ..write('splitType: $splitType, ')
          ..write('splitValue: $splitValue, ')
          ..write('priority: $priority, ')
          ..write('active: $active, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalAccountsTable localAccounts = $LocalAccountsTable(this);
  late final $LocalCategoriesTable localCategories =
      $LocalCategoriesTable(this);
  late final $LocalTransactionsTable localTransactions =
      $LocalTransactionsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $LocalProjectsTable localProjects = $LocalProjectsTable(this);
  late final $LocalTasksTable localTasks = $LocalTasksTable(this);
  late final $LocalTaskChecklistItemsTable localTaskChecklistItems =
      $LocalTaskChecklistItemsTable(this);
  late final $LocalEventsTable localEvents = $LocalEventsTable(this);
  late final $LocalProjectPaymentsTable localProjectPayments =
      $LocalProjectPaymentsTable(this);
  late final $LocalAgendaCacheTable localAgendaCache =
      $LocalAgendaCacheTable(this);
  late final $LocalBudgetsTable localBudgets = $LocalBudgetsTable(this);
  late final $LocalRecurringBillsTable localRecurringBills =
      $LocalRecurringBillsTable(this);
  late final $LocalSavingsGoalsTable localSavingsGoals =
      $LocalSavingsGoalsTable(this);
  late final $LocalIncomeSplitRulesTable localIncomeSplitRules =
      $LocalIncomeSplitRulesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localAccounts,
        localCategories,
        localTransactions,
        syncOutbox,
        localProjects,
        localTasks,
        localTaskChecklistItems,
        localEvents,
        localProjectPayments,
        localAgendaCache,
        localBudgets,
        localRecurringBills,
        localSavingsGoals,
        localIncomeSplitRules
      ];
}

typedef $$LocalAccountsTableCreateCompanionBuilder = LocalAccountsCompanion
    Function({
  required String id,
  required String workspaceId,
  required String name,
  required String type,
  required String currency,
  Value<double> initialBalance,
  Value<double> currentBalance,
  Value<bool> isLiquid,
  Value<String> visibility,
  Value<bool> archived,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$LocalAccountsTableUpdateCompanionBuilder = LocalAccountsCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> name,
  Value<String> type,
  Value<String> currency,
  Value<double> initialBalance,
  Value<double> currentBalance,
  Value<bool> isLiquid,
  Value<String> visibility,
  Value<bool> archived,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$LocalAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get currentBalance => $composableBuilder(
      column: $table.currentBalance,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLiquid => $composableBuilder(
      column: $table.isLiquid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$LocalAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get currentBalance => $composableBuilder(
      column: $table.currentBalance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLiquid => $composableBuilder(
      column: $table.isLiquid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$LocalAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get initialBalance => $composableBuilder(
      column: $table.initialBalance, builder: (column) => column);

  GeneratedColumn<double> get currentBalance => $composableBuilder(
      column: $table.currentBalance, builder: (column) => column);

  GeneratedColumn<bool> get isLiquid =>
      $composableBuilder(column: $table.isLiquid, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
      column: $table.visibility, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$LocalAccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalAccountsTable,
    LocalAccount,
    $$LocalAccountsTableFilterComposer,
    $$LocalAccountsTableOrderingComposer,
    $$LocalAccountsTableAnnotationComposer,
    $$LocalAccountsTableCreateCompanionBuilder,
    $$LocalAccountsTableUpdateCompanionBuilder,
    (
      LocalAccount,
      BaseReferences<_$AppDatabase, $LocalAccountsTable, LocalAccount>
    ),
    LocalAccount,
    PrefetchHooks Function()> {
  $$LocalAccountsTableTableManager(_$AppDatabase db, $LocalAccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<double> initialBalance = const Value.absent(),
            Value<double> currentBalance = const Value.absent(),
            Value<bool> isLiquid = const Value.absent(),
            Value<String> visibility = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAccountsCompanion(
            id: id,
            workspaceId: workspaceId,
            name: name,
            type: type,
            currency: currency,
            initialBalance: initialBalance,
            currentBalance: currentBalance,
            isLiquid: isLiquid,
            visibility: visibility,
            archived: archived,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String name,
            required String type,
            required String currency,
            Value<double> initialBalance = const Value.absent(),
            Value<double> currentBalance = const Value.absent(),
            Value<bool> isLiquid = const Value.absent(),
            Value<String> visibility = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAccountsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            name: name,
            type: type,
            currency: currency,
            initialBalance: initialBalance,
            currentBalance: currentBalance,
            isLiquid: isLiquid,
            visibility: visibility,
            archived: archived,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalAccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalAccountsTable,
    LocalAccount,
    $$LocalAccountsTableFilterComposer,
    $$LocalAccountsTableOrderingComposer,
    $$LocalAccountsTableAnnotationComposer,
    $$LocalAccountsTableCreateCompanionBuilder,
    $$LocalAccountsTableUpdateCompanionBuilder,
    (
      LocalAccount,
      BaseReferences<_$AppDatabase, $LocalAccountsTable, LocalAccount>
    ),
    LocalAccount,
    PrefetchHooks Function()>;
typedef $$LocalCategoriesTableCreateCompanionBuilder = LocalCategoriesCompanion
    Function({
  required String id,
  required String workspaceId,
  required String name,
  required String type,
  Value<String?> parentId,
  Value<String?> systemKey,
  Value<bool> archived,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$LocalCategoriesTableUpdateCompanionBuilder = LocalCategoriesCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> name,
  Value<String> type,
  Value<String?> parentId,
  Value<String?> systemKey,
  Value<bool> archived,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$LocalCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCategoriesTable> {
  $$LocalCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get systemKey => $composableBuilder(
      column: $table.systemKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$LocalCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCategoriesTable> {
  $$LocalCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get systemKey => $composableBuilder(
      column: $table.systemKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$LocalCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCategoriesTable> {
  $$LocalCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get systemKey =>
      $composableBuilder(column: $table.systemKey, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$LocalCategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalCategoriesTable,
    LocalCategory,
    $$LocalCategoriesTableFilterComposer,
    $$LocalCategoriesTableOrderingComposer,
    $$LocalCategoriesTableAnnotationComposer,
    $$LocalCategoriesTableCreateCompanionBuilder,
    $$LocalCategoriesTableUpdateCompanionBuilder,
    (
      LocalCategory,
      BaseReferences<_$AppDatabase, $LocalCategoriesTable, LocalCategory>
    ),
    LocalCategory,
    PrefetchHooks Function()> {
  $$LocalCategoriesTableTableManager(
      _$AppDatabase db, $LocalCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<String?> systemKey = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCategoriesCompanion(
            id: id,
            workspaceId: workspaceId,
            name: name,
            type: type,
            parentId: parentId,
            systemKey: systemKey,
            archived: archived,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String name,
            required String type,
            Value<String?> parentId = const Value.absent(),
            Value<String?> systemKey = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCategoriesCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            name: name,
            type: type,
            parentId: parentId,
            systemKey: systemKey,
            archived: archived,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalCategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalCategoriesTable,
    LocalCategory,
    $$LocalCategoriesTableFilterComposer,
    $$LocalCategoriesTableOrderingComposer,
    $$LocalCategoriesTableAnnotationComposer,
    $$LocalCategoriesTableCreateCompanionBuilder,
    $$LocalCategoriesTableUpdateCompanionBuilder,
    (
      LocalCategory,
      BaseReferences<_$AppDatabase, $LocalCategoriesTable, LocalCategory>
    ),
    LocalCategory,
    PrefetchHooks Function()>;
typedef $$LocalTransactionsTableCreateCompanionBuilder
    = LocalTransactionsCompanion Function({
  required String id,
  required String workspaceId,
  required String accountId,
  Value<String?> categoryId,
  required String type,
  required String status,
  Value<String?> draftState,
  required double amount,
  required String currency,
  Value<String?> source,
  Value<String?> merchant,
  Value<String?> note,
  required DateTime occurredAt,
  Value<String?> transferGroupId,
  Value<String?> transferDirection,
  Value<String> origin,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalTransactionsTableUpdateCompanionBuilder
    = LocalTransactionsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> accountId,
  Value<String?> categoryId,
  Value<String> type,
  Value<String> status,
  Value<String?> draftState,
  Value<double> amount,
  Value<String> currency,
  Value<String?> source,
  Value<String?> merchant,
  Value<String?> note,
  Value<DateTime> occurredAt,
  Value<String?> transferGroupId,
  Value<String?> transferDirection,
  Value<String> origin,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get draftState => $composableBuilder(
      column: $table.draftState, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get merchant => $composableBuilder(
      column: $table.merchant, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transferGroupId => $composableBuilder(
      column: $table.transferGroupId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transferDirection => $composableBuilder(
      column: $table.transferDirection,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get origin => $composableBuilder(
      column: $table.origin, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get draftState => $composableBuilder(
      column: $table.draftState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get merchant => $composableBuilder(
      column: $table.merchant, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transferGroupId => $composableBuilder(
      column: $table.transferGroupId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transferDirection => $composableBuilder(
      column: $table.transferDirection,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get origin => $composableBuilder(
      column: $table.origin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTransactionsTable> {
  $$LocalTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get draftState => $composableBuilder(
      column: $table.draftState, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<String> get transferGroupId => $composableBuilder(
      column: $table.transferGroupId, builder: (column) => column);

  GeneratedColumn<String> get transferDirection => $composableBuilder(
      column: $table.transferDirection, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalTransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalTransactionsTable,
    LocalTransaction,
    $$LocalTransactionsTableFilterComposer,
    $$LocalTransactionsTableOrderingComposer,
    $$LocalTransactionsTableAnnotationComposer,
    $$LocalTransactionsTableCreateCompanionBuilder,
    $$LocalTransactionsTableUpdateCompanionBuilder,
    (
      LocalTransaction,
      BaseReferences<_$AppDatabase, $LocalTransactionsTable, LocalTransaction>
    ),
    LocalTransaction,
    PrefetchHooks Function()> {
  $$LocalTransactionsTableTableManager(
      _$AppDatabase db, $LocalTransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTransactionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String?> categoryId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> draftState = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<String?> source = const Value.absent(),
            Value<String?> merchant = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<String?> transferGroupId = const Value.absent(),
            Value<String?> transferDirection = const Value.absent(),
            Value<String> origin = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalTransactionsCompanion(
            id: id,
            workspaceId: workspaceId,
            accountId: accountId,
            categoryId: categoryId,
            type: type,
            status: status,
            draftState: draftState,
            amount: amount,
            currency: currency,
            source: source,
            merchant: merchant,
            note: note,
            occurredAt: occurredAt,
            transferGroupId: transferGroupId,
            transferDirection: transferDirection,
            origin: origin,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String accountId,
            Value<String?> categoryId = const Value.absent(),
            required String type,
            required String status,
            Value<String?> draftState = const Value.absent(),
            required double amount,
            required String currency,
            Value<String?> source = const Value.absent(),
            Value<String?> merchant = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required DateTime occurredAt,
            Value<String?> transferGroupId = const Value.absent(),
            Value<String?> transferDirection = const Value.absent(),
            Value<String> origin = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalTransactionsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            accountId: accountId,
            categoryId: categoryId,
            type: type,
            status: status,
            draftState: draftState,
            amount: amount,
            currency: currency,
            source: source,
            merchant: merchant,
            note: note,
            occurredAt: occurredAt,
            transferGroupId: transferGroupId,
            transferDirection: transferDirection,
            origin: origin,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalTransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalTransactionsTable,
    LocalTransaction,
    $$LocalTransactionsTableFilterComposer,
    $$LocalTransactionsTableOrderingComposer,
    $$LocalTransactionsTableAnnotationComposer,
    $$LocalTransactionsTableCreateCompanionBuilder,
    $$LocalTransactionsTableUpdateCompanionBuilder,
    (
      LocalTransaction,
      BaseReferences<_$AppDatabase, $LocalTransactionsTable, LocalTransaction>
    ),
    LocalTransaction,
    PrefetchHooks Function()>;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  required String id,
  required String targetTable,
  required String recordId,
  required String action,
  required String payload,
  required DateTime createdAt,
  Value<String> status,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<String> id,
  Value<String> targetTable,
  Value<String> recordId,
  Value<String> action,
  Value<String> payload,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get action => $composableBuilder(
      column: $table.action, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetTable => $composableBuilder(
      column: $table.targetTable, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncOutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()> {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> targetTable = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> action = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxCompanion(
            id: id,
            targetTable: targetTable,
            recordId: recordId,
            action: action,
            payload: payload,
            createdAt: createdAt,
            status: status,
            attempts: attempts,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String targetTable,
            required String recordId,
            required String action,
            required String payload,
            required DateTime createdAt,
            Value<String> status = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxCompanion.insert(
            id: id,
            targetTable: targetTable,
            recordId: recordId,
            action: action,
            payload: payload,
            createdAt: createdAt,
            status: status,
            attempts: attempts,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncOutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()>;
typedef $$LocalProjectsTableCreateCompanionBuilder = LocalProjectsCompanion
    Function({
  required String id,
  required String workspaceId,
  required String kind,
  required String name,
  Value<String?> description,
  Value<String> status,
  Value<DateTime?> startedOn,
  Value<DateTime?> deadline,
  Value<String?> color,
  Value<String?> clientName,
  Value<double?> contractValue,
  Value<String?> currency,
  Value<double?> platformFeePercent,
  Value<String?> feeMode,
  Value<int?> semester,
  Value<String?> courseCode,
  Value<int?> credits,
  Value<double?> stipendAmount,
  Value<int?> stipendDay,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalProjectsTableUpdateCompanionBuilder = LocalProjectsCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> kind,
  Value<String> name,
  Value<String?> description,
  Value<String> status,
  Value<DateTime?> startedOn,
  Value<DateTime?> deadline,
  Value<String?> color,
  Value<String?> clientName,
  Value<double?> contractValue,
  Value<String?> currency,
  Value<double?> platformFeePercent,
  Value<String?> feeMode,
  Value<int?> semester,
  Value<String?> courseCode,
  Value<int?> credits,
  Value<double?> stipendAmount,
  Value<int?> stipendDay,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedOn => $composableBuilder(
      column: $table.startedOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deadline => $composableBuilder(
      column: $table.deadline, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get contractValue => $composableBuilder(
      column: $table.contractValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get platformFeePercent => $composableBuilder(
      column: $table.platformFeePercent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get feeMode => $composableBuilder(
      column: $table.feeMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get semester => $composableBuilder(
      column: $table.semester, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get credits => $composableBuilder(
      column: $table.credits, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get stipendAmount => $composableBuilder(
      column: $table.stipendAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stipendDay => $composableBuilder(
      column: $table.stipendDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedOn => $composableBuilder(
      column: $table.startedOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deadline => $composableBuilder(
      column: $table.deadline, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get contractValue => $composableBuilder(
      column: $table.contractValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get platformFeePercent => $composableBuilder(
      column: $table.platformFeePercent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get feeMode => $composableBuilder(
      column: $table.feeMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get semester => $composableBuilder(
      column: $table.semester, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get credits => $composableBuilder(
      column: $table.credits, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get stipendAmount => $composableBuilder(
      column: $table.stipendAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stipendDay => $composableBuilder(
      column: $table.stipendDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProjectsTable> {
  $$LocalProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedOn =>
      $composableBuilder(column: $table.startedOn, builder: (column) => column);

  GeneratedColumn<DateTime> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get clientName => $composableBuilder(
      column: $table.clientName, builder: (column) => column);

  GeneratedColumn<double> get contractValue => $composableBuilder(
      column: $table.contractValue, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get platformFeePercent => $composableBuilder(
      column: $table.platformFeePercent, builder: (column) => column);

  GeneratedColumn<String> get feeMode =>
      $composableBuilder(column: $table.feeMode, builder: (column) => column);

  GeneratedColumn<int> get semester =>
      $composableBuilder(column: $table.semester, builder: (column) => column);

  GeneratedColumn<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => column);

  GeneratedColumn<int> get credits =>
      $composableBuilder(column: $table.credits, builder: (column) => column);

  GeneratedColumn<double> get stipendAmount => $composableBuilder(
      column: $table.stipendAmount, builder: (column) => column);

  GeneratedColumn<int> get stipendDay => $composableBuilder(
      column: $table.stipendDay, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalProjectsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalProjectsTable,
    LocalProject,
    $$LocalProjectsTableFilterComposer,
    $$LocalProjectsTableOrderingComposer,
    $$LocalProjectsTableAnnotationComposer,
    $$LocalProjectsTableCreateCompanionBuilder,
    $$LocalProjectsTableUpdateCompanionBuilder,
    (
      LocalProject,
      BaseReferences<_$AppDatabase, $LocalProjectsTable, LocalProject>
    ),
    LocalProject,
    PrefetchHooks Function()> {
  $$LocalProjectsTableTableManager(_$AppDatabase db, $LocalProjectsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> startedOn = const Value.absent(),
            Value<DateTime?> deadline = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<String?> clientName = const Value.absent(),
            Value<double?> contractValue = const Value.absent(),
            Value<String?> currency = const Value.absent(),
            Value<double?> platformFeePercent = const Value.absent(),
            Value<String?> feeMode = const Value.absent(),
            Value<int?> semester = const Value.absent(),
            Value<String?> courseCode = const Value.absent(),
            Value<int?> credits = const Value.absent(),
            Value<double?> stipendAmount = const Value.absent(),
            Value<int?> stipendDay = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalProjectsCompanion(
            id: id,
            workspaceId: workspaceId,
            kind: kind,
            name: name,
            description: description,
            status: status,
            startedOn: startedOn,
            deadline: deadline,
            color: color,
            clientName: clientName,
            contractValue: contractValue,
            currency: currency,
            platformFeePercent: platformFeePercent,
            feeMode: feeMode,
            semester: semester,
            courseCode: courseCode,
            credits: credits,
            stipendAmount: stipendAmount,
            stipendDay: stipendDay,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String kind,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> startedOn = const Value.absent(),
            Value<DateTime?> deadline = const Value.absent(),
            Value<String?> color = const Value.absent(),
            Value<String?> clientName = const Value.absent(),
            Value<double?> contractValue = const Value.absent(),
            Value<String?> currency = const Value.absent(),
            Value<double?> platformFeePercent = const Value.absent(),
            Value<String?> feeMode = const Value.absent(),
            Value<int?> semester = const Value.absent(),
            Value<String?> courseCode = const Value.absent(),
            Value<int?> credits = const Value.absent(),
            Value<double?> stipendAmount = const Value.absent(),
            Value<int?> stipendDay = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalProjectsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            kind: kind,
            name: name,
            description: description,
            status: status,
            startedOn: startedOn,
            deadline: deadline,
            color: color,
            clientName: clientName,
            contractValue: contractValue,
            currency: currency,
            platformFeePercent: platformFeePercent,
            feeMode: feeMode,
            semester: semester,
            courseCode: courseCode,
            credits: credits,
            stipendAmount: stipendAmount,
            stipendDay: stipendDay,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalProjectsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalProjectsTable,
    LocalProject,
    $$LocalProjectsTableFilterComposer,
    $$LocalProjectsTableOrderingComposer,
    $$LocalProjectsTableAnnotationComposer,
    $$LocalProjectsTableCreateCompanionBuilder,
    $$LocalProjectsTableUpdateCompanionBuilder,
    (
      LocalProject,
      BaseReferences<_$AppDatabase, $LocalProjectsTable, LocalProject>
    ),
    LocalProject,
    PrefetchHooks Function()>;
typedef $$LocalTasksTableCreateCompanionBuilder = LocalTasksCompanion Function({
  required String id,
  required String workspaceId,
  Value<String?> projectId,
  required String kind,
  required String title,
  Value<String?> description,
  Value<String> status,
  Value<String> priority,
  Value<DateTime?> dueAt,
  Value<bool> dueIsDateOnly,
  Value<DateTime?> completedAt,
  Value<String?> milestonePaymentId,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalTasksTableUpdateCompanionBuilder = LocalTasksCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String?> projectId,
  Value<String> kind,
  Value<String> title,
  Value<String?> description,
  Value<String> status,
  Value<String> priority,
  Value<DateTime?> dueAt,
  Value<bool> dueIsDateOnly,
  Value<DateTime?> completedAt,
  Value<String?> milestonePaymentId,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalTasksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
      column: $table.dueAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dueIsDateOnly => $composableBuilder(
      column: $table.dueIsDateOnly, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get milestonePaymentId => $composableBuilder(
      column: $table.milestonePaymentId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
      column: $table.dueAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dueIsDateOnly => $composableBuilder(
      column: $table.dueIsDateOnly,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get milestonePaymentId => $composableBuilder(
      column: $table.milestonePaymentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTasksTable> {
  $$LocalTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get dueIsDateOnly => $composableBuilder(
      column: $table.dueIsDateOnly, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<String> get milestonePaymentId => $composableBuilder(
      column: $table.milestonePaymentId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalTasksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalTasksTable,
    LocalTask,
    $$LocalTasksTableFilterComposer,
    $$LocalTasksTableOrderingComposer,
    $$LocalTasksTableAnnotationComposer,
    $$LocalTasksTableCreateCompanionBuilder,
    $$LocalTasksTableUpdateCompanionBuilder,
    (LocalTask, BaseReferences<_$AppDatabase, $LocalTasksTable, LocalTask>),
    LocalTask,
    PrefetchHooks Function()> {
  $$LocalTasksTableTableManager(_$AppDatabase db, $LocalTasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<DateTime?> dueAt = const Value.absent(),
            Value<bool> dueIsDateOnly = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<String?> milestonePaymentId = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalTasksCompanion(
            id: id,
            workspaceId: workspaceId,
            projectId: projectId,
            kind: kind,
            title: title,
            description: description,
            status: status,
            priority: priority,
            dueAt: dueAt,
            dueIsDateOnly: dueIsDateOnly,
            completedAt: completedAt,
            milestonePaymentId: milestonePaymentId,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            Value<String?> projectId = const Value.absent(),
            required String kind,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> priority = const Value.absent(),
            Value<DateTime?> dueAt = const Value.absent(),
            Value<bool> dueIsDateOnly = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<String?> milestonePaymentId = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalTasksCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            projectId: projectId,
            kind: kind,
            title: title,
            description: description,
            status: status,
            priority: priority,
            dueAt: dueAt,
            dueIsDateOnly: dueIsDateOnly,
            completedAt: completedAt,
            milestonePaymentId: milestonePaymentId,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalTasksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalTasksTable,
    LocalTask,
    $$LocalTasksTableFilterComposer,
    $$LocalTasksTableOrderingComposer,
    $$LocalTasksTableAnnotationComposer,
    $$LocalTasksTableCreateCompanionBuilder,
    $$LocalTasksTableUpdateCompanionBuilder,
    (LocalTask, BaseReferences<_$AppDatabase, $LocalTasksTable, LocalTask>),
    LocalTask,
    PrefetchHooks Function()>;
typedef $$LocalTaskChecklistItemsTableCreateCompanionBuilder
    = LocalTaskChecklistItemsCompanion Function({
  required String id,
  required String taskId,
  required String textContent,
  Value<bool> done,
  Value<int> sortOrder,
  Value<int> rowid,
});
typedef $$LocalTaskChecklistItemsTableUpdateCompanionBuilder
    = LocalTaskChecklistItemsCompanion Function({
  Value<String> id,
  Value<String> taskId,
  Value<String> textContent,
  Value<bool> done,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$LocalTaskChecklistItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTaskChecklistItemsTable> {
  $$LocalTaskChecklistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get textContent => $composableBuilder(
      column: $table.textContent, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get done => $composableBuilder(
      column: $table.done, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));
}

class $$LocalTaskChecklistItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTaskChecklistItemsTable> {
  $$LocalTaskChecklistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get textContent => $composableBuilder(
      column: $table.textContent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get done => $composableBuilder(
      column: $table.done, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));
}

class $$LocalTaskChecklistItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTaskChecklistItemsTable> {
  $$LocalTaskChecklistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
      column: $table.textContent, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$LocalTaskChecklistItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalTaskChecklistItemsTable,
    LocalTaskChecklistItem,
    $$LocalTaskChecklistItemsTableFilterComposer,
    $$LocalTaskChecklistItemsTableOrderingComposer,
    $$LocalTaskChecklistItemsTableAnnotationComposer,
    $$LocalTaskChecklistItemsTableCreateCompanionBuilder,
    $$LocalTaskChecklistItemsTableUpdateCompanionBuilder,
    (
      LocalTaskChecklistItem,
      BaseReferences<_$AppDatabase, $LocalTaskChecklistItemsTable,
          LocalTaskChecklistItem>
    ),
    LocalTaskChecklistItem,
    PrefetchHooks Function()> {
  $$LocalTaskChecklistItemsTableTableManager(
      _$AppDatabase db, $LocalTaskChecklistItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTaskChecklistItemsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTaskChecklistItemsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTaskChecklistItemsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> taskId = const Value.absent(),
            Value<String> textContent = const Value.absent(),
            Value<bool> done = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalTaskChecklistItemsCompanion(
            id: id,
            taskId: taskId,
            textContent: textContent,
            done: done,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String taskId,
            required String textContent,
            Value<bool> done = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalTaskChecklistItemsCompanion.insert(
            id: id,
            taskId: taskId,
            textContent: textContent,
            done: done,
            sortOrder: sortOrder,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalTaskChecklistItemsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalTaskChecklistItemsTable,
        LocalTaskChecklistItem,
        $$LocalTaskChecklistItemsTableFilterComposer,
        $$LocalTaskChecklistItemsTableOrderingComposer,
        $$LocalTaskChecklistItemsTableAnnotationComposer,
        $$LocalTaskChecklistItemsTableCreateCompanionBuilder,
        $$LocalTaskChecklistItemsTableUpdateCompanionBuilder,
        (
          LocalTaskChecklistItem,
          BaseReferences<_$AppDatabase, $LocalTaskChecklistItemsTable,
              LocalTaskChecklistItem>
        ),
        LocalTaskChecklistItem,
        PrefetchHooks Function()>;
typedef $$LocalEventsTableCreateCompanionBuilder = LocalEventsCompanion
    Function({
  required String id,
  required String workspaceId,
  Value<String?> projectId,
  required String kind,
  required String title,
  Value<String?> description,
  Value<String?> location,
  required DateTime startsAt,
  required DateTime endsAt,
  Value<bool> allDay,
  Value<String> timezone,
  Value<String?> recurrence,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalEventsTableUpdateCompanionBuilder = LocalEventsCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String?> projectId,
  Value<String> kind,
  Value<String> title,
  Value<String?> description,
  Value<String?> location,
  Value<DateTime> startsAt,
  Value<DateTime> endsAt,
  Value<bool> allDay,
  Value<String> timezone,
  Value<String?> recurrence,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startsAt => $composableBuilder(
      column: $table.startsAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
      column: $table.endsAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get allDay => $composableBuilder(
      column: $table.allDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timezone => $composableBuilder(
      column: $table.timezone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startsAt => $composableBuilder(
      column: $table.startsAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
      column: $table.endsAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get allDay => $composableBuilder(
      column: $table.allDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timezone => $composableBuilder(
      column: $table.timezone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<DateTime> get startsAt =>
      $composableBuilder(column: $table.startsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
      column: $table.recurrence, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalEventsTable,
    LocalEvent,
    $$LocalEventsTableFilterComposer,
    $$LocalEventsTableOrderingComposer,
    $$LocalEventsTableAnnotationComposer,
    $$LocalEventsTableCreateCompanionBuilder,
    $$LocalEventsTableUpdateCompanionBuilder,
    (LocalEvent, BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>),
    LocalEvent,
    PrefetchHooks Function()> {
  $$LocalEventsTableTableManager(_$AppDatabase db, $LocalEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<DateTime> startsAt = const Value.absent(),
            Value<DateTime> endsAt = const Value.absent(),
            Value<bool> allDay = const Value.absent(),
            Value<String> timezone = const Value.absent(),
            Value<String?> recurrence = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalEventsCompanion(
            id: id,
            workspaceId: workspaceId,
            projectId: projectId,
            kind: kind,
            title: title,
            description: description,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
            allDay: allDay,
            timezone: timezone,
            recurrence: recurrence,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            Value<String?> projectId = const Value.absent(),
            required String kind,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String?> location = const Value.absent(),
            required DateTime startsAt,
            required DateTime endsAt,
            Value<bool> allDay = const Value.absent(),
            Value<String> timezone = const Value.absent(),
            Value<String?> recurrence = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalEventsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            projectId: projectId,
            kind: kind,
            title: title,
            description: description,
            location: location,
            startsAt: startsAt,
            endsAt: endsAt,
            allDay: allDay,
            timezone: timezone,
            recurrence: recurrence,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalEventsTable,
    LocalEvent,
    $$LocalEventsTableFilterComposer,
    $$LocalEventsTableOrderingComposer,
    $$LocalEventsTableAnnotationComposer,
    $$LocalEventsTableCreateCompanionBuilder,
    $$LocalEventsTableUpdateCompanionBuilder,
    (LocalEvent, BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>),
    LocalEvent,
    PrefetchHooks Function()>;
typedef $$LocalProjectPaymentsTableCreateCompanionBuilder
    = LocalProjectPaymentsCompanion Function({
  required String id,
  required String workspaceId,
  required String projectId,
  required String label,
  required double amount,
  Value<DateTime?> dueDate,
  Value<String> status,
  Value<double> paidAmount,
  Value<DateTime?> paidAt,
  Value<String?> accountId,
  Value<String?> transactionId,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalProjectPaymentsTableUpdateCompanionBuilder
    = LocalProjectPaymentsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> projectId,
  Value<String> label,
  Value<double> amount,
  Value<DateTime?> dueDate,
  Value<String> status,
  Value<double> paidAmount,
  Value<DateTime?> paidAt,
  Value<String?> accountId,
  Value<String?> transactionId,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalProjectPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProjectPaymentsTable> {
  $$LocalProjectPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get paidAmount => $composableBuilder(
      column: $table.paidAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
      column: $table.paidAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalProjectPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProjectPaymentsTable> {
  $$LocalProjectPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get paidAmount => $composableBuilder(
      column: $table.paidAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
      column: $table.paidAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transactionId => $composableBuilder(
      column: $table.transactionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalProjectPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProjectPaymentsTable> {
  $$LocalProjectPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get paidAmount => $composableBuilder(
      column: $table.paidAmount, builder: (column) => column);

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
      column: $table.transactionId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalProjectPaymentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalProjectPaymentsTable,
    LocalProjectPayment,
    $$LocalProjectPaymentsTableFilterComposer,
    $$LocalProjectPaymentsTableOrderingComposer,
    $$LocalProjectPaymentsTableAnnotationComposer,
    $$LocalProjectPaymentsTableCreateCompanionBuilder,
    $$LocalProjectPaymentsTableUpdateCompanionBuilder,
    (
      LocalProjectPayment,
      BaseReferences<_$AppDatabase, $LocalProjectPaymentsTable,
          LocalProjectPayment>
    ),
    LocalProjectPayment,
    PrefetchHooks Function()> {
  $$LocalProjectPaymentsTableTableManager(
      _$AppDatabase db, $LocalProjectPaymentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProjectPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProjectPaymentsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProjectPaymentsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<DateTime?> dueDate = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<double> paidAmount = const Value.absent(),
            Value<DateTime?> paidAt = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<String?> transactionId = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalProjectPaymentsCompanion(
            id: id,
            workspaceId: workspaceId,
            projectId: projectId,
            label: label,
            amount: amount,
            dueDate: dueDate,
            status: status,
            paidAmount: paidAmount,
            paidAt: paidAt,
            accountId: accountId,
            transactionId: transactionId,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String projectId,
            required String label,
            required double amount,
            Value<DateTime?> dueDate = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<double> paidAmount = const Value.absent(),
            Value<DateTime?> paidAt = const Value.absent(),
            Value<String?> accountId = const Value.absent(),
            Value<String?> transactionId = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalProjectPaymentsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            projectId: projectId,
            label: label,
            amount: amount,
            dueDate: dueDate,
            status: status,
            paidAmount: paidAmount,
            paidAt: paidAt,
            accountId: accountId,
            transactionId: transactionId,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalProjectPaymentsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalProjectPaymentsTable,
        LocalProjectPayment,
        $$LocalProjectPaymentsTableFilterComposer,
        $$LocalProjectPaymentsTableOrderingComposer,
        $$LocalProjectPaymentsTableAnnotationComposer,
        $$LocalProjectPaymentsTableCreateCompanionBuilder,
        $$LocalProjectPaymentsTableUpdateCompanionBuilder,
        (
          LocalProjectPayment,
          BaseReferences<_$AppDatabase, $LocalProjectPaymentsTable,
              LocalProjectPayment>
        ),
        LocalProjectPayment,
        PrefetchHooks Function()>;
typedef $$LocalAgendaCacheTableCreateCompanionBuilder
    = LocalAgendaCacheCompanion Function({
  required String id,
  required String workspaceId,
  required String itemType,
  required String kind,
  required String title,
  Value<String?> description,
  Value<String?> projectId,
  Value<String?> projectName,
  Value<DateTime?> startsAt,
  Value<DateTime?> endsAt,
  Value<bool> allDay,
  Value<String?> location,
  required String status,
  Value<String?> priority,
  Value<DateTime?> dueAt,
  Value<bool> dueIsDateOnly,
  Value<bool> isOverdue,
  Value<int> checklistTotal,
  Value<int> checklistDone,
  Value<String?> eventId,
  Value<bool> isRecurring,
  Value<String?> milestonePaymentId,
  required String cachedDate,
  Value<int> rowid,
});
typedef $$LocalAgendaCacheTableUpdateCompanionBuilder
    = LocalAgendaCacheCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> itemType,
  Value<String> kind,
  Value<String> title,
  Value<String?> description,
  Value<String?> projectId,
  Value<String?> projectName,
  Value<DateTime?> startsAt,
  Value<DateTime?> endsAt,
  Value<bool> allDay,
  Value<String?> location,
  Value<String> status,
  Value<String?> priority,
  Value<DateTime?> dueAt,
  Value<bool> dueIsDateOnly,
  Value<bool> isOverdue,
  Value<int> checklistTotal,
  Value<int> checklistDone,
  Value<String?> eventId,
  Value<bool> isRecurring,
  Value<String?> milestonePaymentId,
  Value<String> cachedDate,
  Value<int> rowid,
});

class $$LocalAgendaCacheTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAgendaCacheTable> {
  $$LocalAgendaCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemType => $composableBuilder(
      column: $table.itemType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectName => $composableBuilder(
      column: $table.projectName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startsAt => $composableBuilder(
      column: $table.startsAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
      column: $table.endsAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get allDay => $composableBuilder(
      column: $table.allDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
      column: $table.dueAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dueIsDateOnly => $composableBuilder(
      column: $table.dueIsDateOnly, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isOverdue => $composableBuilder(
      column: $table.isOverdue, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get checklistTotal => $composableBuilder(
      column: $table.checklistTotal,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get checklistDone => $composableBuilder(
      column: $table.checklistDone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRecurring => $composableBuilder(
      column: $table.isRecurring, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get milestonePaymentId => $composableBuilder(
      column: $table.milestonePaymentId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cachedDate => $composableBuilder(
      column: $table.cachedDate, builder: (column) => ColumnFilters(column));
}

class $$LocalAgendaCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAgendaCacheTable> {
  $$LocalAgendaCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemType => $composableBuilder(
      column: $table.itemType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectName => $composableBuilder(
      column: $table.projectName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startsAt => $composableBuilder(
      column: $table.startsAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
      column: $table.endsAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get allDay => $composableBuilder(
      column: $table.allDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location => $composableBuilder(
      column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
      column: $table.dueAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dueIsDateOnly => $composableBuilder(
      column: $table.dueIsDateOnly,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isOverdue => $composableBuilder(
      column: $table.isOverdue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get checklistTotal => $composableBuilder(
      column: $table.checklistTotal,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get checklistDone => $composableBuilder(
      column: $table.checklistDone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventId => $composableBuilder(
      column: $table.eventId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRecurring => $composableBuilder(
      column: $table.isRecurring, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get milestonePaymentId => $composableBuilder(
      column: $table.milestonePaymentId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cachedDate => $composableBuilder(
      column: $table.cachedDate, builder: (column) => ColumnOrderings(column));
}

class $$LocalAgendaCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAgendaCacheTable> {
  $$LocalAgendaCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get projectName => $composableBuilder(
      column: $table.projectName, builder: (column) => column);

  GeneratedColumn<DateTime> get startsAt =>
      $composableBuilder(column: $table.startsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get dueIsDateOnly => $composableBuilder(
      column: $table.dueIsDateOnly, builder: (column) => column);

  GeneratedColumn<bool> get isOverdue =>
      $composableBuilder(column: $table.isOverdue, builder: (column) => column);

  GeneratedColumn<int> get checklistTotal => $composableBuilder(
      column: $table.checklistTotal, builder: (column) => column);

  GeneratedColumn<int> get checklistDone => $composableBuilder(
      column: $table.checklistDone, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<bool> get isRecurring => $composableBuilder(
      column: $table.isRecurring, builder: (column) => column);

  GeneratedColumn<String> get milestonePaymentId => $composableBuilder(
      column: $table.milestonePaymentId, builder: (column) => column);

  GeneratedColumn<String> get cachedDate => $composableBuilder(
      column: $table.cachedDate, builder: (column) => column);
}

class $$LocalAgendaCacheTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalAgendaCacheTable,
    LocalAgendaCacheData,
    $$LocalAgendaCacheTableFilterComposer,
    $$LocalAgendaCacheTableOrderingComposer,
    $$LocalAgendaCacheTableAnnotationComposer,
    $$LocalAgendaCacheTableCreateCompanionBuilder,
    $$LocalAgendaCacheTableUpdateCompanionBuilder,
    (
      LocalAgendaCacheData,
      BaseReferences<_$AppDatabase, $LocalAgendaCacheTable,
          LocalAgendaCacheData>
    ),
    LocalAgendaCacheData,
    PrefetchHooks Function()> {
  $$LocalAgendaCacheTableTableManager(
      _$AppDatabase db, $LocalAgendaCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAgendaCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAgendaCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAgendaCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> itemType = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String?> projectName = const Value.absent(),
            Value<DateTime?> startsAt = const Value.absent(),
            Value<DateTime?> endsAt = const Value.absent(),
            Value<bool> allDay = const Value.absent(),
            Value<String?> location = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> priority = const Value.absent(),
            Value<DateTime?> dueAt = const Value.absent(),
            Value<bool> dueIsDateOnly = const Value.absent(),
            Value<bool> isOverdue = const Value.absent(),
            Value<int> checklistTotal = const Value.absent(),
            Value<int> checklistDone = const Value.absent(),
            Value<String?> eventId = const Value.absent(),
            Value<bool> isRecurring = const Value.absent(),
            Value<String?> milestonePaymentId = const Value.absent(),
            Value<String> cachedDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAgendaCacheCompanion(
            id: id,
            workspaceId: workspaceId,
            itemType: itemType,
            kind: kind,
            title: title,
            description: description,
            projectId: projectId,
            projectName: projectName,
            startsAt: startsAt,
            endsAt: endsAt,
            allDay: allDay,
            location: location,
            status: status,
            priority: priority,
            dueAt: dueAt,
            dueIsDateOnly: dueIsDateOnly,
            isOverdue: isOverdue,
            checklistTotal: checklistTotal,
            checklistDone: checklistDone,
            eventId: eventId,
            isRecurring: isRecurring,
            milestonePaymentId: milestonePaymentId,
            cachedDate: cachedDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String itemType,
            required String kind,
            required String title,
            Value<String?> description = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String?> projectName = const Value.absent(),
            Value<DateTime?> startsAt = const Value.absent(),
            Value<DateTime?> endsAt = const Value.absent(),
            Value<bool> allDay = const Value.absent(),
            Value<String?> location = const Value.absent(),
            required String status,
            Value<String?> priority = const Value.absent(),
            Value<DateTime?> dueAt = const Value.absent(),
            Value<bool> dueIsDateOnly = const Value.absent(),
            Value<bool> isOverdue = const Value.absent(),
            Value<int> checklistTotal = const Value.absent(),
            Value<int> checklistDone = const Value.absent(),
            Value<String?> eventId = const Value.absent(),
            Value<bool> isRecurring = const Value.absent(),
            Value<String?> milestonePaymentId = const Value.absent(),
            required String cachedDate,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalAgendaCacheCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            itemType: itemType,
            kind: kind,
            title: title,
            description: description,
            projectId: projectId,
            projectName: projectName,
            startsAt: startsAt,
            endsAt: endsAt,
            allDay: allDay,
            location: location,
            status: status,
            priority: priority,
            dueAt: dueAt,
            dueIsDateOnly: dueIsDateOnly,
            isOverdue: isOverdue,
            checklistTotal: checklistTotal,
            checklistDone: checklistDone,
            eventId: eventId,
            isRecurring: isRecurring,
            milestonePaymentId: milestonePaymentId,
            cachedDate: cachedDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalAgendaCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalAgendaCacheTable,
    LocalAgendaCacheData,
    $$LocalAgendaCacheTableFilterComposer,
    $$LocalAgendaCacheTableOrderingComposer,
    $$LocalAgendaCacheTableAnnotationComposer,
    $$LocalAgendaCacheTableCreateCompanionBuilder,
    $$LocalAgendaCacheTableUpdateCompanionBuilder,
    (
      LocalAgendaCacheData,
      BaseReferences<_$AppDatabase, $LocalAgendaCacheTable,
          LocalAgendaCacheData>
    ),
    LocalAgendaCacheData,
    PrefetchHooks Function()>;
typedef $$LocalBudgetsTableCreateCompanionBuilder = LocalBudgetsCompanion
    Function({
  required String id,
  required String workspaceId,
  required String categoryId,
  required double amount,
  Value<String> period,
  Value<bool> rollover,
  Value<double> notifyAtPercent,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalBudgetsTableUpdateCompanionBuilder = LocalBudgetsCompanion
    Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> categoryId,
  Value<double> amount,
  Value<String> period,
  Value<bool> rollover,
  Value<double> notifyAtPercent,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalBudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get rollover => $composableBuilder(
      column: $table.rollover, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get notifyAtPercent => $composableBuilder(
      column: $table.notifyAtPercent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalBudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get rollover => $composableBuilder(
      column: $table.rollover, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get notifyAtPercent => $composableBuilder(
      column: $table.notifyAtPercent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalBudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBudgetsTable> {
  $$LocalBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<bool> get rollover =>
      $composableBuilder(column: $table.rollover, builder: (column) => column);

  GeneratedColumn<double> get notifyAtPercent => $composableBuilder(
      column: $table.notifyAtPercent, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalBudgetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalBudgetsTable,
    LocalBudget,
    $$LocalBudgetsTableFilterComposer,
    $$LocalBudgetsTableOrderingComposer,
    $$LocalBudgetsTableAnnotationComposer,
    $$LocalBudgetsTableCreateCompanionBuilder,
    $$LocalBudgetsTableUpdateCompanionBuilder,
    (
      LocalBudget,
      BaseReferences<_$AppDatabase, $LocalBudgetsTable, LocalBudget>
    ),
    LocalBudget,
    PrefetchHooks Function()> {
  $$LocalBudgetsTableTableManager(_$AppDatabase db, $LocalBudgetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> period = const Value.absent(),
            Value<bool> rollover = const Value.absent(),
            Value<double> notifyAtPercent = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalBudgetsCompanion(
            id: id,
            workspaceId: workspaceId,
            categoryId: categoryId,
            amount: amount,
            period: period,
            rollover: rollover,
            notifyAtPercent: notifyAtPercent,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String categoryId,
            required double amount,
            Value<String> period = const Value.absent(),
            Value<bool> rollover = const Value.absent(),
            Value<double> notifyAtPercent = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalBudgetsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            categoryId: categoryId,
            amount: amount,
            period: period,
            rollover: rollover,
            notifyAtPercent: notifyAtPercent,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalBudgetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalBudgetsTable,
    LocalBudget,
    $$LocalBudgetsTableFilterComposer,
    $$LocalBudgetsTableOrderingComposer,
    $$LocalBudgetsTableAnnotationComposer,
    $$LocalBudgetsTableCreateCompanionBuilder,
    $$LocalBudgetsTableUpdateCompanionBuilder,
    (
      LocalBudget,
      BaseReferences<_$AppDatabase, $LocalBudgetsTable, LocalBudget>
    ),
    LocalBudget,
    PrefetchHooks Function()>;
typedef $$LocalRecurringBillsTableCreateCompanionBuilder
    = LocalRecurringBillsCompanion Function({
  required String id,
  required String workspaceId,
  required String name,
  required double amount,
  required String categoryId,
  required String accountId,
  Value<String> scheduleType,
  Value<int> scheduleValue,
  Value<String> remindDaysBefore,
  Value<bool> active,
  Value<bool> autoCreateDraft,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalRecurringBillsTableUpdateCompanionBuilder
    = LocalRecurringBillsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> name,
  Value<double> amount,
  Value<String> categoryId,
  Value<String> accountId,
  Value<String> scheduleType,
  Value<int> scheduleValue,
  Value<String> remindDaysBefore,
  Value<bool> active,
  Value<bool> autoCreateDraft,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalRecurringBillsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalRecurringBillsTable> {
  $$LocalRecurringBillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scheduleType => $composableBuilder(
      column: $table.scheduleType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scheduleValue => $composableBuilder(
      column: $table.scheduleValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remindDaysBefore => $composableBuilder(
      column: $table.remindDaysBefore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get autoCreateDraft => $composableBuilder(
      column: $table.autoCreateDraft,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalRecurringBillsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalRecurringBillsTable> {
  $$LocalRecurringBillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount => $composableBuilder(
      column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scheduleType => $composableBuilder(
      column: $table.scheduleType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scheduleValue => $composableBuilder(
      column: $table.scheduleValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remindDaysBefore => $composableBuilder(
      column: $table.remindDaysBefore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get autoCreateDraft => $composableBuilder(
      column: $table.autoCreateDraft,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalRecurringBillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalRecurringBillsTable> {
  $$LocalRecurringBillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get scheduleType => $composableBuilder(
      column: $table.scheduleType, builder: (column) => column);

  GeneratedColumn<int> get scheduleValue => $composableBuilder(
      column: $table.scheduleValue, builder: (column) => column);

  GeneratedColumn<String> get remindDaysBefore => $composableBuilder(
      column: $table.remindDaysBefore, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<bool> get autoCreateDraft => $composableBuilder(
      column: $table.autoCreateDraft, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalRecurringBillsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalRecurringBillsTable,
    LocalRecurringBill,
    $$LocalRecurringBillsTableFilterComposer,
    $$LocalRecurringBillsTableOrderingComposer,
    $$LocalRecurringBillsTableAnnotationComposer,
    $$LocalRecurringBillsTableCreateCompanionBuilder,
    $$LocalRecurringBillsTableUpdateCompanionBuilder,
    (
      LocalRecurringBill,
      BaseReferences<_$AppDatabase, $LocalRecurringBillsTable,
          LocalRecurringBill>
    ),
    LocalRecurringBill,
    PrefetchHooks Function()> {
  $$LocalRecurringBillsTableTableManager(
      _$AppDatabase db, $LocalRecurringBillsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalRecurringBillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalRecurringBillsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalRecurringBillsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> amount = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> scheduleType = const Value.absent(),
            Value<int> scheduleValue = const Value.absent(),
            Value<String> remindDaysBefore = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<bool> autoCreateDraft = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalRecurringBillsCompanion(
            id: id,
            workspaceId: workspaceId,
            name: name,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            scheduleType: scheduleType,
            scheduleValue: scheduleValue,
            remindDaysBefore: remindDaysBefore,
            active: active,
            autoCreateDraft: autoCreateDraft,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String name,
            required double amount,
            required String categoryId,
            required String accountId,
            Value<String> scheduleType = const Value.absent(),
            Value<int> scheduleValue = const Value.absent(),
            Value<String> remindDaysBefore = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<bool> autoCreateDraft = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalRecurringBillsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            name: name,
            amount: amount,
            categoryId: categoryId,
            accountId: accountId,
            scheduleType: scheduleType,
            scheduleValue: scheduleValue,
            remindDaysBefore: remindDaysBefore,
            active: active,
            autoCreateDraft: autoCreateDraft,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalRecurringBillsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalRecurringBillsTable,
    LocalRecurringBill,
    $$LocalRecurringBillsTableFilterComposer,
    $$LocalRecurringBillsTableOrderingComposer,
    $$LocalRecurringBillsTableAnnotationComposer,
    $$LocalRecurringBillsTableCreateCompanionBuilder,
    $$LocalRecurringBillsTableUpdateCompanionBuilder,
    (
      LocalRecurringBill,
      BaseReferences<_$AppDatabase, $LocalRecurringBillsTable,
          LocalRecurringBill>
    ),
    LocalRecurringBill,
    PrefetchHooks Function()>;
typedef $$LocalSavingsGoalsTableCreateCompanionBuilder
    = LocalSavingsGoalsCompanion Function({
  required String id,
  required String workspaceId,
  required String name,
  required double targetAmount,
  Value<double> currentAmount,
  Value<DateTime?> targetDate,
  Value<bool> isCompleted,
  Value<String?> notes,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalSavingsGoalsTableUpdateCompanionBuilder
    = LocalSavingsGoalsCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> name,
  Value<double> targetAmount,
  Value<double> currentAmount,
  Value<DateTime?> targetDate,
  Value<bool> isCompleted,
  Value<String?> notes,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalSavingsGoalsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSavingsGoalsTable> {
  $$LocalSavingsGoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalSavingsGoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSavingsGoalsTable> {
  $$LocalSavingsGoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalSavingsGoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSavingsGoalsTable> {
  $$LocalSavingsGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get targetAmount => $composableBuilder(
      column: $table.targetAmount, builder: (column) => column);

  GeneratedColumn<double> get currentAmount => $composableBuilder(
      column: $table.currentAmount, builder: (column) => column);

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalSavingsGoalsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalSavingsGoalsTable,
    LocalSavingsGoal,
    $$LocalSavingsGoalsTableFilterComposer,
    $$LocalSavingsGoalsTableOrderingComposer,
    $$LocalSavingsGoalsTableAnnotationComposer,
    $$LocalSavingsGoalsTableCreateCompanionBuilder,
    $$LocalSavingsGoalsTableUpdateCompanionBuilder,
    (
      LocalSavingsGoal,
      BaseReferences<_$AppDatabase, $LocalSavingsGoalsTable, LocalSavingsGoal>
    ),
    LocalSavingsGoal,
    PrefetchHooks Function()> {
  $$LocalSavingsGoalsTableTableManager(
      _$AppDatabase db, $LocalSavingsGoalsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSavingsGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSavingsGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSavingsGoalsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> targetAmount = const Value.absent(),
            Value<double> currentAmount = const Value.absent(),
            Value<DateTime?> targetDate = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSavingsGoalsCompanion(
            id: id,
            workspaceId: workspaceId,
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
            isCompleted: isCompleted,
            notes: notes,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String name,
            required double targetAmount,
            Value<double> currentAmount = const Value.absent(),
            Value<DateTime?> targetDate = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSavingsGoalsCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
            isCompleted: isCompleted,
            notes: notes,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSavingsGoalsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalSavingsGoalsTable,
    LocalSavingsGoal,
    $$LocalSavingsGoalsTableFilterComposer,
    $$LocalSavingsGoalsTableOrderingComposer,
    $$LocalSavingsGoalsTableAnnotationComposer,
    $$LocalSavingsGoalsTableCreateCompanionBuilder,
    $$LocalSavingsGoalsTableUpdateCompanionBuilder,
    (
      LocalSavingsGoal,
      BaseReferences<_$AppDatabase, $LocalSavingsGoalsTable, LocalSavingsGoal>
    ),
    LocalSavingsGoal,
    PrefetchHooks Function()>;
typedef $$LocalIncomeSplitRulesTableCreateCompanionBuilder
    = LocalIncomeSplitRulesCompanion Function({
  required String id,
  required String workspaceId,
  required String source,
  required String goalId,
  Value<String> splitType,
  required double splitValue,
  Value<int> priority,
  Value<bool> active,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$LocalIncomeSplitRulesTableUpdateCompanionBuilder
    = LocalIncomeSplitRulesCompanion Function({
  Value<String> id,
  Value<String> workspaceId,
  Value<String> source,
  Value<String> goalId,
  Value<String> splitType,
  Value<double> splitValue,
  Value<int> priority,
  Value<bool> active,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$LocalIncomeSplitRulesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalIncomeSplitRulesTable> {
  $$LocalIncomeSplitRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get goalId => $composableBuilder(
      column: $table.goalId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get splitType => $composableBuilder(
      column: $table.splitType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get splitValue => $composableBuilder(
      column: $table.splitValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalIncomeSplitRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalIncomeSplitRulesTable> {
  $$LocalIncomeSplitRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get goalId => $composableBuilder(
      column: $table.goalId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get splitType => $composableBuilder(
      column: $table.splitType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get splitValue => $composableBuilder(
      column: $table.splitValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get active => $composableBuilder(
      column: $table.active, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalIncomeSplitRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalIncomeSplitRulesTable> {
  $$LocalIncomeSplitRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workspaceId => $composableBuilder(
      column: $table.workspaceId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<String> get splitType =>
      $composableBuilder(column: $table.splitType, builder: (column) => column);

  GeneratedColumn<double> get splitValue => $composableBuilder(
      column: $table.splitValue, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$LocalIncomeSplitRulesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalIncomeSplitRulesTable,
    LocalIncomeSplitRule,
    $$LocalIncomeSplitRulesTableFilterComposer,
    $$LocalIncomeSplitRulesTableOrderingComposer,
    $$LocalIncomeSplitRulesTableAnnotationComposer,
    $$LocalIncomeSplitRulesTableCreateCompanionBuilder,
    $$LocalIncomeSplitRulesTableUpdateCompanionBuilder,
    (
      LocalIncomeSplitRule,
      BaseReferences<_$AppDatabase, $LocalIncomeSplitRulesTable,
          LocalIncomeSplitRule>
    ),
    LocalIncomeSplitRule,
    PrefetchHooks Function()> {
  $$LocalIncomeSplitRulesTableTableManager(
      _$AppDatabase db, $LocalIncomeSplitRulesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalIncomeSplitRulesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalIncomeSplitRulesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalIncomeSplitRulesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> workspaceId = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String> goalId = const Value.absent(),
            Value<String> splitType = const Value.absent(),
            Value<double> splitValue = const Value.absent(),
            Value<int> priority = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalIncomeSplitRulesCompanion(
            id: id,
            workspaceId: workspaceId,
            source: source,
            goalId: goalId,
            splitType: splitType,
            splitValue: splitValue,
            priority: priority,
            active: active,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String workspaceId,
            required String source,
            required String goalId,
            Value<String> splitType = const Value.absent(),
            required double splitValue,
            Value<int> priority = const Value.absent(),
            Value<bool> active = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalIncomeSplitRulesCompanion.insert(
            id: id,
            workspaceId: workspaceId,
            source: source,
            goalId: goalId,
            splitType: splitType,
            splitValue: splitValue,
            priority: priority,
            active: active,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalIncomeSplitRulesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalIncomeSplitRulesTable,
        LocalIncomeSplitRule,
        $$LocalIncomeSplitRulesTableFilterComposer,
        $$LocalIncomeSplitRulesTableOrderingComposer,
        $$LocalIncomeSplitRulesTableAnnotationComposer,
        $$LocalIncomeSplitRulesTableCreateCompanionBuilder,
        $$LocalIncomeSplitRulesTableUpdateCompanionBuilder,
        (
          LocalIncomeSplitRule,
          BaseReferences<_$AppDatabase, $LocalIncomeSplitRulesTable,
              LocalIncomeSplitRule>
        ),
        LocalIncomeSplitRule,
        PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalAccountsTableTableManager get localAccounts =>
      $$LocalAccountsTableTableManager(_db, _db.localAccounts);
  $$LocalCategoriesTableTableManager get localCategories =>
      $$LocalCategoriesTableTableManager(_db, _db.localCategories);
  $$LocalTransactionsTableTableManager get localTransactions =>
      $$LocalTransactionsTableTableManager(_db, _db.localTransactions);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$LocalProjectsTableTableManager get localProjects =>
      $$LocalProjectsTableTableManager(_db, _db.localProjects);
  $$LocalTasksTableTableManager get localTasks =>
      $$LocalTasksTableTableManager(_db, _db.localTasks);
  $$LocalTaskChecklistItemsTableTableManager get localTaskChecklistItems =>
      $$LocalTaskChecklistItemsTableTableManager(
          _db, _db.localTaskChecklistItems);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db, _db.localEvents);
  $$LocalProjectPaymentsTableTableManager get localProjectPayments =>
      $$LocalProjectPaymentsTableTableManager(_db, _db.localProjectPayments);
  $$LocalAgendaCacheTableTableManager get localAgendaCache =>
      $$LocalAgendaCacheTableTableManager(_db, _db.localAgendaCache);
  $$LocalBudgetsTableTableManager get localBudgets =>
      $$LocalBudgetsTableTableManager(_db, _db.localBudgets);
  $$LocalRecurringBillsTableTableManager get localRecurringBills =>
      $$LocalRecurringBillsTableTableManager(_db, _db.localRecurringBills);
  $$LocalSavingsGoalsTableTableManager get localSavingsGoals =>
      $$LocalSavingsGoalsTableTableManager(_db, _db.localSavingsGoals);
  $$LocalIncomeSplitRulesTableTableManager get localIncomeSplitRules =>
      $$LocalIncomeSplitRulesTableTableManager(_db, _db.localIncomeSplitRules);
}
