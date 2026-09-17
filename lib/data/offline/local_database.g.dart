// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $LocalCustomersTable extends LocalCustomers
    with TableInfo<$LocalCustomersTable, LocalCustomerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    name,
    phone,
    notes,
    createdAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCustomerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCustomerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCustomerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $LocalCustomersTable createAlias(String alias) {
    return $LocalCustomersTable(attachedDatabase, alias);
  }
}

class LocalCustomerRow extends DataClass
    implements Insertable<LocalCustomerRow> {
  final String id;
  final String tenantId;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime? createdAt;
  final bool synced;
  const LocalCustomerRow({
    required this.id,
    required this.tenantId,
    required this.name,
    this.phone,
    this.notes,
    this.createdAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  LocalCustomersCompanion toCompanion(bool nullToAbsent) {
    return LocalCustomersCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      synced: Value(synced),
    );
  }

  factory LocalCustomerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCustomerRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  LocalCustomerRow copyWith({
    String? id,
    String? tenantId,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    bool? synced,
  }) => LocalCustomerRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    synced: synced ?? this.synced,
  );
  LocalCustomerRow copyWithCompanion(LocalCustomersCompanion data) {
    return LocalCustomerRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomerRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, tenantId, name, phone, notes, createdAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCustomerRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class LocalCustomersCompanion extends UpdateCompanion<LocalCustomerRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> notes;
  final Value<DateTime?> createdAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const LocalCustomersCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCustomersCompanion.insert({
    required String id,
    required String tenantId,
    required String name,
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       name = Value(name);
  static Insertable<LocalCustomerRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? notes,
    Value<DateTime?>? createdAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return LocalCustomersCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCustomersCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSuppliersTable extends LocalSuppliers
    with TableInfo<$LocalSuppliersTable, LocalSupplierRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dealTypeMeta = const VerificationMeta(
    'dealType',
  );
  @override
  late final GeneratedColumn<String> dealType = GeneratedColumn<String>(
    'deal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('direct'),
  );
  static const VerificationMeta _commissionRateMeta = const VerificationMeta(
    'commissionRate',
  );
  @override
  late final GeneratedColumn<double> commissionRate = GeneratedColumn<double>(
    'commission_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    name,
    phone,
    notes,
    dealType,
    commissionRate,
    createdAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSupplierRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('deal_type')) {
      context.handle(
        _dealTypeMeta,
        dealType.isAcceptableOrUnknown(data['deal_type']!, _dealTypeMeta),
      );
    }
    if (data.containsKey('commission_rate')) {
      context.handle(
        _commissionRateMeta,
        commissionRate.isAcceptableOrUnknown(
          data['commission_rate']!,
          _commissionRateMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSupplierRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSupplierRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      dealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deal_type'],
      )!,
      commissionRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}commission_rate'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $LocalSuppliersTable createAlias(String alias) {
    return $LocalSuppliersTable(attachedDatabase, alias);
  }
}

class LocalSupplierRow extends DataClass
    implements Insertable<LocalSupplierRow> {
  final String id;
  final String tenantId;
  final String name;
  final String? phone;
  final String? notes;
  final String dealType;
  final double? commissionRate;
  final DateTime? createdAt;
  final bool synced;
  const LocalSupplierRow({
    required this.id,
    required this.tenantId,
    required this.name,
    this.phone,
    this.notes,
    required this.dealType,
    this.commissionRate,
    this.createdAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['deal_type'] = Variable<String>(dealType);
    if (!nullToAbsent || commissionRate != null) {
      map['commission_rate'] = Variable<double>(commissionRate);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  LocalSuppliersCompanion toCompanion(bool nullToAbsent) {
    return LocalSuppliersCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      dealType: Value(dealType),
      commissionRate: commissionRate == null && nullToAbsent
          ? const Value.absent()
          : Value(commissionRate),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      synced: Value(synced),
    );
  }

  factory LocalSupplierRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSupplierRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      notes: serializer.fromJson<String?>(json['notes']),
      dealType: serializer.fromJson<String>(json['dealType']),
      commissionRate: serializer.fromJson<double?>(json['commissionRate']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'notes': serializer.toJson<String?>(notes),
      'dealType': serializer.toJson<String>(dealType),
      'commissionRate': serializer.toJson<double?>(commissionRate),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  LocalSupplierRow copyWith({
    String? id,
    String? tenantId,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? dealType,
    Value<double?> commissionRate = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    bool? synced,
  }) => LocalSupplierRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    notes: notes.present ? notes.value : this.notes,
    dealType: dealType ?? this.dealType,
    commissionRate: commissionRate.present
        ? commissionRate.value
        : this.commissionRate,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    synced: synced ?? this.synced,
  );
  LocalSupplierRow copyWithCompanion(LocalSuppliersCompanion data) {
    return LocalSupplierRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      notes: data.notes.present ? data.notes.value : this.notes,
      dealType: data.dealType.present ? data.dealType.value : this.dealType,
      commissionRate: data.commissionRate.present
          ? data.commissionRate.value
          : this.commissionRate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSupplierRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('dealType: $dealType, ')
          ..write('commissionRate: $commissionRate, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    name,
    phone,
    notes,
    dealType,
    commissionRate,
    createdAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSupplierRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.notes == this.notes &&
          other.dealType == this.dealType &&
          other.commissionRate == this.commissionRate &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class LocalSuppliersCompanion extends UpdateCompanion<LocalSupplierRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> notes;
  final Value<String> dealType;
  final Value<double?> commissionRate;
  final Value<DateTime?> createdAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const LocalSuppliersCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.dealType = const Value.absent(),
    this.commissionRate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSuppliersCompanion.insert({
    required String id,
    required String tenantId,
    required String name,
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.dealType = const Value.absent(),
    this.commissionRate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       name = Value(name);
  static Insertable<LocalSupplierRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? notes,
    Expression<String>? dealType,
    Expression<double>? commissionRate,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      if (dealType != null) 'deal_type': dealType,
      if (commissionRate != null) 'commission_rate': commissionRate,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSuppliersCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? notes,
    Value<String>? dealType,
    Value<double?>? commissionRate,
    Value<DateTime?>? createdAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return LocalSuppliersCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      dealType: dealType ?? this.dealType,
      commissionRate: commissionRate ?? this.commissionRate,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (dealType.present) {
      map['deal_type'] = Variable<String>(dealType.value);
    }
    if (commissionRate.present) {
      map['commission_rate'] = Variable<double>(commissionRate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSuppliersCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('dealType: $dealType, ')
          ..write('commissionRate: $commissionRate, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalProductsTable extends LocalProducts
    with TableInfo<$LocalProductsTable, LocalProductRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitTypeMeta = const VerificationMeta(
    'unitType',
  );
  @override
  late final GeneratedColumn<String> unitType = GeneratedColumn<String>(
    'unit_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('count'),
  );
  static const VerificationMeta _salePriceMeta = const VerificationMeta(
    'salePrice',
  );
  @override
  late final GeneratedColumn<int> salePrice = GeneratedColumn<int>(
    'sale_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchasePriceMeta = const VerificationMeta(
    'purchasePrice',
  );
  @override
  late final GeneratedColumn<int> purchasePrice = GeneratedColumn<int>(
    'purchase_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reorderLevelMeta = const VerificationMeta(
    'reorderLevel',
  );
  @override
  late final GeneratedColumn<double> reorderLevel = GeneratedColumn<double>(
    'reorder_level',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commissionRateMeta = const VerificationMeta(
    'commissionRate',
  );
  @override
  late final GeneratedColumn<double> commissionRate = GeneratedColumn<double>(
    'commission_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    name,
    barcode,
    unit,
    unitType,
    salePrice,
    purchasePrice,
    qty,
    reorderLevel,
    supplierId,
    commissionRate,
    createdAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProductRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('unit_type')) {
      context.handle(
        _unitTypeMeta,
        unitType.isAcceptableOrUnknown(data['unit_type']!, _unitTypeMeta),
      );
    }
    if (data.containsKey('sale_price')) {
      context.handle(
        _salePriceMeta,
        salePrice.isAcceptableOrUnknown(data['sale_price']!, _salePriceMeta),
      );
    } else if (isInserting) {
      context.missing(_salePriceMeta);
    }
    if (data.containsKey('purchase_price')) {
      context.handle(
        _purchasePriceMeta,
        purchasePrice.isAcceptableOrUnknown(
          data['purchase_price']!,
          _purchasePriceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_purchasePriceMeta);
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    }
    if (data.containsKey('reorder_level')) {
      context.handle(
        _reorderLevelMeta,
        reorderLevel.isAcceptableOrUnknown(
          data['reorder_level']!,
          _reorderLevelMeta,
        ),
      );
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    }
    if (data.containsKey('commission_rate')) {
      context.handle(
        _commissionRateMeta,
        commissionRate.isAcceptableOrUnknown(
          data['commission_rate']!,
          _commissionRateMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProductRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProductRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      unitType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_type'],
      )!,
      salePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sale_price'],
      )!,
      purchasePrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}purchase_price'],
      )!,
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty'],
      )!,
      reorderLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reorder_level'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      ),
      commissionRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}commission_rate'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $LocalProductsTable createAlias(String alias) {
    return $LocalProductsTable(attachedDatabase, alias);
  }
}

class LocalProductRow extends DataClass implements Insertable<LocalProductRow> {
  final String id;
  final String tenantId;
  final String name;
  final String? barcode;
  final String unit;
  final String unitType;
  final int salePrice;
  final int purchasePrice;
  final double qty;
  final double reorderLevel;
  final String? supplierId;
  final double? commissionRate;
  final DateTime? createdAt;
  final bool synced;
  const LocalProductRow({
    required this.id,
    required this.tenantId,
    required this.name,
    this.barcode,
    required this.unit,
    required this.unitType,
    required this.salePrice,
    required this.purchasePrice,
    required this.qty,
    required this.reorderLevel,
    this.supplierId,
    this.commissionRate,
    this.createdAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['unit'] = Variable<String>(unit);
    map['unit_type'] = Variable<String>(unitType);
    map['sale_price'] = Variable<int>(salePrice);
    map['purchase_price'] = Variable<int>(purchasePrice);
    map['qty'] = Variable<double>(qty);
    map['reorder_level'] = Variable<double>(reorderLevel);
    if (!nullToAbsent || supplierId != null) {
      map['supplier_id'] = Variable<String>(supplierId);
    }
    if (!nullToAbsent || commissionRate != null) {
      map['commission_rate'] = Variable<double>(commissionRate);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  LocalProductsCompanion toCompanion(bool nullToAbsent) {
    return LocalProductsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      name: Value(name),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      unit: Value(unit),
      unitType: Value(unitType),
      salePrice: Value(salePrice),
      purchasePrice: Value(purchasePrice),
      qty: Value(qty),
      reorderLevel: Value(reorderLevel),
      supplierId: supplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierId),
      commissionRate: commissionRate == null && nullToAbsent
          ? const Value.absent()
          : Value(commissionRate),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      synced: Value(synced),
    );
  }

  factory LocalProductRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProductRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      name: serializer.fromJson<String>(json['name']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      unit: serializer.fromJson<String>(json['unit']),
      unitType: serializer.fromJson<String>(json['unitType']),
      salePrice: serializer.fromJson<int>(json['salePrice']),
      purchasePrice: serializer.fromJson<int>(json['purchasePrice']),
      qty: serializer.fromJson<double>(json['qty']),
      reorderLevel: serializer.fromJson<double>(json['reorderLevel']),
      supplierId: serializer.fromJson<String?>(json['supplierId']),
      commissionRate: serializer.fromJson<double?>(json['commissionRate']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'name': serializer.toJson<String>(name),
      'barcode': serializer.toJson<String?>(barcode),
      'unit': serializer.toJson<String>(unit),
      'unitType': serializer.toJson<String>(unitType),
      'salePrice': serializer.toJson<int>(salePrice),
      'purchasePrice': serializer.toJson<int>(purchasePrice),
      'qty': serializer.toJson<double>(qty),
      'reorderLevel': serializer.toJson<double>(reorderLevel),
      'supplierId': serializer.toJson<String?>(supplierId),
      'commissionRate': serializer.toJson<double?>(commissionRate),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  LocalProductRow copyWith({
    String? id,
    String? tenantId,
    String? name,
    Value<String?> barcode = const Value.absent(),
    String? unit,
    String? unitType,
    int? salePrice,
    int? purchasePrice,
    double? qty,
    double? reorderLevel,
    Value<String?> supplierId = const Value.absent(),
    Value<double?> commissionRate = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    bool? synced,
  }) => LocalProductRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    name: name ?? this.name,
    barcode: barcode.present ? barcode.value : this.barcode,
    unit: unit ?? this.unit,
    unitType: unitType ?? this.unitType,
    salePrice: salePrice ?? this.salePrice,
    purchasePrice: purchasePrice ?? this.purchasePrice,
    qty: qty ?? this.qty,
    reorderLevel: reorderLevel ?? this.reorderLevel,
    supplierId: supplierId.present ? supplierId.value : this.supplierId,
    commissionRate: commissionRate.present
        ? commissionRate.value
        : this.commissionRate,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    synced: synced ?? this.synced,
  );
  LocalProductRow copyWithCompanion(LocalProductsCompanion data) {
    return LocalProductRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      name: data.name.present ? data.name.value : this.name,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      unit: data.unit.present ? data.unit.value : this.unit,
      unitType: data.unitType.present ? data.unitType.value : this.unitType,
      salePrice: data.salePrice.present ? data.salePrice.value : this.salePrice,
      purchasePrice: data.purchasePrice.present
          ? data.purchasePrice.value
          : this.purchasePrice,
      qty: data.qty.present ? data.qty.value : this.qty,
      reorderLevel: data.reorderLevel.present
          ? data.reorderLevel.value
          : this.reorderLevel,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      commissionRate: data.commissionRate.present
          ? data.commissionRate.value
          : this.commissionRate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProductRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('barcode: $barcode, ')
          ..write('unit: $unit, ')
          ..write('unitType: $unitType, ')
          ..write('salePrice: $salePrice, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('qty: $qty, ')
          ..write('reorderLevel: $reorderLevel, ')
          ..write('supplierId: $supplierId, ')
          ..write('commissionRate: $commissionRate, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    name,
    barcode,
    unit,
    unitType,
    salePrice,
    purchasePrice,
    qty,
    reorderLevel,
    supplierId,
    commissionRate,
    createdAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProductRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.name == this.name &&
          other.barcode == this.barcode &&
          other.unit == this.unit &&
          other.unitType == this.unitType &&
          other.salePrice == this.salePrice &&
          other.purchasePrice == this.purchasePrice &&
          other.qty == this.qty &&
          other.reorderLevel == this.reorderLevel &&
          other.supplierId == this.supplierId &&
          other.commissionRate == this.commissionRate &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class LocalProductsCompanion extends UpdateCompanion<LocalProductRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> name;
  final Value<String?> barcode;
  final Value<String> unit;
  final Value<String> unitType;
  final Value<int> salePrice;
  final Value<int> purchasePrice;
  final Value<double> qty;
  final Value<double> reorderLevel;
  final Value<String?> supplierId;
  final Value<double?> commissionRate;
  final Value<DateTime?> createdAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const LocalProductsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.name = const Value.absent(),
    this.barcode = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitType = const Value.absent(),
    this.salePrice = const Value.absent(),
    this.purchasePrice = const Value.absent(),
    this.qty = const Value.absent(),
    this.reorderLevel = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.commissionRate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProductsCompanion.insert({
    required String id,
    required String tenantId,
    required String name,
    this.barcode = const Value.absent(),
    required String unit,
    this.unitType = const Value.absent(),
    required int salePrice,
    required int purchasePrice,
    this.qty = const Value.absent(),
    this.reorderLevel = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.commissionRate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       name = Value(name),
       unit = Value(unit),
       salePrice = Value(salePrice),
       purchasePrice = Value(purchasePrice);
  static Insertable<LocalProductRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? name,
    Expression<String>? barcode,
    Expression<String>? unit,
    Expression<String>? unitType,
    Expression<int>? salePrice,
    Expression<int>? purchasePrice,
    Expression<double>? qty,
    Expression<double>? reorderLevel,
    Expression<String>? supplierId,
    Expression<double>? commissionRate,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (name != null) 'name': name,
      if (barcode != null) 'barcode': barcode,
      if (unit != null) 'unit': unit,
      if (unitType != null) 'unit_type': unitType,
      if (salePrice != null) 'sale_price': salePrice,
      if (purchasePrice != null) 'purchase_price': purchasePrice,
      if (qty != null) 'qty': qty,
      if (reorderLevel != null) 'reorder_level': reorderLevel,
      if (supplierId != null) 'supplier_id': supplierId,
      if (commissionRate != null) 'commission_rate': commissionRate,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? name,
    Value<String?>? barcode,
    Value<String>? unit,
    Value<String>? unitType,
    Value<int>? salePrice,
    Value<int>? purchasePrice,
    Value<double>? qty,
    Value<double>? reorderLevel,
    Value<String?>? supplierId,
    Value<double?>? commissionRate,
    Value<DateTime?>? createdAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return LocalProductsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      unitType: unitType ?? this.unitType,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      qty: qty ?? this.qty,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      supplierId: supplierId ?? this.supplierId,
      commissionRate: commissionRate ?? this.commissionRate,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (unitType.present) {
      map['unit_type'] = Variable<String>(unitType.value);
    }
    if (salePrice.present) {
      map['sale_price'] = Variable<int>(salePrice.value);
    }
    if (purchasePrice.present) {
      map['purchase_price'] = Variable<int>(purchasePrice.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (reorderLevel.present) {
      map['reorder_level'] = Variable<double>(reorderLevel.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (commissionRate.present) {
      map['commission_rate'] = Variable<double>(commissionRate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProductsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('barcode: $barcode, ')
          ..write('unit: $unit, ')
          ..write('unitType: $unitType, ')
          ..write('salePrice: $salePrice, ')
          ..write('purchasePrice: $purchasePrice, ')
          ..write('qty: $qty, ')
          ..write('reorderLevel: $reorderLevel, ')
          ..write('supplierId: $supplierId, ')
          ..write('commissionRate: $commissionRate, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEmployeesTable extends LocalEmployees
    with TableInfo<$LocalEmployeesTable, LocalEmployeeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEmployeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _jobTitleMeta = const VerificationMeta(
    'jobTitle',
  );
  @override
  late final GeneratedColumn<String> jobTitle = GeneratedColumn<String>(
    'job_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseSalaryMeta = const VerificationMeta(
    'baseSalary',
  );
  @override
  late final GeneratedColumn<int> baseSalary = GeneratedColumn<int>(
    'base_salary',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    name,
    jobTitle,
    phone,
    baseSalary,
    createdAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_employees';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEmployeeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('job_title')) {
      context.handle(
        _jobTitleMeta,
        jobTitle.isAcceptableOrUnknown(data['job_title']!, _jobTitleMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('base_salary')) {
      context.handle(
        _baseSalaryMeta,
        baseSalary.isAcceptableOrUnknown(data['base_salary']!, _baseSalaryMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalEmployeeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEmployeeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      jobTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_title'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      baseSalary: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_salary'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $LocalEmployeesTable createAlias(String alias) {
    return $LocalEmployeesTable(attachedDatabase, alias);
  }
}

class LocalEmployeeRow extends DataClass
    implements Insertable<LocalEmployeeRow> {
  final String id;
  final String tenantId;
  final String name;
  final String? jobTitle;
  final String? phone;
  final int baseSalary;
  final DateTime? createdAt;
  final bool synced;
  const LocalEmployeeRow({
    required this.id,
    required this.tenantId,
    required this.name,
    this.jobTitle,
    this.phone,
    required this.baseSalary,
    this.createdAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || jobTitle != null) {
      map['job_title'] = Variable<String>(jobTitle);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['base_salary'] = Variable<int>(baseSalary);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  LocalEmployeesCompanion toCompanion(bool nullToAbsent) {
    return LocalEmployeesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      name: Value(name),
      jobTitle: jobTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(jobTitle),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      baseSalary: Value(baseSalary),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      synced: Value(synced),
    );
  }

  factory LocalEmployeeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEmployeeRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      name: serializer.fromJson<String>(json['name']),
      jobTitle: serializer.fromJson<String?>(json['jobTitle']),
      phone: serializer.fromJson<String?>(json['phone']),
      baseSalary: serializer.fromJson<int>(json['baseSalary']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'name': serializer.toJson<String>(name),
      'jobTitle': serializer.toJson<String?>(jobTitle),
      'phone': serializer.toJson<String?>(phone),
      'baseSalary': serializer.toJson<int>(baseSalary),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  LocalEmployeeRow copyWith({
    String? id,
    String? tenantId,
    String? name,
    Value<String?> jobTitle = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    int? baseSalary,
    Value<DateTime?> createdAt = const Value.absent(),
    bool? synced,
  }) => LocalEmployeeRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    name: name ?? this.name,
    jobTitle: jobTitle.present ? jobTitle.value : this.jobTitle,
    phone: phone.present ? phone.value : this.phone,
    baseSalary: baseSalary ?? this.baseSalary,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    synced: synced ?? this.synced,
  );
  LocalEmployeeRow copyWithCompanion(LocalEmployeesCompanion data) {
    return LocalEmployeeRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      name: data.name.present ? data.name.value : this.name,
      jobTitle: data.jobTitle.present ? data.jobTitle.value : this.jobTitle,
      phone: data.phone.present ? data.phone.value : this.phone,
      baseSalary: data.baseSalary.present
          ? data.baseSalary.value
          : this.baseSalary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEmployeeRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('jobTitle: $jobTitle, ')
          ..write('phone: $phone, ')
          ..write('baseSalary: $baseSalary, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    name,
    jobTitle,
    phone,
    baseSalary,
    createdAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEmployeeRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.name == this.name &&
          other.jobTitle == this.jobTitle &&
          other.phone == this.phone &&
          other.baseSalary == this.baseSalary &&
          other.createdAt == this.createdAt &&
          other.synced == this.synced);
}

class LocalEmployeesCompanion extends UpdateCompanion<LocalEmployeeRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> name;
  final Value<String?> jobTitle;
  final Value<String?> phone;
  final Value<int> baseSalary;
  final Value<DateTime?> createdAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const LocalEmployeesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.name = const Value.absent(),
    this.jobTitle = const Value.absent(),
    this.phone = const Value.absent(),
    this.baseSalary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEmployeesCompanion.insert({
    required String id,
    required String tenantId,
    required String name,
    this.jobTitle = const Value.absent(),
    this.phone = const Value.absent(),
    this.baseSalary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       name = Value(name);
  static Insertable<LocalEmployeeRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? name,
    Expression<String>? jobTitle,
    Expression<String>? phone,
    Expression<int>? baseSalary,
    Expression<DateTime>? createdAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (name != null) 'name': name,
      if (jobTitle != null) 'job_title': jobTitle,
      if (phone != null) 'phone': phone,
      if (baseSalary != null) 'base_salary': baseSalary,
      if (createdAt != null) 'created_at': createdAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEmployeesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? name,
    Value<String?>? jobTitle,
    Value<String?>? phone,
    Value<int>? baseSalary,
    Value<DateTime?>? createdAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return LocalEmployeesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      jobTitle: jobTitle ?? this.jobTitle,
      phone: phone ?? this.phone,
      baseSalary: baseSalary ?? this.baseSalary,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (jobTitle.present) {
      map['job_title'] = Variable<String>(jobTitle.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (baseSalary.present) {
      map['base_salary'] = Variable<int>(baseSalary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEmployeesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('name: $name, ')
          ..write('jobTitle: $jobTitle, ')
          ..write('phone: $phone, ')
          ..write('baseSalary: $baseSalary, ')
          ..write('createdAt: $createdAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAccountsTable extends LocalAccounts
    with TableInfo<$LocalAccountsTable, LocalAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentCodeMeta = const VerificationMeta(
    'parentCode',
  );
  @override
  late final GeneratedColumn<String> parentCode = GeneratedColumn<String>(
    'parent_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    code,
    name,
    type,
    parentCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('parent_code')) {
      context.handle(
        _parentCodeMeta,
        parentCode.isAcceptableOrUnknown(data['parent_code']!, _parentCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      parentCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_code'],
      ),
    );
  }

  @override
  $LocalAccountsTable createAlias(String alias) {
    return $LocalAccountsTable(attachedDatabase, alias);
  }
}

class LocalAccountRow extends DataClass implements Insertable<LocalAccountRow> {
  final String id;
  final String tenantId;
  final String code;
  final String name;
  final String type;
  final String? parentCode;
  const LocalAccountRow({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.name,
    required this.type,
    this.parentCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || parentCode != null) {
      map['parent_code'] = Variable<String>(parentCode);
    }
    return map;
  }

  LocalAccountsCompanion toCompanion(bool nullToAbsent) {
    return LocalAccountsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      code: Value(code),
      name: Value(name),
      type: Value(type),
      parentCode: parentCode == null && nullToAbsent
          ? const Value.absent()
          : Value(parentCode),
    );
  }

  factory LocalAccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAccountRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      parentCode: serializer.fromJson<String?>(json['parentCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'parentCode': serializer.toJson<String?>(parentCode),
    };
  }

  LocalAccountRow copyWith({
    String? id,
    String? tenantId,
    String? code,
    String? name,
    String? type,
    Value<String?> parentCode = const Value.absent(),
  }) => LocalAccountRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    code: code ?? this.code,
    name: name ?? this.name,
    type: type ?? this.type,
    parentCode: parentCode.present ? parentCode.value : this.parentCode,
  );
  LocalAccountRow copyWithCompanion(LocalAccountsCompanion data) {
    return LocalAccountRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      parentCode: data.parentCode.present
          ? data.parentCode.value
          : this.parentCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccountRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('parentCode: $parentCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tenantId, code, name, type, parentCode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAccountRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.code == this.code &&
          other.name == this.name &&
          other.type == this.type &&
          other.parentCode == this.parentCode);
}

class LocalAccountsCompanion extends UpdateCompanion<LocalAccountRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> code;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> parentCode;
  final Value<int> rowid;
  const LocalAccountsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.parentCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAccountsCompanion.insert({
    required String id,
    required String tenantId,
    required String code,
    required String name,
    required String type,
    this.parentCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       code = Value(code),
       name = Value(name),
       type = Value(type);
  static Insertable<LocalAccountRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? parentCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (parentCode != null) 'parent_code': parentCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? code,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? parentCode,
    Value<int>? rowid,
  }) {
    return LocalAccountsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      parentCode: parentCode ?? this.parentCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (parentCode.present) {
      map['parent_code'] = Variable<String>(parentCode.value);
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
          ..write('tenantId: $tenantId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('parentCode: $parentCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalInvoicesTable extends LocalInvoices
    with TableInfo<$LocalInvoicesTable, LocalInvoiceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalInvoicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noMeta = const VerificationMeta('no');
  @override
  late final GeneratedColumn<String> no = GeneratedColumn<String>(
    'no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partyIdMeta = const VerificationMeta(
    'partyId',
  );
  @override
  late final GeneratedColumn<String> partyId = GeneratedColumn<String>(
    'party_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partyNameMeta = const VerificationMeta(
    'partyName',
  );
  @override
  late final GeneratedColumn<String> partyName = GeneratedColumn<String>(
    'party_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<int> subtotal = GeneratedColumn<int>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  @override
  late final GeneratedColumn<int> paid = GeneratedColumn<int>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingMeta = const VerificationMeta(
    'remaining',
  );
  @override
  late final GeneratedColumn<int> remaining = GeneratedColumn<int>(
    'remaining',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownershipMeta = const VerificationMeta(
    'ownership',
  );
  @override
  late final GeneratedColumn<String> ownership = GeneratedColumn<String>(
    'ownership',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    type,
    no,
    partyId,
    partyName,
    date,
    subtotal,
    total,
    paid,
    remaining,
    status,
    ownership,
    requestId,
    synced,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_invoices';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalInvoiceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('no')) {
      context.handle(_noMeta, no.isAcceptableOrUnknown(data['no']!, _noMeta));
    } else if (isInserting) {
      context.missing(_noMeta);
    }
    if (data.containsKey('party_id')) {
      context.handle(
        _partyIdMeta,
        partyId.isAcceptableOrUnknown(data['party_id']!, _partyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partyIdMeta);
    }
    if (data.containsKey('party_name')) {
      context.handle(
        _partyNameMeta,
        partyName.isAcceptableOrUnknown(data['party_name']!, _partyNameMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('paid')) {
      context.handle(
        _paidMeta,
        paid.isAcceptableOrUnknown(data['paid']!, _paidMeta),
      );
    } else if (isInserting) {
      context.missing(_paidMeta);
    }
    if (data.containsKey('remaining')) {
      context.handle(
        _remainingMeta,
        remaining.isAcceptableOrUnknown(data['remaining']!, _remainingMeta),
      );
    } else if (isInserting) {
      context.missing(_remainingMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('ownership')) {
      context.handle(
        _ownershipMeta,
        ownership.isAcceptableOrUnknown(data['ownership']!, _ownershipMeta),
      );
    } else if (isInserting) {
      context.missing(_ownershipMeta);
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalInvoiceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalInvoiceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      no: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}no'],
      )!,
      partyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_id'],
      )!,
      partyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_name'],
      ),
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      paid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid'],
      )!,
      remaining: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remaining'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      ownership: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ownership'],
      )!,
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $LocalInvoicesTable createAlias(String alias) {
    return $LocalInvoicesTable(attachedDatabase, alias);
  }
}

class LocalInvoiceRow extends DataClass implements Insertable<LocalInvoiceRow> {
  final String id;
  final String tenantId;
  final String type;
  final String no;
  final String partyId;
  final String? partyName;
  final DateTime date;
  final int subtotal;
  final int total;
  final int paid;
  final int remaining;
  final String status;
  final String ownership;
  final String? requestId;
  final bool synced;
  final DateTime? createdAt;
  const LocalInvoiceRow({
    required this.id,
    required this.tenantId,
    required this.type,
    required this.no,
    required this.partyId,
    this.partyName,
    required this.date,
    required this.subtotal,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.ownership,
    this.requestId,
    required this.synced,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['type'] = Variable<String>(type);
    map['no'] = Variable<String>(no);
    map['party_id'] = Variable<String>(partyId);
    if (!nullToAbsent || partyName != null) {
      map['party_name'] = Variable<String>(partyName);
    }
    map['date'] = Variable<DateTime>(date);
    map['subtotal'] = Variable<int>(subtotal);
    map['total'] = Variable<int>(total);
    map['paid'] = Variable<int>(paid);
    map['remaining'] = Variable<int>(remaining);
    map['status'] = Variable<String>(status);
    map['ownership'] = Variable<String>(ownership);
    if (!nullToAbsent || requestId != null) {
      map['request_id'] = Variable<String>(requestId);
    }
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  LocalInvoicesCompanion toCompanion(bool nullToAbsent) {
    return LocalInvoicesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      type: Value(type),
      no: Value(no),
      partyId: Value(partyId),
      partyName: partyName == null && nullToAbsent
          ? const Value.absent()
          : Value(partyName),
      date: Value(date),
      subtotal: Value(subtotal),
      total: Value(total),
      paid: Value(paid),
      remaining: Value(remaining),
      status: Value(status),
      ownership: Value(ownership),
      requestId: requestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requestId),
      synced: Value(synced),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LocalInvoiceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalInvoiceRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      type: serializer.fromJson<String>(json['type']),
      no: serializer.fromJson<String>(json['no']),
      partyId: serializer.fromJson<String>(json['partyId']),
      partyName: serializer.fromJson<String?>(json['partyName']),
      date: serializer.fromJson<DateTime>(json['date']),
      subtotal: serializer.fromJson<int>(json['subtotal']),
      total: serializer.fromJson<int>(json['total']),
      paid: serializer.fromJson<int>(json['paid']),
      remaining: serializer.fromJson<int>(json['remaining']),
      status: serializer.fromJson<String>(json['status']),
      ownership: serializer.fromJson<String>(json['ownership']),
      requestId: serializer.fromJson<String?>(json['requestId']),
      synced: serializer.fromJson<bool>(json['synced']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'type': serializer.toJson<String>(type),
      'no': serializer.toJson<String>(no),
      'partyId': serializer.toJson<String>(partyId),
      'partyName': serializer.toJson<String?>(partyName),
      'date': serializer.toJson<DateTime>(date),
      'subtotal': serializer.toJson<int>(subtotal),
      'total': serializer.toJson<int>(total),
      'paid': serializer.toJson<int>(paid),
      'remaining': serializer.toJson<int>(remaining),
      'status': serializer.toJson<String>(status),
      'ownership': serializer.toJson<String>(ownership),
      'requestId': serializer.toJson<String?>(requestId),
      'synced': serializer.toJson<bool>(synced),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  LocalInvoiceRow copyWith({
    String? id,
    String? tenantId,
    String? type,
    String? no,
    String? partyId,
    Value<String?> partyName = const Value.absent(),
    DateTime? date,
    int? subtotal,
    int? total,
    int? paid,
    int? remaining,
    String? status,
    String? ownership,
    Value<String?> requestId = const Value.absent(),
    bool? synced,
    Value<DateTime?> createdAt = const Value.absent(),
  }) => LocalInvoiceRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    type: type ?? this.type,
    no: no ?? this.no,
    partyId: partyId ?? this.partyId,
    partyName: partyName.present ? partyName.value : this.partyName,
    date: date ?? this.date,
    subtotal: subtotal ?? this.subtotal,
    total: total ?? this.total,
    paid: paid ?? this.paid,
    remaining: remaining ?? this.remaining,
    status: status ?? this.status,
    ownership: ownership ?? this.ownership,
    requestId: requestId.present ? requestId.value : this.requestId,
    synced: synced ?? this.synced,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  LocalInvoiceRow copyWithCompanion(LocalInvoicesCompanion data) {
    return LocalInvoiceRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      type: data.type.present ? data.type.value : this.type,
      no: data.no.present ? data.no.value : this.no,
      partyId: data.partyId.present ? data.partyId.value : this.partyId,
      partyName: data.partyName.present ? data.partyName.value : this.partyName,
      date: data.date.present ? data.date.value : this.date,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      total: data.total.present ? data.total.value : this.total,
      paid: data.paid.present ? data.paid.value : this.paid,
      remaining: data.remaining.present ? data.remaining.value : this.remaining,
      status: data.status.present ? data.status.value : this.status,
      ownership: data.ownership.present ? data.ownership.value : this.ownership,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      synced: data.synced.present ? data.synced.value : this.synced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalInvoiceRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('type: $type, ')
          ..write('no: $no, ')
          ..write('partyId: $partyId, ')
          ..write('partyName: $partyName, ')
          ..write('date: $date, ')
          ..write('subtotal: $subtotal, ')
          ..write('total: $total, ')
          ..write('paid: $paid, ')
          ..write('remaining: $remaining, ')
          ..write('status: $status, ')
          ..write('ownership: $ownership, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    type,
    no,
    partyId,
    partyName,
    date,
    subtotal,
    total,
    paid,
    remaining,
    status,
    ownership,
    requestId,
    synced,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalInvoiceRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.type == this.type &&
          other.no == this.no &&
          other.partyId == this.partyId &&
          other.partyName == this.partyName &&
          other.date == this.date &&
          other.subtotal == this.subtotal &&
          other.total == this.total &&
          other.paid == this.paid &&
          other.remaining == this.remaining &&
          other.status == this.status &&
          other.ownership == this.ownership &&
          other.requestId == this.requestId &&
          other.synced == this.synced &&
          other.createdAt == this.createdAt);
}

class LocalInvoicesCompanion extends UpdateCompanion<LocalInvoiceRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> type;
  final Value<String> no;
  final Value<String> partyId;
  final Value<String?> partyName;
  final Value<DateTime> date;
  final Value<int> subtotal;
  final Value<int> total;
  final Value<int> paid;
  final Value<int> remaining;
  final Value<String> status;
  final Value<String> ownership;
  final Value<String?> requestId;
  final Value<bool> synced;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const LocalInvoicesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.type = const Value.absent(),
    this.no = const Value.absent(),
    this.partyId = const Value.absent(),
    this.partyName = const Value.absent(),
    this.date = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.total = const Value.absent(),
    this.paid = const Value.absent(),
    this.remaining = const Value.absent(),
    this.status = const Value.absent(),
    this.ownership = const Value.absent(),
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalInvoicesCompanion.insert({
    required String id,
    required String tenantId,
    required String type,
    required String no,
    required String partyId,
    this.partyName = const Value.absent(),
    required DateTime date,
    required int subtotal,
    required int total,
    required int paid,
    required int remaining,
    required String status,
    required String ownership,
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       type = Value(type),
       no = Value(no),
       partyId = Value(partyId),
       date = Value(date),
       subtotal = Value(subtotal),
       total = Value(total),
       paid = Value(paid),
       remaining = Value(remaining),
       status = Value(status),
       ownership = Value(ownership);
  static Insertable<LocalInvoiceRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? type,
    Expression<String>? no,
    Expression<String>? partyId,
    Expression<String>? partyName,
    Expression<DateTime>? date,
    Expression<int>? subtotal,
    Expression<int>? total,
    Expression<int>? paid,
    Expression<int>? remaining,
    Expression<String>? status,
    Expression<String>? ownership,
    Expression<String>? requestId,
    Expression<bool>? synced,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (type != null) 'type': type,
      if (no != null) 'no': no,
      if (partyId != null) 'party_id': partyId,
      if (partyName != null) 'party_name': partyName,
      if (date != null) 'date': date,
      if (subtotal != null) 'subtotal': subtotal,
      if (total != null) 'total': total,
      if (paid != null) 'paid': paid,
      if (remaining != null) 'remaining': remaining,
      if (status != null) 'status': status,
      if (ownership != null) 'ownership': ownership,
      if (requestId != null) 'request_id': requestId,
      if (synced != null) 'synced': synced,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalInvoicesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? type,
    Value<String>? no,
    Value<String>? partyId,
    Value<String?>? partyName,
    Value<DateTime>? date,
    Value<int>? subtotal,
    Value<int>? total,
    Value<int>? paid,
    Value<int>? remaining,
    Value<String>? status,
    Value<String>? ownership,
    Value<String?>? requestId,
    Value<bool>? synced,
    Value<DateTime?>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalInvoicesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      type: type ?? this.type,
      no: no ?? this.no,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      date: date ?? this.date,
      subtotal: subtotal ?? this.subtotal,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      remaining: remaining ?? this.remaining,
      status: status ?? this.status,
      ownership: ownership ?? this.ownership,
      requestId: requestId ?? this.requestId,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (no.present) {
      map['no'] = Variable<String>(no.value);
    }
    if (partyId.present) {
      map['party_id'] = Variable<String>(partyId.value);
    }
    if (partyName.present) {
      map['party_name'] = Variable<String>(partyName.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<int>(subtotal.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (paid.present) {
      map['paid'] = Variable<int>(paid.value);
    }
    if (remaining.present) {
      map['remaining'] = Variable<int>(remaining.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (ownership.present) {
      map['ownership'] = Variable<String>(ownership.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalInvoicesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('type: $type, ')
          ..write('no: $no, ')
          ..write('partyId: $partyId, ')
          ..write('partyName: $partyName, ')
          ..write('date: $date, ')
          ..write('subtotal: $subtotal, ')
          ..write('total: $total, ')
          ..write('paid: $paid, ')
          ..write('remaining: $remaining, ')
          ..write('status: $status, ')
          ..write('ownership: $ownership, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalInvoiceItemsTable extends LocalInvoiceItems
    with TableInfo<$LocalInvoiceItemsTable, LocalInvoiceItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalInvoiceItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invoiceIdMeta = const VerificationMeta(
    'invoiceId',
  );
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
    'invoice_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productUnitMeta = const VerificationMeta(
    'productUnit',
  );
  @override
  late final GeneratedColumn<String> productUnit = GeneratedColumn<String>(
    'product_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productUnitTypeMeta = const VerificationMeta(
    'productUnitType',
  );
  @override
  late final GeneratedColumn<String> productUnitType = GeneratedColumn<String>(
    'product_unit_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _qtyMeta = const VerificationMeta('qty');
  @override
  late final GeneratedColumn<double> qty = GeneratedColumn<double>(
    'qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    invoiceId,
    productId,
    productName,
    productUnit,
    productUnitType,
    qty,
    price,
    total,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_invoice_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalInvoiceItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('invoice_id')) {
      context.handle(
        _invoiceIdMeta,
        invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    }
    if (data.containsKey('product_unit')) {
      context.handle(
        _productUnitMeta,
        productUnit.isAcceptableOrUnknown(
          data['product_unit']!,
          _productUnitMeta,
        ),
      );
    }
    if (data.containsKey('product_unit_type')) {
      context.handle(
        _productUnitTypeMeta,
        productUnitType.isAcceptableOrUnknown(
          data['product_unit_type']!,
          _productUnitTypeMeta,
        ),
      );
    }
    if (data.containsKey('qty')) {
      context.handle(
        _qtyMeta,
        qty.isAcceptableOrUnknown(data['qty']!, _qtyMeta),
      );
    } else if (isInserting) {
      context.missing(_qtyMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalInvoiceItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalInvoiceItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      invoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      ),
      productUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_unit'],
      ),
      productUnitType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_unit_type'],
      ),
      qty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}qty'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
    );
  }

  @override
  $LocalInvoiceItemsTable createAlias(String alias) {
    return $LocalInvoiceItemsTable(attachedDatabase, alias);
  }
}

class LocalInvoiceItemRow extends DataClass
    implements Insertable<LocalInvoiceItemRow> {
  final String id;
  final String tenantId;
  final String invoiceId;
  final String? productId;
  final String? productName;
  final String? productUnit;
  final String? productUnitType;
  final double qty;
  final int price;
  final int total;
  const LocalInvoiceItemRow({
    required this.id,
    required this.tenantId,
    required this.invoiceId,
    this.productId,
    this.productName,
    this.productUnit,
    this.productUnitType,
    required this.qty,
    required this.price,
    required this.total,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['invoice_id'] = Variable<String>(invoiceId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    if (!nullToAbsent || productName != null) {
      map['product_name'] = Variable<String>(productName);
    }
    if (!nullToAbsent || productUnit != null) {
      map['product_unit'] = Variable<String>(productUnit);
    }
    if (!nullToAbsent || productUnitType != null) {
      map['product_unit_type'] = Variable<String>(productUnitType);
    }
    map['qty'] = Variable<double>(qty);
    map['price'] = Variable<int>(price);
    map['total'] = Variable<int>(total);
    return map;
  }

  LocalInvoiceItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalInvoiceItemsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      invoiceId: Value(invoiceId),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      productName: productName == null && nullToAbsent
          ? const Value.absent()
          : Value(productName),
      productUnit: productUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(productUnit),
      productUnitType: productUnitType == null && nullToAbsent
          ? const Value.absent()
          : Value(productUnitType),
      qty: Value(qty),
      price: Value(price),
      total: Value(total),
    );
  }

  factory LocalInvoiceItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalInvoiceItemRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      invoiceId: serializer.fromJson<String>(json['invoiceId']),
      productId: serializer.fromJson<String?>(json['productId']),
      productName: serializer.fromJson<String?>(json['productName']),
      productUnit: serializer.fromJson<String?>(json['productUnit']),
      productUnitType: serializer.fromJson<String?>(json['productUnitType']),
      qty: serializer.fromJson<double>(json['qty']),
      price: serializer.fromJson<int>(json['price']),
      total: serializer.fromJson<int>(json['total']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'invoiceId': serializer.toJson<String>(invoiceId),
      'productId': serializer.toJson<String?>(productId),
      'productName': serializer.toJson<String?>(productName),
      'productUnit': serializer.toJson<String?>(productUnit),
      'productUnitType': serializer.toJson<String?>(productUnitType),
      'qty': serializer.toJson<double>(qty),
      'price': serializer.toJson<int>(price),
      'total': serializer.toJson<int>(total),
    };
  }

  LocalInvoiceItemRow copyWith({
    String? id,
    String? tenantId,
    String? invoiceId,
    Value<String?> productId = const Value.absent(),
    Value<String?> productName = const Value.absent(),
    Value<String?> productUnit = const Value.absent(),
    Value<String?> productUnitType = const Value.absent(),
    double? qty,
    int? price,
    int? total,
  }) => LocalInvoiceItemRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    invoiceId: invoiceId ?? this.invoiceId,
    productId: productId.present ? productId.value : this.productId,
    productName: productName.present ? productName.value : this.productName,
    productUnit: productUnit.present ? productUnit.value : this.productUnit,
    productUnitType: productUnitType.present
        ? productUnitType.value
        : this.productUnitType,
    qty: qty ?? this.qty,
    price: price ?? this.price,
    total: total ?? this.total,
  );
  LocalInvoiceItemRow copyWithCompanion(LocalInvoiceItemsCompanion data) {
    return LocalInvoiceItemRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      productUnit: data.productUnit.present
          ? data.productUnit.value
          : this.productUnit,
      productUnitType: data.productUnitType.present
          ? data.productUnitType.value
          : this.productUnitType,
      qty: data.qty.present ? data.qty.value : this.qty,
      price: data.price.present ? data.price.value : this.price,
      total: data.total.present ? data.total.value : this.total,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalInvoiceItemRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('productUnit: $productUnit, ')
          ..write('productUnitType: $productUnitType, ')
          ..write('qty: $qty, ')
          ..write('price: $price, ')
          ..write('total: $total')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    invoiceId,
    productId,
    productName,
    productUnit,
    productUnitType,
    qty,
    price,
    total,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalInvoiceItemRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.invoiceId == this.invoiceId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.productUnit == this.productUnit &&
          other.productUnitType == this.productUnitType &&
          other.qty == this.qty &&
          other.price == this.price &&
          other.total == this.total);
}

class LocalInvoiceItemsCompanion extends UpdateCompanion<LocalInvoiceItemRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> invoiceId;
  final Value<String?> productId;
  final Value<String?> productName;
  final Value<String?> productUnit;
  final Value<String?> productUnitType;
  final Value<double> qty;
  final Value<int> price;
  final Value<int> total;
  final Value<int> rowid;
  const LocalInvoiceItemsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.productUnit = const Value.absent(),
    this.productUnitType = const Value.absent(),
    this.qty = const Value.absent(),
    this.price = const Value.absent(),
    this.total = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalInvoiceItemsCompanion.insert({
    required String id,
    required String tenantId,
    required String invoiceId,
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.productUnit = const Value.absent(),
    this.productUnitType = const Value.absent(),
    required double qty,
    required int price,
    required int total,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       invoiceId = Value(invoiceId),
       qty = Value(qty),
       price = Value(price),
       total = Value(total);
  static Insertable<LocalInvoiceItemRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? invoiceId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<String>? productUnit,
    Expression<String>? productUnitType,
    Expression<double>? qty,
    Expression<int>? price,
    Expression<int>? total,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (productUnit != null) 'product_unit': productUnit,
      if (productUnitType != null) 'product_unit_type': productUnitType,
      if (qty != null) 'qty': qty,
      if (price != null) 'price': price,
      if (total != null) 'total': total,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalInvoiceItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? invoiceId,
    Value<String?>? productId,
    Value<String?>? productName,
    Value<String?>? productUnit,
    Value<String?>? productUnitType,
    Value<double>? qty,
    Value<int>? price,
    Value<int>? total,
    Value<int>? rowid,
  }) {
    return LocalInvoiceItemsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productUnit: productUnit ?? this.productUnit,
      productUnitType: productUnitType ?? this.productUnitType,
      qty: qty ?? this.qty,
      price: price ?? this.price,
      total: total ?? this.total,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (productUnit.present) {
      map['product_unit'] = Variable<String>(productUnit.value);
    }
    if (productUnitType.present) {
      map['product_unit_type'] = Variable<String>(productUnitType.value);
    }
    if (qty.present) {
      map['qty'] = Variable<double>(qty.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalInvoiceItemsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('productUnit: $productUnit, ')
          ..write('productUnitType: $productUnitType, ')
          ..write('qty: $qty, ')
          ..write('price: $price, ')
          ..write('total: $total, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPaymentsTable extends LocalPayments
    with TableInfo<$LocalPaymentsTable, LocalPaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invoiceIdMeta = const VerificationMeta(
    'invoiceId',
  );
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
    'invoice_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partyIdMeta = const VerificationMeta(
    'partyId',
  );
  @override
  late final GeneratedColumn<String> partyId = GeneratedColumn<String>(
    'party_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partyNameMeta = const VerificationMeta(
    'partyName',
  );
  @override
  late final GeneratedColumn<String> partyName = GeneratedColumn<String>(
    'party_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    invoiceId,
    partyId,
    partyName,
    amount,
    method,
    date,
    note,
    requestId,
    synced,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('invoice_id')) {
      context.handle(
        _invoiceIdMeta,
        invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta),
      );
    }
    if (data.containsKey('party_id')) {
      context.handle(
        _partyIdMeta,
        partyId.isAcceptableOrUnknown(data['party_id']!, _partyIdMeta),
      );
    }
    if (data.containsKey('party_name')) {
      context.handle(
        _partyNameMeta,
        partyName.isAcceptableOrUnknown(data['party_name']!, _partyNameMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPaymentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      invoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_id'],
      ),
      partyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_id'],
      ),
      partyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_name'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $LocalPaymentsTable createAlias(String alias) {
    return $LocalPaymentsTable(attachedDatabase, alias);
  }
}

class LocalPaymentRow extends DataClass implements Insertable<LocalPaymentRow> {
  final String id;
  final String tenantId;
  final String? invoiceId;
  final String? partyId;
  final String? partyName;
  final int amount;
  final String method;
  final DateTime date;
  final String? note;
  final String? requestId;
  final bool synced;
  final DateTime? createdAt;
  const LocalPaymentRow({
    required this.id,
    required this.tenantId,
    this.invoiceId,
    this.partyId,
    this.partyName,
    required this.amount,
    required this.method,
    required this.date,
    this.note,
    this.requestId,
    required this.synced,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    if (!nullToAbsent || invoiceId != null) {
      map['invoice_id'] = Variable<String>(invoiceId);
    }
    if (!nullToAbsent || partyId != null) {
      map['party_id'] = Variable<String>(partyId);
    }
    if (!nullToAbsent || partyName != null) {
      map['party_name'] = Variable<String>(partyName);
    }
    map['amount'] = Variable<int>(amount);
    map['method'] = Variable<String>(method);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || requestId != null) {
      map['request_id'] = Variable<String>(requestId);
    }
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  LocalPaymentsCompanion toCompanion(bool nullToAbsent) {
    return LocalPaymentsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      invoiceId: invoiceId == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceId),
      partyId: partyId == null && nullToAbsent
          ? const Value.absent()
          : Value(partyId),
      partyName: partyName == null && nullToAbsent
          ? const Value.absent()
          : Value(partyName),
      amount: Value(amount),
      method: Value(method),
      date: Value(date),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      requestId: requestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requestId),
      synced: Value(synced),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LocalPaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPaymentRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      invoiceId: serializer.fromJson<String?>(json['invoiceId']),
      partyId: serializer.fromJson<String?>(json['partyId']),
      partyName: serializer.fromJson<String?>(json['partyName']),
      amount: serializer.fromJson<int>(json['amount']),
      method: serializer.fromJson<String>(json['method']),
      date: serializer.fromJson<DateTime>(json['date']),
      note: serializer.fromJson<String?>(json['note']),
      requestId: serializer.fromJson<String?>(json['requestId']),
      synced: serializer.fromJson<bool>(json['synced']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'invoiceId': serializer.toJson<String?>(invoiceId),
      'partyId': serializer.toJson<String?>(partyId),
      'partyName': serializer.toJson<String?>(partyName),
      'amount': serializer.toJson<int>(amount),
      'method': serializer.toJson<String>(method),
      'date': serializer.toJson<DateTime>(date),
      'note': serializer.toJson<String?>(note),
      'requestId': serializer.toJson<String?>(requestId),
      'synced': serializer.toJson<bool>(synced),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  LocalPaymentRow copyWith({
    String? id,
    String? tenantId,
    Value<String?> invoiceId = const Value.absent(),
    Value<String?> partyId = const Value.absent(),
    Value<String?> partyName = const Value.absent(),
    int? amount,
    String? method,
    DateTime? date,
    Value<String?> note = const Value.absent(),
    Value<String?> requestId = const Value.absent(),
    bool? synced,
    Value<DateTime?> createdAt = const Value.absent(),
  }) => LocalPaymentRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    invoiceId: invoiceId.present ? invoiceId.value : this.invoiceId,
    partyId: partyId.present ? partyId.value : this.partyId,
    partyName: partyName.present ? partyName.value : this.partyName,
    amount: amount ?? this.amount,
    method: method ?? this.method,
    date: date ?? this.date,
    note: note.present ? note.value : this.note,
    requestId: requestId.present ? requestId.value : this.requestId,
    synced: synced ?? this.synced,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  LocalPaymentRow copyWithCompanion(LocalPaymentsCompanion data) {
    return LocalPaymentRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      partyId: data.partyId.present ? data.partyId.value : this.partyId,
      partyName: data.partyName.present ? data.partyName.value : this.partyName,
      amount: data.amount.present ? data.amount.value : this.amount,
      method: data.method.present ? data.method.value : this.method,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      synced: data.synced.present ? data.synced.value : this.synced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPaymentRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('partyId: $partyId, ')
          ..write('partyName: $partyName, ')
          ..write('amount: $amount, ')
          ..write('method: $method, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    invoiceId,
    partyId,
    partyName,
    amount,
    method,
    date,
    note,
    requestId,
    synced,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPaymentRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.invoiceId == this.invoiceId &&
          other.partyId == this.partyId &&
          other.partyName == this.partyName &&
          other.amount == this.amount &&
          other.method == this.method &&
          other.date == this.date &&
          other.note == this.note &&
          other.requestId == this.requestId &&
          other.synced == this.synced &&
          other.createdAt == this.createdAt);
}

class LocalPaymentsCompanion extends UpdateCompanion<LocalPaymentRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String?> invoiceId;
  final Value<String?> partyId;
  final Value<String?> partyName;
  final Value<int> amount;
  final Value<String> method;
  final Value<DateTime> date;
  final Value<String?> note;
  final Value<String?> requestId;
  final Value<bool> synced;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const LocalPaymentsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.partyId = const Value.absent(),
    this.partyName = const Value.absent(),
    this.amount = const Value.absent(),
    this.method = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPaymentsCompanion.insert({
    required String id,
    required String tenantId,
    this.invoiceId = const Value.absent(),
    this.partyId = const Value.absent(),
    this.partyName = const Value.absent(),
    required int amount,
    required String method,
    required DateTime date,
    this.note = const Value.absent(),
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       amount = Value(amount),
       method = Value(method),
       date = Value(date);
  static Insertable<LocalPaymentRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? invoiceId,
    Expression<String>? partyId,
    Expression<String>? partyName,
    Expression<int>? amount,
    Expression<String>? method,
    Expression<DateTime>? date,
    Expression<String>? note,
    Expression<String>? requestId,
    Expression<bool>? synced,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (partyId != null) 'party_id': partyId,
      if (partyName != null) 'party_name': partyName,
      if (amount != null) 'amount': amount,
      if (method != null) 'method': method,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (requestId != null) 'request_id': requestId,
      if (synced != null) 'synced': synced,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String?>? invoiceId,
    Value<String?>? partyId,
    Value<String?>? partyName,
    Value<int>? amount,
    Value<String>? method,
    Value<DateTime>? date,
    Value<String?>? note,
    Value<String?>? requestId,
    Value<bool>? synced,
    Value<DateTime?>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalPaymentsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      invoiceId: invoiceId ?? this.invoiceId,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      amount: amount ?? this.amount,
      method: method ?? this.method,
      date: date ?? this.date,
      note: note ?? this.note,
      requestId: requestId ?? this.requestId,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (partyId.present) {
      map['party_id'] = Variable<String>(partyId.value);
    }
    if (partyName.present) {
      map['party_name'] = Variable<String>(partyName.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('partyId: $partyId, ')
          ..write('partyName: $partyName, ')
          ..write('amount: $amount, ')
          ..write('method: $method, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalCommissionDuesTable extends LocalCommissionDues
    with TableInfo<$LocalCommissionDuesTable, LocalCommissionDueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCommissionDuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invoiceIdMeta = const VerificationMeta(
    'invoiceId',
  );
  @override
  late final GeneratedColumn<String> invoiceId = GeneratedColumn<String>(
    'invoice_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAmountMeta = const VerificationMeta(
    'dueAmount',
  );
  @override
  late final GeneratedColumn<int> dueAmount = GeneratedColumn<int>(
    'due_amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    invoiceId,
    productId,
    supplierId,
    dueAmount,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_commission_dues';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCommissionDueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('invoice_id')) {
      context.handle(
        _invoiceIdMeta,
        invoiceId.isAcceptableOrUnknown(data['invoice_id']!, _invoiceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_invoiceIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    } else if (isInserting) {
      context.missing(_supplierIdMeta);
    }
    if (data.containsKey('due_amount')) {
      context.handle(
        _dueAmountMeta,
        dueAmount.isAcceptableOrUnknown(data['due_amount']!, _dueAmountMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAmountMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCommissionDueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCommissionDueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      invoiceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      )!,
      dueAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_amount'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $LocalCommissionDuesTable createAlias(String alias) {
    return $LocalCommissionDuesTable(attachedDatabase, alias);
  }
}

class LocalCommissionDueRow extends DataClass
    implements Insertable<LocalCommissionDueRow> {
  final String id;
  final String tenantId;
  final String invoiceId;
  final String productId;
  final String supplierId;
  final int dueAmount;
  final String status;
  final DateTime? createdAt;
  const LocalCommissionDueRow({
    required this.id,
    required this.tenantId,
    required this.invoiceId,
    required this.productId,
    required this.supplierId,
    required this.dueAmount,
    required this.status,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['invoice_id'] = Variable<String>(invoiceId);
    map['product_id'] = Variable<String>(productId);
    map['supplier_id'] = Variable<String>(supplierId);
    map['due_amount'] = Variable<int>(dueAmount);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  LocalCommissionDuesCompanion toCompanion(bool nullToAbsent) {
    return LocalCommissionDuesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      invoiceId: Value(invoiceId),
      productId: Value(productId),
      supplierId: Value(supplierId),
      dueAmount: Value(dueAmount),
      status: Value(status),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LocalCommissionDueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCommissionDueRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      invoiceId: serializer.fromJson<String>(json['invoiceId']),
      productId: serializer.fromJson<String>(json['productId']),
      supplierId: serializer.fromJson<String>(json['supplierId']),
      dueAmount: serializer.fromJson<int>(json['dueAmount']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'invoiceId': serializer.toJson<String>(invoiceId),
      'productId': serializer.toJson<String>(productId),
      'supplierId': serializer.toJson<String>(supplierId),
      'dueAmount': serializer.toJson<int>(dueAmount),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  LocalCommissionDueRow copyWith({
    String? id,
    String? tenantId,
    String? invoiceId,
    String? productId,
    String? supplierId,
    int? dueAmount,
    String? status,
    Value<DateTime?> createdAt = const Value.absent(),
  }) => LocalCommissionDueRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    invoiceId: invoiceId ?? this.invoiceId,
    productId: productId ?? this.productId,
    supplierId: supplierId ?? this.supplierId,
    dueAmount: dueAmount ?? this.dueAmount,
    status: status ?? this.status,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  LocalCommissionDueRow copyWithCompanion(LocalCommissionDuesCompanion data) {
    return LocalCommissionDueRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      invoiceId: data.invoiceId.present ? data.invoiceId.value : this.invoiceId,
      productId: data.productId.present ? data.productId.value : this.productId,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      dueAmount: data.dueAmount.present ? data.dueAmount.value : this.dueAmount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCommissionDueRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('productId: $productId, ')
          ..write('supplierId: $supplierId, ')
          ..write('dueAmount: $dueAmount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    invoiceId,
    productId,
    supplierId,
    dueAmount,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCommissionDueRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.invoiceId == this.invoiceId &&
          other.productId == this.productId &&
          other.supplierId == this.supplierId &&
          other.dueAmount == this.dueAmount &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class LocalCommissionDuesCompanion
    extends UpdateCompanion<LocalCommissionDueRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> invoiceId;
  final Value<String> productId;
  final Value<String> supplierId;
  final Value<int> dueAmount;
  final Value<String> status;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const LocalCommissionDuesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.invoiceId = const Value.absent(),
    this.productId = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.dueAmount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCommissionDuesCompanion.insert({
    required String id,
    required String tenantId,
    required String invoiceId,
    required String productId,
    required String supplierId,
    required int dueAmount,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       invoiceId = Value(invoiceId),
       productId = Value(productId),
       supplierId = Value(supplierId),
       dueAmount = Value(dueAmount);
  static Insertable<LocalCommissionDueRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? invoiceId,
    Expression<String>? productId,
    Expression<String>? supplierId,
    Expression<int>? dueAmount,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (productId != null) 'product_id': productId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (dueAmount != null) 'due_amount': dueAmount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCommissionDuesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? invoiceId,
    Value<String>? productId,
    Value<String>? supplierId,
    Value<int>? dueAmount,
    Value<String>? status,
    Value<DateTime?>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalCommissionDuesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      dueAmount: dueAmount ?? this.dueAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (invoiceId.present) {
      map['invoice_id'] = Variable<String>(invoiceId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (dueAmount.present) {
      map['due_amount'] = Variable<int>(dueAmount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCommissionDuesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('invoiceId: $invoiceId, ')
          ..write('productId: $productId, ')
          ..write('supplierId: $supplierId, ')
          ..write('dueAmount: $dueAmount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalJournalEntriesTable extends LocalJournalEntries
    with TableInfo<$LocalJournalEntriesTable, LocalJournalEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalJournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linesMeta = const VerificationMeta('lines');
  @override
  late final GeneratedColumn<String> lines = GeneratedColumn<String>(
    'lines',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    date,
    memo,
    lines,
    sourceType,
    sourceId,
    requestId,
    synced,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_journal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalJournalEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    } else if (isInserting) {
      context.missing(_memoMeta);
    }
    if (data.containsKey('lines')) {
      context.handle(
        _linesMeta,
        lines.isAcceptableOrUnknown(data['lines']!, _linesMeta),
      );
    } else if (isInserting) {
      context.missing(_linesMeta);
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceTypeMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalJournalEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalJournalEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      )!,
      lines: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lines'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $LocalJournalEntriesTable createAlias(String alias) {
    return $LocalJournalEntriesTable(attachedDatabase, alias);
  }
}

class LocalJournalEntryRow extends DataClass
    implements Insertable<LocalJournalEntryRow> {
  final String id;
  final String tenantId;
  final DateTime date;
  final String memo;
  final String lines;
  final String sourceType;
  final String? sourceId;
  final String? requestId;
  final bool synced;
  final DateTime? createdAt;
  const LocalJournalEntryRow({
    required this.id,
    required this.tenantId,
    required this.date,
    required this.memo,
    required this.lines,
    required this.sourceType,
    this.sourceId,
    this.requestId,
    required this.synced,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['date'] = Variable<DateTime>(date);
    map['memo'] = Variable<String>(memo);
    map['lines'] = Variable<String>(lines);
    map['source_type'] = Variable<String>(sourceType);
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || requestId != null) {
      map['request_id'] = Variable<String>(requestId);
    }
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  LocalJournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return LocalJournalEntriesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      date: Value(date),
      memo: Value(memo),
      lines: Value(lines),
      sourceType: Value(sourceType),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      requestId: requestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requestId),
      synced: Value(synced),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LocalJournalEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalJournalEntryRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      date: serializer.fromJson<DateTime>(json['date']),
      memo: serializer.fromJson<String>(json['memo']),
      lines: serializer.fromJson<String>(json['lines']),
      sourceType: serializer.fromJson<String>(json['sourceType']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      requestId: serializer.fromJson<String?>(json['requestId']),
      synced: serializer.fromJson<bool>(json['synced']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'date': serializer.toJson<DateTime>(date),
      'memo': serializer.toJson<String>(memo),
      'lines': serializer.toJson<String>(lines),
      'sourceType': serializer.toJson<String>(sourceType),
      'sourceId': serializer.toJson<String?>(sourceId),
      'requestId': serializer.toJson<String?>(requestId),
      'synced': serializer.toJson<bool>(synced),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  LocalJournalEntryRow copyWith({
    String? id,
    String? tenantId,
    DateTime? date,
    String? memo,
    String? lines,
    String? sourceType,
    Value<String?> sourceId = const Value.absent(),
    Value<String?> requestId = const Value.absent(),
    bool? synced,
    Value<DateTime?> createdAt = const Value.absent(),
  }) => LocalJournalEntryRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    date: date ?? this.date,
    memo: memo ?? this.memo,
    lines: lines ?? this.lines,
    sourceType: sourceType ?? this.sourceType,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    requestId: requestId.present ? requestId.value : this.requestId,
    synced: synced ?? this.synced,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  LocalJournalEntryRow copyWithCompanion(LocalJournalEntriesCompanion data) {
    return LocalJournalEntryRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      date: data.date.present ? data.date.value : this.date,
      memo: data.memo.present ? data.memo.value : this.memo,
      lines: data.lines.present ? data.lines.value : this.lines,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      synced: data.synced.present ? data.synced.value : this.synced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalJournalEntryRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('date: $date, ')
          ..write('memo: $memo, ')
          ..write('lines: $lines, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    date,
    memo,
    lines,
    sourceType,
    sourceId,
    requestId,
    synced,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalJournalEntryRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.date == this.date &&
          other.memo == this.memo &&
          other.lines == this.lines &&
          other.sourceType == this.sourceType &&
          other.sourceId == this.sourceId &&
          other.requestId == this.requestId &&
          other.synced == this.synced &&
          other.createdAt == this.createdAt);
}

class LocalJournalEntriesCompanion
    extends UpdateCompanion<LocalJournalEntryRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<DateTime> date;
  final Value<String> memo;
  final Value<String> lines;
  final Value<String> sourceType;
  final Value<String?> sourceId;
  final Value<String?> requestId;
  final Value<bool> synced;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const LocalJournalEntriesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.date = const Value.absent(),
    this.memo = const Value.absent(),
    this.lines = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalJournalEntriesCompanion.insert({
    required String id,
    required String tenantId,
    required DateTime date,
    required String memo,
    required String lines,
    required String sourceType,
    this.sourceId = const Value.absent(),
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       date = Value(date),
       memo = Value(memo),
       lines = Value(lines),
       sourceType = Value(sourceType);
  static Insertable<LocalJournalEntryRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<DateTime>? date,
    Expression<String>? memo,
    Expression<String>? lines,
    Expression<String>? sourceType,
    Expression<String>? sourceId,
    Expression<String>? requestId,
    Expression<bool>? synced,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (date != null) 'date': date,
      if (memo != null) 'memo': memo,
      if (lines != null) 'lines': lines,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      if (requestId != null) 'request_id': requestId,
      if (synced != null) 'synced': synced,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalJournalEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<DateTime>? date,
    Value<String>? memo,
    Value<String>? lines,
    Value<String>? sourceType,
    Value<String?>? sourceId,
    Value<String?>? requestId,
    Value<bool>? synced,
    Value<DateTime?>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalJournalEntriesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      date: date ?? this.date,
      memo: memo ?? this.memo,
      lines: lines ?? this.lines,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      requestId: requestId ?? this.requestId,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (lines.present) {
      map['lines'] = Variable<String>(lines.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalJournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('date: $date, ')
          ..write('memo: $memo, ')
          ..write('lines: $lines, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEmployeeMovementsTable extends LocalEmployeeMovements
    with TableInfo<$LocalEmployeeMovementsTable, LocalEmployeeMovementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEmployeeMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<String> employeeId = GeneratedColumn<String>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    employeeId,
    month,
    direction,
    category,
    amount,
    date,
    note,
    requestId,
    synced,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_employee_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEmployeeMovementRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalEmployeeMovementRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEmployeeMovementRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      ),
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $LocalEmployeeMovementsTable createAlias(String alias) {
    return $LocalEmployeeMovementsTable(attachedDatabase, alias);
  }
}

class LocalEmployeeMovementRow extends DataClass
    implements Insertable<LocalEmployeeMovementRow> {
  final String id;
  final String tenantId;
  final String employeeId;
  final String? month;
  final String direction;
  final String category;
  final int amount;
  final DateTime date;
  final String? note;
  final String? requestId;
  final bool synced;
  final DateTime? createdAt;
  const LocalEmployeeMovementRow({
    required this.id,
    required this.tenantId,
    required this.employeeId,
    this.month,
    required this.direction,
    required this.category,
    required this.amount,
    required this.date,
    this.note,
    this.requestId,
    required this.synced,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['employee_id'] = Variable<String>(employeeId);
    if (!nullToAbsent || month != null) {
      map['month'] = Variable<String>(month);
    }
    map['direction'] = Variable<String>(direction);
    map['category'] = Variable<String>(category);
    map['amount'] = Variable<int>(amount);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || requestId != null) {
      map['request_id'] = Variable<String>(requestId);
    }
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  LocalEmployeeMovementsCompanion toCompanion(bool nullToAbsent) {
    return LocalEmployeeMovementsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      employeeId: Value(employeeId),
      month: month == null && nullToAbsent
          ? const Value.absent()
          : Value(month),
      direction: Value(direction),
      category: Value(category),
      amount: Value(amount),
      date: Value(date),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      requestId: requestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requestId),
      synced: Value(synced),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LocalEmployeeMovementRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEmployeeMovementRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      employeeId: serializer.fromJson<String>(json['employeeId']),
      month: serializer.fromJson<String?>(json['month']),
      direction: serializer.fromJson<String>(json['direction']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<int>(json['amount']),
      date: serializer.fromJson<DateTime>(json['date']),
      note: serializer.fromJson<String?>(json['note']),
      requestId: serializer.fromJson<String?>(json['requestId']),
      synced: serializer.fromJson<bool>(json['synced']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'employeeId': serializer.toJson<String>(employeeId),
      'month': serializer.toJson<String?>(month),
      'direction': serializer.toJson<String>(direction),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<int>(amount),
      'date': serializer.toJson<DateTime>(date),
      'note': serializer.toJson<String?>(note),
      'requestId': serializer.toJson<String?>(requestId),
      'synced': serializer.toJson<bool>(synced),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  LocalEmployeeMovementRow copyWith({
    String? id,
    String? tenantId,
    String? employeeId,
    Value<String?> month = const Value.absent(),
    String? direction,
    String? category,
    int? amount,
    DateTime? date,
    Value<String?> note = const Value.absent(),
    Value<String?> requestId = const Value.absent(),
    bool? synced,
    Value<DateTime?> createdAt = const Value.absent(),
  }) => LocalEmployeeMovementRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    employeeId: employeeId ?? this.employeeId,
    month: month.present ? month.value : this.month,
    direction: direction ?? this.direction,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    note: note.present ? note.value : this.note,
    requestId: requestId.present ? requestId.value : this.requestId,
    synced: synced ?? this.synced,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  LocalEmployeeMovementRow copyWithCompanion(
    LocalEmployeeMovementsCompanion data,
  ) {
    return LocalEmployeeMovementRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      month: data.month.present ? data.month.value : this.month,
      direction: data.direction.present ? data.direction.value : this.direction,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      date: data.date.present ? data.date.value : this.date,
      note: data.note.present ? data.note.value : this.note,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      synced: data.synced.present ? data.synced.value : this.synced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEmployeeMovementRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('employeeId: $employeeId, ')
          ..write('month: $month, ')
          ..write('direction: $direction, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    employeeId,
    month,
    direction,
    category,
    amount,
    date,
    note,
    requestId,
    synced,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEmployeeMovementRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.employeeId == this.employeeId &&
          other.month == this.month &&
          other.direction == this.direction &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.date == this.date &&
          other.note == this.note &&
          other.requestId == this.requestId &&
          other.synced == this.synced &&
          other.createdAt == this.createdAt);
}

class LocalEmployeeMovementsCompanion
    extends UpdateCompanion<LocalEmployeeMovementRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> employeeId;
  final Value<String?> month;
  final Value<String> direction;
  final Value<String> category;
  final Value<int> amount;
  final Value<DateTime> date;
  final Value<String?> note;
  final Value<String?> requestId;
  final Value<bool> synced;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const LocalEmployeeMovementsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.month = const Value.absent(),
    this.direction = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.date = const Value.absent(),
    this.note = const Value.absent(),
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEmployeeMovementsCompanion.insert({
    required String id,
    required String tenantId,
    required String employeeId,
    this.month = const Value.absent(),
    required String direction,
    required String category,
    required int amount,
    required DateTime date,
    this.note = const Value.absent(),
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       employeeId = Value(employeeId),
       direction = Value(direction),
       category = Value(category),
       amount = Value(amount),
       date = Value(date);
  static Insertable<LocalEmployeeMovementRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? employeeId,
    Expression<String>? month,
    Expression<String>? direction,
    Expression<String>? category,
    Expression<int>? amount,
    Expression<DateTime>? date,
    Expression<String>? note,
    Expression<String>? requestId,
    Expression<bool>? synced,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (employeeId != null) 'employee_id': employeeId,
      if (month != null) 'month': month,
      if (direction != null) 'direction': direction,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date,
      if (note != null) 'note': note,
      if (requestId != null) 'request_id': requestId,
      if (synced != null) 'synced': synced,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEmployeeMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? employeeId,
    Value<String?>? month,
    Value<String>? direction,
    Value<String>? category,
    Value<int>? amount,
    Value<DateTime>? date,
    Value<String?>? note,
    Value<String?>? requestId,
    Value<bool>? synced,
    Value<DateTime?>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalEmployeeMovementsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      employeeId: employeeId ?? this.employeeId,
      month: month ?? this.month,
      direction: direction ?? this.direction,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      requestId: requestId ?? this.requestId,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<String>(employeeId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEmployeeMovementsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('employeeId: $employeeId, ')
          ..write('month: $month, ')
          ..write('direction: $direction, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('note: $note, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSalariesTable extends LocalSalaries
    with TableInfo<$LocalSalariesTable, LocalSalaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSalariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<String> employeeId = GeneratedColumn<String>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  @override
  late final GeneratedColumn<int> paid = GeneratedColumn<int>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _netDueMeta = const VerificationMeta('netDue');
  @override
  late final GeneratedColumn<int> netDue = GeneratedColumn<int>(
    'net_due',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    employeeId,
    month,
    paid,
    netDue,
    requestId,
    synced,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_salaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSalaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('paid')) {
      context.handle(
        _paidMeta,
        paid.isAcceptableOrUnknown(data['paid']!, _paidMeta),
      );
    } else if (isInserting) {
      context.missing(_paidMeta);
    }
    if (data.containsKey('net_due')) {
      context.handle(
        _netDueMeta,
        netDue.isAcceptableOrUnknown(data['net_due']!, _netDueMeta),
      );
    } else if (isInserting) {
      context.missing(_netDueMeta);
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSalaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSalaryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      paid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid'],
      )!,
      netDue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}net_due'],
      )!,
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $LocalSalariesTable createAlias(String alias) {
    return $LocalSalariesTable(attachedDatabase, alias);
  }
}

class LocalSalaryRow extends DataClass implements Insertable<LocalSalaryRow> {
  final String id;
  final String tenantId;
  final String employeeId;
  final String month;
  final int paid;
  final int netDue;
  final String? requestId;
  final bool synced;
  final DateTime? createdAt;
  const LocalSalaryRow({
    required this.id,
    required this.tenantId,
    required this.employeeId,
    required this.month,
    required this.paid,
    required this.netDue,
    this.requestId,
    required this.synced,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['employee_id'] = Variable<String>(employeeId);
    map['month'] = Variable<String>(month);
    map['paid'] = Variable<int>(paid);
    map['net_due'] = Variable<int>(netDue);
    if (!nullToAbsent || requestId != null) {
      map['request_id'] = Variable<String>(requestId);
    }
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    return map;
  }

  LocalSalariesCompanion toCompanion(bool nullToAbsent) {
    return LocalSalariesCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      employeeId: Value(employeeId),
      month: Value(month),
      paid: Value(paid),
      netDue: Value(netDue),
      requestId: requestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requestId),
      synced: Value(synced),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LocalSalaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSalaryRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      employeeId: serializer.fromJson<String>(json['employeeId']),
      month: serializer.fromJson<String>(json['month']),
      paid: serializer.fromJson<int>(json['paid']),
      netDue: serializer.fromJson<int>(json['netDue']),
      requestId: serializer.fromJson<String?>(json['requestId']),
      synced: serializer.fromJson<bool>(json['synced']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'employeeId': serializer.toJson<String>(employeeId),
      'month': serializer.toJson<String>(month),
      'paid': serializer.toJson<int>(paid),
      'netDue': serializer.toJson<int>(netDue),
      'requestId': serializer.toJson<String?>(requestId),
      'synced': serializer.toJson<bool>(synced),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
    };
  }

  LocalSalaryRow copyWith({
    String? id,
    String? tenantId,
    String? employeeId,
    String? month,
    int? paid,
    int? netDue,
    Value<String?> requestId = const Value.absent(),
    bool? synced,
    Value<DateTime?> createdAt = const Value.absent(),
  }) => LocalSalaryRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    employeeId: employeeId ?? this.employeeId,
    month: month ?? this.month,
    paid: paid ?? this.paid,
    netDue: netDue ?? this.netDue,
    requestId: requestId.present ? requestId.value : this.requestId,
    synced: synced ?? this.synced,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  LocalSalaryRow copyWithCompanion(LocalSalariesCompanion data) {
    return LocalSalaryRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      month: data.month.present ? data.month.value : this.month,
      paid: data.paid.present ? data.paid.value : this.paid,
      netDue: data.netDue.present ? data.netDue.value : this.netDue,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      synced: data.synced.present ? data.synced.value : this.synced,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSalaryRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('employeeId: $employeeId, ')
          ..write('month: $month, ')
          ..write('paid: $paid, ')
          ..write('netDue: $netDue, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    employeeId,
    month,
    paid,
    netDue,
    requestId,
    synced,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSalaryRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.employeeId == this.employeeId &&
          other.month == this.month &&
          other.paid == this.paid &&
          other.netDue == this.netDue &&
          other.requestId == this.requestId &&
          other.synced == this.synced &&
          other.createdAt == this.createdAt);
}

class LocalSalariesCompanion extends UpdateCompanion<LocalSalaryRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> employeeId;
  final Value<String> month;
  final Value<int> paid;
  final Value<int> netDue;
  final Value<String?> requestId;
  final Value<bool> synced;
  final Value<DateTime?> createdAt;
  final Value<int> rowid;
  const LocalSalariesCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.month = const Value.absent(),
    this.paid = const Value.absent(),
    this.netDue = const Value.absent(),
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSalariesCompanion.insert({
    required String id,
    required String tenantId,
    required String employeeId,
    required String month,
    required int paid,
    required int netDue,
    this.requestId = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       employeeId = Value(employeeId),
       month = Value(month),
       paid = Value(paid),
       netDue = Value(netDue);
  static Insertable<LocalSalaryRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? employeeId,
    Expression<String>? month,
    Expression<int>? paid,
    Expression<int>? netDue,
    Expression<String>? requestId,
    Expression<bool>? synced,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (employeeId != null) 'employee_id': employeeId,
      if (month != null) 'month': month,
      if (paid != null) 'paid': paid,
      if (netDue != null) 'net_due': netDue,
      if (requestId != null) 'request_id': requestId,
      if (synced != null) 'synced': synced,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSalariesCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? employeeId,
    Value<String>? month,
    Value<int>? paid,
    Value<int>? netDue,
    Value<String?>? requestId,
    Value<bool>? synced,
    Value<DateTime?>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalSalariesCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      employeeId: employeeId ?? this.employeeId,
      month: month ?? this.month,
      paid: paid ?? this.paid,
      netDue: netDue ?? this.netDue,
      requestId: requestId ?? this.requestId,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<String>(employeeId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (paid.present) {
      map['paid'] = Variable<int>(paid.value);
    }
    if (netDue.present) {
      map['net_due'] = Variable<int>(netDue.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSalariesCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('employeeId: $employeeId, ')
          ..write('month: $month, ')
          ..write('paid: $paid, ')
          ..write('netDue: $netDue, ')
          ..write('requestId: $requestId, ')
          ..write('synced: $synced, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueItemsTable extends SyncQueueItems
    with TableInfo<$SyncQueueItemsTable, SyncQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rpcMeta = const VerificationMeta('rpc');
  @override
  late final GeneratedColumn<String> rpc = GeneratedColumn<String>(
    'rpc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('rpc'),
  );
  static const VerificationMeta _paramsMeta = const VerificationMeta('params');
  @override
  late final GeneratedColumn<String> params = GeneratedColumn<String>(
    'params',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tenantId,
    rpc,
    op,
    params,
    requestId,
    entity,
    localId,
    status,
    attempts,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('rpc')) {
      context.handle(
        _rpcMeta,
        rpc.isAcceptableOrUnknown(data['rpc']!, _rpcMeta),
      );
    } else if (isInserting) {
      context.missing(_rpcMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    }
    if (data.containsKey('params')) {
      context.handle(
        _paramsMeta,
        params.isAcceptableOrUnknown(data['params']!, _paramsMeta),
      );
    } else if (isInserting) {
      context.missing(_paramsMeta);
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    }
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      rpc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rpc'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      params: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}params'],
      )!,
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      ),
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      ),
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncQueueItemsTable createAlias(String alias) {
    return $SyncQueueItemsTable(attachedDatabase, alias);
  }
}

class SyncQueueRow extends DataClass implements Insertable<SyncQueueRow> {
  final String id;
  final String tenantId;
  final String rpc;
  final String op;
  final String params;
  final String? requestId;
  final String? entity;
  final String? localId;
  final String status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SyncQueueRow({
    required this.id,
    required this.tenantId,
    required this.rpc,
    required this.op,
    required this.params,
    this.requestId,
    this.entity,
    this.localId,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tenant_id'] = Variable<String>(tenantId);
    map['rpc'] = Variable<String>(rpc);
    map['op'] = Variable<String>(op);
    map['params'] = Variable<String>(params);
    if (!nullToAbsent || requestId != null) {
      map['request_id'] = Variable<String>(requestId);
    }
    if (!nullToAbsent || entity != null) {
      map['entity'] = Variable<String>(entity);
    }
    if (!nullToAbsent || localId != null) {
      map['local_id'] = Variable<String>(localId);
    }
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncQueueItemsCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueItemsCompanion(
      id: Value(id),
      tenantId: Value(tenantId),
      rpc: Value(rpc),
      op: Value(op),
      params: Value(params),
      requestId: requestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requestId),
      entity: entity == null && nullToAbsent
          ? const Value.absent()
          : Value(entity),
      localId: localId == null && nullToAbsent
          ? const Value.absent()
          : Value(localId),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueRow(
      id: serializer.fromJson<String>(json['id']),
      tenantId: serializer.fromJson<String>(json['tenantId']),
      rpc: serializer.fromJson<String>(json['rpc']),
      op: serializer.fromJson<String>(json['op']),
      params: serializer.fromJson<String>(json['params']),
      requestId: serializer.fromJson<String?>(json['requestId']),
      entity: serializer.fromJson<String?>(json['entity']),
      localId: serializer.fromJson<String?>(json['localId']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tenantId': serializer.toJson<String>(tenantId),
      'rpc': serializer.toJson<String>(rpc),
      'op': serializer.toJson<String>(op),
      'params': serializer.toJson<String>(params),
      'requestId': serializer.toJson<String?>(requestId),
      'entity': serializer.toJson<String?>(entity),
      'localId': serializer.toJson<String?>(localId),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncQueueRow copyWith({
    String? id,
    String? tenantId,
    String? rpc,
    String? op,
    String? params,
    Value<String?> requestId = const Value.absent(),
    Value<String?> entity = const Value.absent(),
    Value<String?> localId = const Value.absent(),
    String? status,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SyncQueueRow(
    id: id ?? this.id,
    tenantId: tenantId ?? this.tenantId,
    rpc: rpc ?? this.rpc,
    op: op ?? this.op,
    params: params ?? this.params,
    requestId: requestId.present ? requestId.value : this.requestId,
    entity: entity.present ? entity.value : this.entity,
    localId: localId.present ? localId.value : this.localId,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncQueueRow copyWithCompanion(SyncQueueItemsCompanion data) {
    return SyncQueueRow(
      id: data.id.present ? data.id.value : this.id,
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      rpc: data.rpc.present ? data.rpc.value : this.rpc,
      op: data.op.present ? data.op.value : this.op,
      params: data.params.present ? data.params.value : this.params,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      entity: data.entity.present ? data.entity.value : this.entity,
      localId: data.localId.present ? data.localId.value : this.localId,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueRow(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('rpc: $rpc, ')
          ..write('op: $op, ')
          ..write('params: $params, ')
          ..write('requestId: $requestId, ')
          ..write('entity: $entity, ')
          ..write('localId: $localId, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tenantId,
    rpc,
    op,
    params,
    requestId,
    entity,
    localId,
    status,
    attempts,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueRow &&
          other.id == this.id &&
          other.tenantId == this.tenantId &&
          other.rpc == this.rpc &&
          other.op == this.op &&
          other.params == this.params &&
          other.requestId == this.requestId &&
          other.entity == this.entity &&
          other.localId == this.localId &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncQueueItemsCompanion extends UpdateCompanion<SyncQueueRow> {
  final Value<String> id;
  final Value<String> tenantId;
  final Value<String> rpc;
  final Value<String> op;
  final Value<String> params;
  final Value<String?> requestId;
  final Value<String?> entity;
  final Value<String?> localId;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncQueueItemsCompanion({
    this.id = const Value.absent(),
    this.tenantId = const Value.absent(),
    this.rpc = const Value.absent(),
    this.op = const Value.absent(),
    this.params = const Value.absent(),
    this.requestId = const Value.absent(),
    this.entity = const Value.absent(),
    this.localId = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueItemsCompanion.insert({
    required String id,
    required String tenantId,
    required String rpc,
    this.op = const Value.absent(),
    required String params,
    this.requestId = const Value.absent(),
    this.entity = const Value.absent(),
    this.localId = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tenantId = Value(tenantId),
       rpc = Value(rpc),
       params = Value(params);
  static Insertable<SyncQueueRow> custom({
    Expression<String>? id,
    Expression<String>? tenantId,
    Expression<String>? rpc,
    Expression<String>? op,
    Expression<String>? params,
    Expression<String>? requestId,
    Expression<String>? entity,
    Expression<String>? localId,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tenantId != null) 'tenant_id': tenantId,
      if (rpc != null) 'rpc': rpc,
      if (op != null) 'op': op,
      if (params != null) 'params': params,
      if (requestId != null) 'request_id': requestId,
      if (entity != null) 'entity': entity,
      if (localId != null) 'local_id': localId,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? tenantId,
    Value<String>? rpc,
    Value<String>? op,
    Value<String>? params,
    Value<String?>? requestId,
    Value<String?>? entity,
    Value<String?>? localId,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncQueueItemsCompanion(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      rpc: rpc ?? this.rpc,
      op: op ?? this.op,
      params: params ?? this.params,
      requestId: requestId ?? this.requestId,
      entity: entity ?? this.entity,
      localId: localId ?? this.localId,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (rpc.present) {
      map['rpc'] = Variable<String>(rpc.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (params.present) {
      map['params'] = Variable<String>(params.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
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
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueItemsCompanion(')
          ..write('id: $id, ')
          ..write('tenantId: $tenantId, ')
          ..write('rpc: $rpc, ')
          ..write('op: $op, ')
          ..write('params: $params, ')
          ..write('requestId: $requestId, ')
          ..write('entity: $entity, ')
          ..write('localId: $localId, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdMappingsTable extends IdMappings
    with TableInfo<$IdMappingsTable, IdMappingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, localId, serverId, syncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'id_mappings';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdMappingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, localId};
  @override
  IdMappingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdMappingRow(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      )!,
    );
  }

  @override
  $IdMappingsTable createAlias(String alias) {
    return $IdMappingsTable(attachedDatabase, alias);
  }
}

class IdMappingRow extends DataClass implements Insertable<IdMappingRow> {
  final String entity;
  final String localId;
  final String serverId;
  final DateTime syncedAt;
  const IdMappingRow({
    required this.entity,
    required this.localId,
    required this.serverId,
    required this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['local_id'] = Variable<String>(localId);
    map['server_id'] = Variable<String>(serverId);
    map['synced_at'] = Variable<DateTime>(syncedAt);
    return map;
  }

  IdMappingsCompanion toCompanion(bool nullToAbsent) {
    return IdMappingsCompanion(
      entity: Value(entity),
      localId: Value(localId),
      serverId: Value(serverId),
      syncedAt: Value(syncedAt),
    );
  }

  factory IdMappingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdMappingRow(
      entity: serializer.fromJson<String>(json['entity']),
      localId: serializer.fromJson<String>(json['localId']),
      serverId: serializer.fromJson<String>(json['serverId']),
      syncedAt: serializer.fromJson<DateTime>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'localId': serializer.toJson<String>(localId),
      'serverId': serializer.toJson<String>(serverId),
      'syncedAt': serializer.toJson<DateTime>(syncedAt),
    };
  }

  IdMappingRow copyWith({
    String? entity,
    String? localId,
    String? serverId,
    DateTime? syncedAt,
  }) => IdMappingRow(
    entity: entity ?? this.entity,
    localId: localId ?? this.localId,
    serverId: serverId ?? this.serverId,
    syncedAt: syncedAt ?? this.syncedAt,
  );
  IdMappingRow copyWithCompanion(IdMappingsCompanion data) {
    return IdMappingRow(
      entity: data.entity.present ? data.entity.value : this.entity,
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdMappingRow(')
          ..write('entity: $entity, ')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, localId, serverId, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdMappingRow &&
          other.entity == this.entity &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.syncedAt == this.syncedAt);
}

class IdMappingsCompanion extends UpdateCompanion<IdMappingRow> {
  final Value<String> entity;
  final Value<String> localId;
  final Value<String> serverId;
  final Value<DateTime> syncedAt;
  final Value<int> rowid;
  const IdMappingsCompanion({
    this.entity = const Value.absent(),
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdMappingsCompanion.insert({
    required String entity,
    required String localId,
    required String serverId,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       localId = Value(localId),
       serverId = Value(serverId);
  static Insertable<IdMappingRow> custom({
    Expression<String>? entity,
    Expression<String>? localId,
    Expression<String>? serverId,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdMappingsCompanion copyWith({
    Value<String>? entity,
    Value<String>? localId,
    Value<String>? serverId,
    Value<DateTime>? syncedAt,
    Value<int>? rowid,
  }) {
    return IdMappingsCompanion(
      entity: entity ?? this.entity,
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdMappingsCompanion(')
          ..write('entity: $entity, ')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTenantSettingsTable extends LocalTenantSettings
    with TableInfo<$LocalTenantSettingsTable, LocalTenantSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTenantSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [tenantId, key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_tenant_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTenantSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tenantId, key};
  @override
  LocalTenantSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTenantSettingRow(
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalTenantSettingsTable createAlias(String alias) {
    return $LocalTenantSettingsTable(attachedDatabase, alias);
  }
}

class LocalTenantSettingRow extends DataClass
    implements Insertable<LocalTenantSettingRow> {
  final String tenantId;
  final String key;
  final String? value;
  final DateTime updatedAt;
  const LocalTenantSettingRow({
    required this.tenantId,
    required this.key,
    this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tenant_id'] = Variable<String>(tenantId);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalTenantSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalTenantSettingsCompanion(
      tenantId: Value(tenantId),
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalTenantSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTenantSettingRow(
      tenantId: serializer.fromJson<String>(json['tenantId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tenantId': serializer.toJson<String>(tenantId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalTenantSettingRow copyWith({
    String? tenantId,
    String? key,
    Value<String?> value = const Value.absent(),
    DateTime? updatedAt,
  }) => LocalTenantSettingRow(
    tenantId: tenantId ?? this.tenantId,
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalTenantSettingRow copyWithCompanion(LocalTenantSettingsCompanion data) {
    return LocalTenantSettingRow(
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTenantSettingRow(')
          ..write('tenantId: $tenantId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tenantId, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTenantSettingRow &&
          other.tenantId == this.tenantId &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class LocalTenantSettingsCompanion
    extends UpdateCompanion<LocalTenantSettingRow> {
  final Value<String> tenantId;
  final Value<String> key;
  final Value<String?> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalTenantSettingsCompanion({
    this.tenantId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTenantSettingsCompanion.insert({
    required String tenantId,
    required String key,
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tenantId = Value(tenantId),
       key = Value(key);
  static Insertable<LocalTenantSettingRow> custom({
    Expression<String>? tenantId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tenantId != null) 'tenant_id': tenantId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTenantSettingsCompanion copyWith({
    Value<String>? tenantId,
    Value<String>? key,
    Value<String?>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalTenantSettingsCompanion(
      tenantId: tenantId ?? this.tenantId,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTenantSettingsCompanion(')
          ..write('tenantId: $tenantId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReportCacheEntriesTable extends ReportCacheEntries
    with TableInfo<$ReportCacheEntriesTable, ReportCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReportCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tenantIdMeta = const VerificationMeta(
    'tenantId',
  );
  @override
  late final GeneratedColumn<String> tenantId = GeneratedColumn<String>(
    'tenant_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [tenantId, key, payload, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'report_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReportCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tenant_id')) {
      context.handle(
        _tenantIdMeta,
        tenantId.isAcceptableOrUnknown(data['tenant_id']!, _tenantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenantIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tenantId, key};
  @override
  ReportCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReportCacheRow(
      tenantId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tenant_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $ReportCacheEntriesTable createAlias(String alias) {
    return $ReportCacheEntriesTable(attachedDatabase, alias);
  }
}

class ReportCacheRow extends DataClass implements Insertable<ReportCacheRow> {
  final String tenantId;
  final String key;
  final String payload;
  final DateTime fetchedAt;
  const ReportCacheRow({
    required this.tenantId,
    required this.key,
    required this.payload,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tenant_id'] = Variable<String>(tenantId);
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  ReportCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return ReportCacheEntriesCompanion(
      tenantId: Value(tenantId),
      key: Value(key),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory ReportCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReportCacheRow(
      tenantId: serializer.fromJson<String>(json['tenantId']),
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tenantId': serializer.toJson<String>(tenantId),
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  ReportCacheRow copyWith({
    String? tenantId,
    String? key,
    String? payload,
    DateTime? fetchedAt,
  }) => ReportCacheRow(
    tenantId: tenantId ?? this.tenantId,
    key: key ?? this.key,
    payload: payload ?? this.payload,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  ReportCacheRow copyWithCompanion(ReportCacheEntriesCompanion data) {
    return ReportCacheRow(
      tenantId: data.tenantId.present ? data.tenantId.value : this.tenantId,
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReportCacheRow(')
          ..write('tenantId: $tenantId, ')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tenantId, key, payload, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReportCacheRow &&
          other.tenantId == this.tenantId &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt);
}

class ReportCacheEntriesCompanion extends UpdateCompanion<ReportCacheRow> {
  final Value<String> tenantId;
  final Value<String> key;
  final Value<String> payload;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const ReportCacheEntriesCompanion({
    this.tenantId = const Value.absent(),
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReportCacheEntriesCompanion.insert({
    required String tenantId,
    required String key,
    required String payload,
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tenantId = Value(tenantId),
       key = Value(key),
       payload = Value(payload);
  static Insertable<ReportCacheRow> custom({
    Expression<String>? tenantId,
    Expression<String>? key,
    Expression<String>? payload,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tenantId != null) 'tenant_id': tenantId,
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReportCacheEntriesCompanion copyWith({
    Value<String>? tenantId,
    Value<String>? key,
    Value<String>? payload,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return ReportCacheEntriesCompanion(
      tenantId: tenantId ?? this.tenantId,
      key: key ?? this.key,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tenantId.present) {
      map['tenant_id'] = Variable<String>(tenantId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReportCacheEntriesCompanion(')
          ..write('tenantId: $tenantId, ')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalCustomersTable localCustomers = $LocalCustomersTable(this);
  late final $LocalSuppliersTable localSuppliers = $LocalSuppliersTable(this);
  late final $LocalProductsTable localProducts = $LocalProductsTable(this);
  late final $LocalEmployeesTable localEmployees = $LocalEmployeesTable(this);
  late final $LocalAccountsTable localAccounts = $LocalAccountsTable(this);
  late final $LocalInvoicesTable localInvoices = $LocalInvoicesTable(this);
  late final $LocalInvoiceItemsTable localInvoiceItems =
      $LocalInvoiceItemsTable(this);
  late final $LocalPaymentsTable localPayments = $LocalPaymentsTable(this);
  late final $LocalCommissionDuesTable localCommissionDues =
      $LocalCommissionDuesTable(this);
  late final $LocalJournalEntriesTable localJournalEntries =
      $LocalJournalEntriesTable(this);
  late final $LocalEmployeeMovementsTable localEmployeeMovements =
      $LocalEmployeeMovementsTable(this);
  late final $LocalSalariesTable localSalaries = $LocalSalariesTable(this);
  late final $SyncQueueItemsTable syncQueueItems = $SyncQueueItemsTable(this);
  late final $IdMappingsTable idMappings = $IdMappingsTable(this);
  late final $LocalTenantSettingsTable localTenantSettings =
      $LocalTenantSettingsTable(this);
  late final $ReportCacheEntriesTable reportCacheEntries =
      $ReportCacheEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localCustomers,
    localSuppliers,
    localProducts,
    localEmployees,
    localAccounts,
    localInvoices,
    localInvoiceItems,
    localPayments,
    localCommissionDues,
    localJournalEntries,
    localEmployeeMovements,
    localSalaries,
    syncQueueItems,
    idMappings,
    localTenantSettings,
    reportCacheEntries,
  ];
}

typedef $$LocalCustomersTableCreateCompanionBuilder =
    LocalCustomersCompanion Function({
      required String id,
      required String tenantId,
      required String name,
      Value<String?> phone,
      Value<String?> notes,
      Value<DateTime?> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$LocalCustomersTableUpdateCompanionBuilder =
    LocalCustomersCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> name,
      Value<String?> phone,
      Value<String?> notes,
      Value<DateTime?> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$LocalCustomersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCustomersTable> {
  $$LocalCustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$LocalCustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCustomersTable,
          LocalCustomerRow,
          $$LocalCustomersTableFilterComposer,
          $$LocalCustomersTableOrderingComposer,
          $$LocalCustomersTableAnnotationComposer,
          $$LocalCustomersTableCreateCompanionBuilder,
          $$LocalCustomersTableUpdateCompanionBuilder,
          (
            LocalCustomerRow,
            BaseReferences<
              _$AppDatabase,
              $LocalCustomersTable,
              LocalCustomerRow
            >,
          ),
          LocalCustomerRow,
          PrefetchHooks Function()
        > {
  $$LocalCustomersTableTableManager(
    _$AppDatabase db,
    $LocalCustomersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCustomersCompanion(
                id: id,
                tenantId: tenantId,
                name: name,
                phone: phone,
                notes: notes,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCustomersCompanion.insert(
                id: id,
                tenantId: tenantId,
                name: name,
                phone: phone,
                notes: notes,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalCustomersTable, LocalCustomerRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalCustomersTable,
                    LocalCustomerRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCustomersTable,
      LocalCustomerRow,
      $$LocalCustomersTableFilterComposer,
      $$LocalCustomersTableOrderingComposer,
      $$LocalCustomersTableAnnotationComposer,
      $$LocalCustomersTableCreateCompanionBuilder,
      $$LocalCustomersTableUpdateCompanionBuilder,
      (
        LocalCustomerRow,
        BaseReferences<_$AppDatabase, $LocalCustomersTable, LocalCustomerRow>,
      ),
      LocalCustomerRow,
      PrefetchHooks Function()
    >;
typedef $$LocalSuppliersTableCreateCompanionBuilder =
    LocalSuppliersCompanion Function({
      required String id,
      required String tenantId,
      required String name,
      Value<String?> phone,
      Value<String?> notes,
      Value<String> dealType,
      Value<double?> commissionRate,
      Value<DateTime?> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$LocalSuppliersTableUpdateCompanionBuilder =
    LocalSuppliersCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> name,
      Value<String?> phone,
      Value<String?> notes,
      Value<String> dealType,
      Value<double?> commissionRate,
      Value<DateTime?> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$LocalSuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSuppliersTable> {
  $$LocalSuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dealType => $composableBuilder(
    column: $table.dealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get commissionRate => $composableBuilder(
    column: $table.commissionRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSuppliersTable> {
  $$LocalSuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dealType => $composableBuilder(
    column: $table.dealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get commissionRate => $composableBuilder(
    column: $table.commissionRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSuppliersTable> {
  $$LocalSuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get dealType =>
      $composableBuilder(column: $table.dealType, builder: (column) => column);

  GeneratedColumn<double> get commissionRate => $composableBuilder(
    column: $table.commissionRate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$LocalSuppliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSuppliersTable,
          LocalSupplierRow,
          $$LocalSuppliersTableFilterComposer,
          $$LocalSuppliersTableOrderingComposer,
          $$LocalSuppliersTableAnnotationComposer,
          $$LocalSuppliersTableCreateCompanionBuilder,
          $$LocalSuppliersTableUpdateCompanionBuilder,
          (
            LocalSupplierRow,
            BaseReferences<
              _$AppDatabase,
              $LocalSuppliersTable,
              LocalSupplierRow
            >,
          ),
          LocalSupplierRow,
          PrefetchHooks Function()
        > {
  $$LocalSuppliersTableTableManager(
    _$AppDatabase db,
    $LocalSuppliersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> dealType = const Value.absent(),
                Value<double?> commissionRate = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSuppliersCompanion(
                id: id,
                tenantId: tenantId,
                name: name,
                phone: phone,
                notes: notes,
                dealType: dealType,
                commissionRate: commissionRate,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> dealType = const Value.absent(),
                Value<double?> commissionRate = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSuppliersCompanion.insert(
                id: id,
                tenantId: tenantId,
                name: name,
                phone: phone,
                notes: notes,
                dealType: dealType,
                commissionRate: commissionRate,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSuppliersTable, LocalSupplierRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSuppliersTable,
                    LocalSupplierRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSuppliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSuppliersTable,
      LocalSupplierRow,
      $$LocalSuppliersTableFilterComposer,
      $$LocalSuppliersTableOrderingComposer,
      $$LocalSuppliersTableAnnotationComposer,
      $$LocalSuppliersTableCreateCompanionBuilder,
      $$LocalSuppliersTableUpdateCompanionBuilder,
      (
        LocalSupplierRow,
        BaseReferences<_$AppDatabase, $LocalSuppliersTable, LocalSupplierRow>,
      ),
      LocalSupplierRow,
      PrefetchHooks Function()
    >;
typedef $$LocalProductsTableCreateCompanionBuilder =
    LocalProductsCompanion Function({
      required String id,
      required String tenantId,
      required String name,
      Value<String?> barcode,
      required String unit,
      Value<String> unitType,
      required int salePrice,
      required int purchasePrice,
      Value<double> qty,
      Value<double> reorderLevel,
      Value<String?> supplierId,
      Value<double?> commissionRate,
      Value<DateTime?> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$LocalProductsTableUpdateCompanionBuilder =
    LocalProductsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> name,
      Value<String?> barcode,
      Value<String> unit,
      Value<String> unitType,
      Value<int> salePrice,
      Value<int> purchasePrice,
      Value<double> qty,
      Value<double> reorderLevel,
      Value<String?> supplierId,
      Value<double?> commissionRate,
      Value<DateTime?> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$LocalProductsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitType => $composableBuilder(
    column: $table.unitType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get salePrice => $composableBuilder(
    column: $table.salePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get reorderLevel => $composableBuilder(
    column: $table.reorderLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get commissionRate => $composableBuilder(
    column: $table.commissionRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitType => $composableBuilder(
    column: $table.unitType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get salePrice => $composableBuilder(
    column: $table.salePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get reorderLevel => $composableBuilder(
    column: $table.reorderLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get commissionRate => $composableBuilder(
    column: $table.commissionRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProductsTable> {
  $$LocalProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get unitType =>
      $composableBuilder(column: $table.unitType, builder: (column) => column);

  GeneratedColumn<int> get salePrice =>
      $composableBuilder(column: $table.salePrice, builder: (column) => column);

  GeneratedColumn<int> get purchasePrice => $composableBuilder(
    column: $table.purchasePrice,
    builder: (column) => column,
  );

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<double> get reorderLevel => $composableBuilder(
    column: $table.reorderLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get commissionRate => $composableBuilder(
    column: $table.commissionRate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$LocalProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProductsTable,
          LocalProductRow,
          $$LocalProductsTableFilterComposer,
          $$LocalProductsTableOrderingComposer,
          $$LocalProductsTableAnnotationComposer,
          $$LocalProductsTableCreateCompanionBuilder,
          $$LocalProductsTableUpdateCompanionBuilder,
          (
            LocalProductRow,
            BaseReferences<_$AppDatabase, $LocalProductsTable, LocalProductRow>,
          ),
          LocalProductRow,
          PrefetchHooks Function()
        > {
  $$LocalProductsTableTableManager(_$AppDatabase db, $LocalProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> unitType = const Value.absent(),
                Value<int> salePrice = const Value.absent(),
                Value<int> purchasePrice = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<double> reorderLevel = const Value.absent(),
                Value<String?> supplierId = const Value.absent(),
                Value<double?> commissionRate = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProductsCompanion(
                id: id,
                tenantId: tenantId,
                name: name,
                barcode: barcode,
                unit: unit,
                unitType: unitType,
                salePrice: salePrice,
                purchasePrice: purchasePrice,
                qty: qty,
                reorderLevel: reorderLevel,
                supplierId: supplierId,
                commissionRate: commissionRate,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String name,
                Value<String?> barcode = const Value.absent(),
                required String unit,
                Value<String> unitType = const Value.absent(),
                required int salePrice,
                required int purchasePrice,
                Value<double> qty = const Value.absent(),
                Value<double> reorderLevel = const Value.absent(),
                Value<String?> supplierId = const Value.absent(),
                Value<double?> commissionRate = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProductsCompanion.insert(
                id: id,
                tenantId: tenantId,
                name: name,
                barcode: barcode,
                unit: unit,
                unitType: unitType,
                salePrice: salePrice,
                purchasePrice: purchasePrice,
                qty: qty,
                reorderLevel: reorderLevel,
                supplierId: supplierId,
                commissionRate: commissionRate,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalProductsTable, LocalProductRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalProductsTable,
                    LocalProductRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProductsTable,
      LocalProductRow,
      $$LocalProductsTableFilterComposer,
      $$LocalProductsTableOrderingComposer,
      $$LocalProductsTableAnnotationComposer,
      $$LocalProductsTableCreateCompanionBuilder,
      $$LocalProductsTableUpdateCompanionBuilder,
      (
        LocalProductRow,
        BaseReferences<_$AppDatabase, $LocalProductsTable, LocalProductRow>,
      ),
      LocalProductRow,
      PrefetchHooks Function()
    >;
typedef $$LocalEmployeesTableCreateCompanionBuilder =
    LocalEmployeesCompanion Function({
      required String id,
      required String tenantId,
      required String name,
      Value<String?> jobTitle,
      Value<String?> phone,
      Value<int> baseSalary,
      Value<DateTime?> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$LocalEmployeesTableUpdateCompanionBuilder =
    LocalEmployeesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> name,
      Value<String?> jobTitle,
      Value<String?> phone,
      Value<int> baseSalary,
      Value<DateTime?> createdAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$LocalEmployeesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEmployeesTable> {
  $$LocalEmployeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobTitle => $composableBuilder(
    column: $table.jobTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseSalary => $composableBuilder(
    column: $table.baseSalary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEmployeesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEmployeesTable> {
  $$LocalEmployeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobTitle => $composableBuilder(
    column: $table.jobTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseSalary => $composableBuilder(
    column: $table.baseSalary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEmployeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEmployeesTable> {
  $$LocalEmployeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get jobTitle =>
      $composableBuilder(column: $table.jobTitle, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<int> get baseSalary => $composableBuilder(
    column: $table.baseSalary,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$LocalEmployeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEmployeesTable,
          LocalEmployeeRow,
          $$LocalEmployeesTableFilterComposer,
          $$LocalEmployeesTableOrderingComposer,
          $$LocalEmployeesTableAnnotationComposer,
          $$LocalEmployeesTableCreateCompanionBuilder,
          $$LocalEmployeesTableUpdateCompanionBuilder,
          (
            LocalEmployeeRow,
            BaseReferences<
              _$AppDatabase,
              $LocalEmployeesTable,
              LocalEmployeeRow
            >,
          ),
          LocalEmployeeRow,
          PrefetchHooks Function()
        > {
  $$LocalEmployeesTableTableManager(
    _$AppDatabase db,
    $LocalEmployeesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEmployeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEmployeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEmployeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> jobTitle = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<int> baseSalary = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmployeesCompanion(
                id: id,
                tenantId: tenantId,
                name: name,
                jobTitle: jobTitle,
                phone: phone,
                baseSalary: baseSalary,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String name,
                Value<String?> jobTitle = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<int> baseSalary = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmployeesCompanion.insert(
                id: id,
                tenantId: tenantId,
                name: name,
                jobTitle: jobTitle,
                phone: phone,
                baseSalary: baseSalary,
                createdAt: createdAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalEmployeesTable, LocalEmployeeRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalEmployeesTable,
                    LocalEmployeeRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEmployeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEmployeesTable,
      LocalEmployeeRow,
      $$LocalEmployeesTableFilterComposer,
      $$LocalEmployeesTableOrderingComposer,
      $$LocalEmployeesTableAnnotationComposer,
      $$LocalEmployeesTableCreateCompanionBuilder,
      $$LocalEmployeesTableUpdateCompanionBuilder,
      (
        LocalEmployeeRow,
        BaseReferences<_$AppDatabase, $LocalEmployeesTable, LocalEmployeeRow>,
      ),
      LocalEmployeeRow,
      PrefetchHooks Function()
    >;
typedef $$LocalAccountsTableCreateCompanionBuilder =
    LocalAccountsCompanion Function({
      required String id,
      required String tenantId,
      required String code,
      required String name,
      required String type,
      Value<String?> parentCode,
      Value<int> rowid,
    });
typedef $$LocalAccountsTableUpdateCompanionBuilder =
    LocalAccountsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> code,
      Value<String> name,
      Value<String> type,
      Value<String?> parentCode,
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
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentCode => $composableBuilder(
    column: $table.parentCode,
    builder: (column) => ColumnFilters(column),
  );
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
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentCode => $composableBuilder(
    column: $table.parentCode,
    builder: (column) => ColumnOrderings(column),
  );
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

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get parentCode => $composableBuilder(
    column: $table.parentCode,
    builder: (column) => column,
  );
}

class $$LocalAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAccountsTable,
          LocalAccountRow,
          $$LocalAccountsTableFilterComposer,
          $$LocalAccountsTableOrderingComposer,
          $$LocalAccountsTableAnnotationComposer,
          $$LocalAccountsTableCreateCompanionBuilder,
          $$LocalAccountsTableUpdateCompanionBuilder,
          (
            LocalAccountRow,
            BaseReferences<_$AppDatabase, $LocalAccountsTable, LocalAccountRow>,
          ),
          LocalAccountRow,
          PrefetchHooks Function()
        > {
  $$LocalAccountsTableTableManager(_$AppDatabase db, $LocalAccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> parentCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAccountsCompanion(
                id: id,
                tenantId: tenantId,
                code: code,
                name: name,
                type: type,
                parentCode: parentCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String code,
                required String name,
                required String type,
                Value<String?> parentCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAccountsCompanion.insert(
                id: id,
                tenantId: tenantId,
                code: code,
                name: name,
                type: type,
                parentCode: parentCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAccountsTable, LocalAccountRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalAccountsTable,
                    LocalAccountRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAccountsTable,
      LocalAccountRow,
      $$LocalAccountsTableFilterComposer,
      $$LocalAccountsTableOrderingComposer,
      $$LocalAccountsTableAnnotationComposer,
      $$LocalAccountsTableCreateCompanionBuilder,
      $$LocalAccountsTableUpdateCompanionBuilder,
      (
        LocalAccountRow,
        BaseReferences<_$AppDatabase, $LocalAccountsTable, LocalAccountRow>,
      ),
      LocalAccountRow,
      PrefetchHooks Function()
    >;
typedef $$LocalInvoicesTableCreateCompanionBuilder =
    LocalInvoicesCompanion Function({
      required String id,
      required String tenantId,
      required String type,
      required String no,
      required String partyId,
      Value<String?> partyName,
      required DateTime date,
      required int subtotal,
      required int total,
      required int paid,
      required int remaining,
      required String status,
      required String ownership,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });
typedef $$LocalInvoicesTableUpdateCompanionBuilder =
    LocalInvoicesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> type,
      Value<String> no,
      Value<String> partyId,
      Value<String?> partyName,
      Value<DateTime> date,
      Value<int> subtotal,
      Value<int> total,
      Value<int> paid,
      Value<int> remaining,
      Value<String> status,
      Value<String> ownership,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });

class $$LocalInvoicesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalInvoicesTable> {
  $$LocalInvoicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get no => $composableBuilder(
    column: $table.no,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyName => $composableBuilder(
    column: $table.partyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remaining => $composableBuilder(
    column: $table.remaining,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownership => $composableBuilder(
    column: $table.ownership,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalInvoicesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalInvoicesTable> {
  $$LocalInvoicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get no => $composableBuilder(
    column: $table.no,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyName => $composableBuilder(
    column: $table.partyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remaining => $composableBuilder(
    column: $table.remaining,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownership => $composableBuilder(
    column: $table.ownership,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalInvoicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalInvoicesTable> {
  $$LocalInvoicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get no =>
      $composableBuilder(column: $table.no, builder: (column) => column);

  GeneratedColumn<String> get partyId =>
      $composableBuilder(column: $table.partyId, builder: (column) => column);

  GeneratedColumn<String> get partyName =>
      $composableBuilder(column: $table.partyName, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<int> get remaining =>
      $composableBuilder(column: $table.remaining, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get ownership =>
      $composableBuilder(column: $table.ownership, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalInvoicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalInvoicesTable,
          LocalInvoiceRow,
          $$LocalInvoicesTableFilterComposer,
          $$LocalInvoicesTableOrderingComposer,
          $$LocalInvoicesTableAnnotationComposer,
          $$LocalInvoicesTableCreateCompanionBuilder,
          $$LocalInvoicesTableUpdateCompanionBuilder,
          (
            LocalInvoiceRow,
            BaseReferences<_$AppDatabase, $LocalInvoicesTable, LocalInvoiceRow>,
          ),
          LocalInvoiceRow,
          PrefetchHooks Function()
        > {
  $$LocalInvoicesTableTableManager(_$AppDatabase db, $LocalInvoicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalInvoicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalInvoicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalInvoicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> no = const Value.absent(),
                Value<String> partyId = const Value.absent(),
                Value<String?> partyName = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<int> subtotal = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> paid = const Value.absent(),
                Value<int> remaining = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> ownership = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalInvoicesCompanion(
                id: id,
                tenantId: tenantId,
                type: type,
                no: no,
                partyId: partyId,
                partyName: partyName,
                date: date,
                subtotal: subtotal,
                total: total,
                paid: paid,
                remaining: remaining,
                status: status,
                ownership: ownership,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String type,
                required String no,
                required String partyId,
                Value<String?> partyName = const Value.absent(),
                required DateTime date,
                required int subtotal,
                required int total,
                required int paid,
                required int remaining,
                required String status,
                required String ownership,
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalInvoicesCompanion.insert(
                id: id,
                tenantId: tenantId,
                type: type,
                no: no,
                partyId: partyId,
                partyName: partyName,
                date: date,
                subtotal: subtotal,
                total: total,
                paid: paid,
                remaining: remaining,
                status: status,
                ownership: ownership,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalInvoicesTable, LocalInvoiceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalInvoicesTable,
                    LocalInvoiceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalInvoicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalInvoicesTable,
      LocalInvoiceRow,
      $$LocalInvoicesTableFilterComposer,
      $$LocalInvoicesTableOrderingComposer,
      $$LocalInvoicesTableAnnotationComposer,
      $$LocalInvoicesTableCreateCompanionBuilder,
      $$LocalInvoicesTableUpdateCompanionBuilder,
      (
        LocalInvoiceRow,
        BaseReferences<_$AppDatabase, $LocalInvoicesTable, LocalInvoiceRow>,
      ),
      LocalInvoiceRow,
      PrefetchHooks Function()
    >;
typedef $$LocalInvoiceItemsTableCreateCompanionBuilder =
    LocalInvoiceItemsCompanion Function({
      required String id,
      required String tenantId,
      required String invoiceId,
      Value<String?> productId,
      Value<String?> productName,
      Value<String?> productUnit,
      Value<String?> productUnitType,
      required double qty,
      required int price,
      required int total,
      Value<int> rowid,
    });
typedef $$LocalInvoiceItemsTableUpdateCompanionBuilder =
    LocalInvoiceItemsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> invoiceId,
      Value<String?> productId,
      Value<String?> productName,
      Value<String?> productUnit,
      Value<String?> productUnitType,
      Value<double> qty,
      Value<int> price,
      Value<int> total,
      Value<int> rowid,
    });

class $$LocalInvoiceItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalInvoiceItemsTable> {
  $$LocalInvoiceItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceId => $composableBuilder(
    column: $table.invoiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productUnit => $composableBuilder(
    column: $table.productUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productUnitType => $composableBuilder(
    column: $table.productUnitType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalInvoiceItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalInvoiceItemsTable> {
  $$LocalInvoiceItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceId => $composableBuilder(
    column: $table.invoiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productUnit => $composableBuilder(
    column: $table.productUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productUnitType => $composableBuilder(
    column: $table.productUnitType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get qty => $composableBuilder(
    column: $table.qty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalInvoiceItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalInvoiceItemsTable> {
  $$LocalInvoiceItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get invoiceId =>
      $composableBuilder(column: $table.invoiceId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productUnit => $composableBuilder(
    column: $table.productUnit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productUnitType => $composableBuilder(
    column: $table.productUnitType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get qty =>
      $composableBuilder(column: $table.qty, builder: (column) => column);

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);
}

class $$LocalInvoiceItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalInvoiceItemsTable,
          LocalInvoiceItemRow,
          $$LocalInvoiceItemsTableFilterComposer,
          $$LocalInvoiceItemsTableOrderingComposer,
          $$LocalInvoiceItemsTableAnnotationComposer,
          $$LocalInvoiceItemsTableCreateCompanionBuilder,
          $$LocalInvoiceItemsTableUpdateCompanionBuilder,
          (
            LocalInvoiceItemRow,
            BaseReferences<
              _$AppDatabase,
              $LocalInvoiceItemsTable,
              LocalInvoiceItemRow
            >,
          ),
          LocalInvoiceItemRow,
          PrefetchHooks Function()
        > {
  $$LocalInvoiceItemsTableTableManager(
    _$AppDatabase db,
    $LocalInvoiceItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalInvoiceItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalInvoiceItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalInvoiceItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> invoiceId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String?> productName = const Value.absent(),
                Value<String?> productUnit = const Value.absent(),
                Value<String?> productUnitType = const Value.absent(),
                Value<double> qty = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalInvoiceItemsCompanion(
                id: id,
                tenantId: tenantId,
                invoiceId: invoiceId,
                productId: productId,
                productName: productName,
                productUnit: productUnit,
                productUnitType: productUnitType,
                qty: qty,
                price: price,
                total: total,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String invoiceId,
                Value<String?> productId = const Value.absent(),
                Value<String?> productName = const Value.absent(),
                Value<String?> productUnit = const Value.absent(),
                Value<String?> productUnitType = const Value.absent(),
                required double qty,
                required int price,
                required int total,
                Value<int> rowid = const Value.absent(),
              }) => LocalInvoiceItemsCompanion.insert(
                id: id,
                tenantId: tenantId,
                invoiceId: invoiceId,
                productId: productId,
                productName: productName,
                productUnit: productUnit,
                productUnitType: productUnitType,
                qty: qty,
                price: price,
                total: total,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalInvoiceItemsTable, LocalInvoiceItemRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalInvoiceItemsTable,
                    LocalInvoiceItemRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalInvoiceItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalInvoiceItemsTable,
      LocalInvoiceItemRow,
      $$LocalInvoiceItemsTableFilterComposer,
      $$LocalInvoiceItemsTableOrderingComposer,
      $$LocalInvoiceItemsTableAnnotationComposer,
      $$LocalInvoiceItemsTableCreateCompanionBuilder,
      $$LocalInvoiceItemsTableUpdateCompanionBuilder,
      (
        LocalInvoiceItemRow,
        BaseReferences<
          _$AppDatabase,
          $LocalInvoiceItemsTable,
          LocalInvoiceItemRow
        >,
      ),
      LocalInvoiceItemRow,
      PrefetchHooks Function()
    >;
typedef $$LocalPaymentsTableCreateCompanionBuilder =
    LocalPaymentsCompanion Function({
      required String id,
      required String tenantId,
      Value<String?> invoiceId,
      Value<String?> partyId,
      Value<String?> partyName,
      required int amount,
      required String method,
      required DateTime date,
      Value<String?> note,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });
typedef $$LocalPaymentsTableUpdateCompanionBuilder =
    LocalPaymentsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String?> invoiceId,
      Value<String?> partyId,
      Value<String?> partyName,
      Value<int> amount,
      Value<String> method,
      Value<DateTime> date,
      Value<String?> note,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });

class $$LocalPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPaymentsTable> {
  $$LocalPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceId => $composableBuilder(
    column: $table.invoiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyName => $composableBuilder(
    column: $table.partyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPaymentsTable> {
  $$LocalPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceId => $composableBuilder(
    column: $table.invoiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyId => $composableBuilder(
    column: $table.partyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyName => $composableBuilder(
    column: $table.partyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPaymentsTable> {
  $$LocalPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get invoiceId =>
      $composableBuilder(column: $table.invoiceId, builder: (column) => column);

  GeneratedColumn<String> get partyId =>
      $composableBuilder(column: $table.partyId, builder: (column) => column);

  GeneratedColumn<String> get partyName =>
      $composableBuilder(column: $table.partyName, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPaymentsTable,
          LocalPaymentRow,
          $$LocalPaymentsTableFilterComposer,
          $$LocalPaymentsTableOrderingComposer,
          $$LocalPaymentsTableAnnotationComposer,
          $$LocalPaymentsTableCreateCompanionBuilder,
          $$LocalPaymentsTableUpdateCompanionBuilder,
          (
            LocalPaymentRow,
            BaseReferences<_$AppDatabase, $LocalPaymentsTable, LocalPaymentRow>,
          ),
          LocalPaymentRow,
          PrefetchHooks Function()
        > {
  $$LocalPaymentsTableTableManager(_$AppDatabase db, $LocalPaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String?> invoiceId = const Value.absent(),
                Value<String?> partyId = const Value.absent(),
                Value<String?> partyName = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPaymentsCompanion(
                id: id,
                tenantId: tenantId,
                invoiceId: invoiceId,
                partyId: partyId,
                partyName: partyName,
                amount: amount,
                method: method,
                date: date,
                note: note,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                Value<String?> invoiceId = const Value.absent(),
                Value<String?> partyId = const Value.absent(),
                Value<String?> partyName = const Value.absent(),
                required int amount,
                required String method,
                required DateTime date,
                Value<String?> note = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPaymentsCompanion.insert(
                id: id,
                tenantId: tenantId,
                invoiceId: invoiceId,
                partyId: partyId,
                partyName: partyName,
                amount: amount,
                method: method,
                date: date,
                note: note,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalPaymentsTable, LocalPaymentRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalPaymentsTable,
                    LocalPaymentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPaymentsTable,
      LocalPaymentRow,
      $$LocalPaymentsTableFilterComposer,
      $$LocalPaymentsTableOrderingComposer,
      $$LocalPaymentsTableAnnotationComposer,
      $$LocalPaymentsTableCreateCompanionBuilder,
      $$LocalPaymentsTableUpdateCompanionBuilder,
      (
        LocalPaymentRow,
        BaseReferences<_$AppDatabase, $LocalPaymentsTable, LocalPaymentRow>,
      ),
      LocalPaymentRow,
      PrefetchHooks Function()
    >;
typedef $$LocalCommissionDuesTableCreateCompanionBuilder =
    LocalCommissionDuesCompanion Function({
      required String id,
      required String tenantId,
      required String invoiceId,
      required String productId,
      required String supplierId,
      required int dueAmount,
      Value<String> status,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });
typedef $$LocalCommissionDuesTableUpdateCompanionBuilder =
    LocalCommissionDuesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> invoiceId,
      Value<String> productId,
      Value<String> supplierId,
      Value<int> dueAmount,
      Value<String> status,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });

class $$LocalCommissionDuesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCommissionDuesTable> {
  $$LocalCommissionDuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceId => $composableBuilder(
    column: $table.invoiceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueAmount => $composableBuilder(
    column: $table.dueAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCommissionDuesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCommissionDuesTable> {
  $$LocalCommissionDuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceId => $composableBuilder(
    column: $table.invoiceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueAmount => $composableBuilder(
    column: $table.dueAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCommissionDuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCommissionDuesTable> {
  $$LocalCommissionDuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get invoiceId =>
      $composableBuilder(column: $table.invoiceId, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get supplierId => $composableBuilder(
    column: $table.supplierId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueAmount =>
      $composableBuilder(column: $table.dueAmount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalCommissionDuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCommissionDuesTable,
          LocalCommissionDueRow,
          $$LocalCommissionDuesTableFilterComposer,
          $$LocalCommissionDuesTableOrderingComposer,
          $$LocalCommissionDuesTableAnnotationComposer,
          $$LocalCommissionDuesTableCreateCompanionBuilder,
          $$LocalCommissionDuesTableUpdateCompanionBuilder,
          (
            LocalCommissionDueRow,
            BaseReferences<
              _$AppDatabase,
              $LocalCommissionDuesTable,
              LocalCommissionDueRow
            >,
          ),
          LocalCommissionDueRow,
          PrefetchHooks Function()
        > {
  $$LocalCommissionDuesTableTableManager(
    _$AppDatabase db,
    $LocalCommissionDuesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCommissionDuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCommissionDuesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalCommissionDuesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> invoiceId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> supplierId = const Value.absent(),
                Value<int> dueAmount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCommissionDuesCompanion(
                id: id,
                tenantId: tenantId,
                invoiceId: invoiceId,
                productId: productId,
                supplierId: supplierId,
                dueAmount: dueAmount,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String invoiceId,
                required String productId,
                required String supplierId,
                required int dueAmount,
                Value<String> status = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalCommissionDuesCompanion.insert(
                id: id,
                tenantId: tenantId,
                invoiceId: invoiceId,
                productId: productId,
                supplierId: supplierId,
                dueAmount: dueAmount,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalCommissionDuesTable, LocalCommissionDueRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalCommissionDuesTable,
                    LocalCommissionDueRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCommissionDuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCommissionDuesTable,
      LocalCommissionDueRow,
      $$LocalCommissionDuesTableFilterComposer,
      $$LocalCommissionDuesTableOrderingComposer,
      $$LocalCommissionDuesTableAnnotationComposer,
      $$LocalCommissionDuesTableCreateCompanionBuilder,
      $$LocalCommissionDuesTableUpdateCompanionBuilder,
      (
        LocalCommissionDueRow,
        BaseReferences<
          _$AppDatabase,
          $LocalCommissionDuesTable,
          LocalCommissionDueRow
        >,
      ),
      LocalCommissionDueRow,
      PrefetchHooks Function()
    >;
typedef $$LocalJournalEntriesTableCreateCompanionBuilder =
    LocalJournalEntriesCompanion Function({
      required String id,
      required String tenantId,
      required DateTime date,
      required String memo,
      required String lines,
      required String sourceType,
      Value<String?> sourceId,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });
typedef $$LocalJournalEntriesTableUpdateCompanionBuilder =
    LocalJournalEntriesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<DateTime> date,
      Value<String> memo,
      Value<String> lines,
      Value<String> sourceType,
      Value<String?> sourceId,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });

class $$LocalJournalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalJournalEntriesTable> {
  $$LocalJournalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lines => $composableBuilder(
    column: $table.lines,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalJournalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalJournalEntriesTable> {
  $$LocalJournalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lines => $composableBuilder(
    column: $table.lines,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalJournalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalJournalEntriesTable> {
  $$LocalJournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get lines =>
      $composableBuilder(column: $table.lines, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalJournalEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalJournalEntriesTable,
          LocalJournalEntryRow,
          $$LocalJournalEntriesTableFilterComposer,
          $$LocalJournalEntriesTableOrderingComposer,
          $$LocalJournalEntriesTableAnnotationComposer,
          $$LocalJournalEntriesTableCreateCompanionBuilder,
          $$LocalJournalEntriesTableUpdateCompanionBuilder,
          (
            LocalJournalEntryRow,
            BaseReferences<
              _$AppDatabase,
              $LocalJournalEntriesTable,
              LocalJournalEntryRow
            >,
          ),
          LocalJournalEntryRow,
          PrefetchHooks Function()
        > {
  $$LocalJournalEntriesTableTableManager(
    _$AppDatabase db,
    $LocalJournalEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalJournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalJournalEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalJournalEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> memo = const Value.absent(),
                Value<String> lines = const Value.absent(),
                Value<String> sourceType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalJournalEntriesCompanion(
                id: id,
                tenantId: tenantId,
                date: date,
                memo: memo,
                lines: lines,
                sourceType: sourceType,
                sourceId: sourceId,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required DateTime date,
                required String memo,
                required String lines,
                required String sourceType,
                Value<String?> sourceId = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalJournalEntriesCompanion.insert(
                id: id,
                tenantId: tenantId,
                date: date,
                memo: memo,
                lines: lines,
                sourceType: sourceType,
                sourceId: sourceId,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalJournalEntriesTable, LocalJournalEntryRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalJournalEntriesTable,
                    LocalJournalEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalJournalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalJournalEntriesTable,
      LocalJournalEntryRow,
      $$LocalJournalEntriesTableFilterComposer,
      $$LocalJournalEntriesTableOrderingComposer,
      $$LocalJournalEntriesTableAnnotationComposer,
      $$LocalJournalEntriesTableCreateCompanionBuilder,
      $$LocalJournalEntriesTableUpdateCompanionBuilder,
      (
        LocalJournalEntryRow,
        BaseReferences<
          _$AppDatabase,
          $LocalJournalEntriesTable,
          LocalJournalEntryRow
        >,
      ),
      LocalJournalEntryRow,
      PrefetchHooks Function()
    >;
typedef $$LocalEmployeeMovementsTableCreateCompanionBuilder =
    LocalEmployeeMovementsCompanion Function({
      required String id,
      required String tenantId,
      required String employeeId,
      Value<String?> month,
      required String direction,
      required String category,
      required int amount,
      required DateTime date,
      Value<String?> note,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });
typedef $$LocalEmployeeMovementsTableUpdateCompanionBuilder =
    LocalEmployeeMovementsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> employeeId,
      Value<String?> month,
      Value<String> direction,
      Value<String> category,
      Value<int> amount,
      Value<DateTime> date,
      Value<String?> note,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });

class $$LocalEmployeeMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEmployeeMovementsTable> {
  $$LocalEmployeeMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEmployeeMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEmployeeMovementsTable> {
  $$LocalEmployeeMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEmployeeMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEmployeeMovementsTable> {
  $$LocalEmployeeMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalEmployeeMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEmployeeMovementsTable,
          LocalEmployeeMovementRow,
          $$LocalEmployeeMovementsTableFilterComposer,
          $$LocalEmployeeMovementsTableOrderingComposer,
          $$LocalEmployeeMovementsTableAnnotationComposer,
          $$LocalEmployeeMovementsTableCreateCompanionBuilder,
          $$LocalEmployeeMovementsTableUpdateCompanionBuilder,
          (
            LocalEmployeeMovementRow,
            BaseReferences<
              _$AppDatabase,
              $LocalEmployeeMovementsTable,
              LocalEmployeeMovementRow
            >,
          ),
          LocalEmployeeMovementRow,
          PrefetchHooks Function()
        > {
  $$LocalEmployeeMovementsTableTableManager(
    _$AppDatabase db,
    $LocalEmployeeMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEmployeeMovementsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalEmployeeMovementsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalEmployeeMovementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> employeeId = const Value.absent(),
                Value<String?> month = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmployeeMovementsCompanion(
                id: id,
                tenantId: tenantId,
                employeeId: employeeId,
                month: month,
                direction: direction,
                category: category,
                amount: amount,
                date: date,
                note: note,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String employeeId,
                Value<String?> month = const Value.absent(),
                required String direction,
                required String category,
                required int amount,
                required DateTime date,
                Value<String?> note = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmployeeMovementsCompanion.insert(
                id: id,
                tenantId: tenantId,
                employeeId: employeeId,
                month: month,
                direction: direction,
                category: category,
                amount: amount,
                date: date,
                note: note,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalEmployeeMovementsTable,
                    LocalEmployeeMovementRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalEmployeeMovementsTable,
                    LocalEmployeeMovementRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEmployeeMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEmployeeMovementsTable,
      LocalEmployeeMovementRow,
      $$LocalEmployeeMovementsTableFilterComposer,
      $$LocalEmployeeMovementsTableOrderingComposer,
      $$LocalEmployeeMovementsTableAnnotationComposer,
      $$LocalEmployeeMovementsTableCreateCompanionBuilder,
      $$LocalEmployeeMovementsTableUpdateCompanionBuilder,
      (
        LocalEmployeeMovementRow,
        BaseReferences<
          _$AppDatabase,
          $LocalEmployeeMovementsTable,
          LocalEmployeeMovementRow
        >,
      ),
      LocalEmployeeMovementRow,
      PrefetchHooks Function()
    >;
typedef $$LocalSalariesTableCreateCompanionBuilder =
    LocalSalariesCompanion Function({
      required String id,
      required String tenantId,
      required String employeeId,
      required String month,
      required int paid,
      required int netDue,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });
typedef $$LocalSalariesTableUpdateCompanionBuilder =
    LocalSalariesCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> employeeId,
      Value<String> month,
      Value<int> paid,
      Value<int> netDue,
      Value<String?> requestId,
      Value<bool> synced,
      Value<DateTime?> createdAt,
      Value<int> rowid,
    });

class $$LocalSalariesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSalariesTable> {
  $$LocalSalariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get netDue => $composableBuilder(
    column: $table.netDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSalariesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSalariesTable> {
  $$LocalSalariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get netDue => $composableBuilder(
    column: $table.netDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSalariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSalariesTable> {
  $$LocalSalariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<int> get netDue =>
      $composableBuilder(column: $table.netDue, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalSalariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSalariesTable,
          LocalSalaryRow,
          $$LocalSalariesTableFilterComposer,
          $$LocalSalariesTableOrderingComposer,
          $$LocalSalariesTableAnnotationComposer,
          $$LocalSalariesTableCreateCompanionBuilder,
          $$LocalSalariesTableUpdateCompanionBuilder,
          (
            LocalSalaryRow,
            BaseReferences<_$AppDatabase, $LocalSalariesTable, LocalSalaryRow>,
          ),
          LocalSalaryRow,
          PrefetchHooks Function()
        > {
  $$LocalSalariesTableTableManager(_$AppDatabase db, $LocalSalariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSalariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSalariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSalariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> employeeId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<int> paid = const Value.absent(),
                Value<int> netDue = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSalariesCompanion(
                id: id,
                tenantId: tenantId,
                employeeId: employeeId,
                month: month,
                paid: paid,
                netDue: netDue,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String employeeId,
                required String month,
                required int paid,
                required int netDue,
                Value<String?> requestId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSalariesCompanion.insert(
                id: id,
                tenantId: tenantId,
                employeeId: employeeId,
                month: month,
                paid: paid,
                netDue: netDue,
                requestId: requestId,
                synced: synced,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSalariesTable, LocalSalaryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSalariesTable,
                    LocalSalaryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSalariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSalariesTable,
      LocalSalaryRow,
      $$LocalSalariesTableFilterComposer,
      $$LocalSalariesTableOrderingComposer,
      $$LocalSalariesTableAnnotationComposer,
      $$LocalSalariesTableCreateCompanionBuilder,
      $$LocalSalariesTableUpdateCompanionBuilder,
      (
        LocalSalaryRow,
        BaseReferences<_$AppDatabase, $LocalSalariesTable, LocalSalaryRow>,
      ),
      LocalSalaryRow,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueItemsTableCreateCompanionBuilder =
    SyncQueueItemsCompanion Function({
      required String id,
      required String tenantId,
      required String rpc,
      Value<String> op,
      required String params,
      Value<String?> requestId,
      Value<String?> entity,
      Value<String?> localId,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SyncQueueItemsTableUpdateCompanionBuilder =
    SyncQueueItemsCompanion Function({
      Value<String> id,
      Value<String> tenantId,
      Value<String> rpc,
      Value<String> op,
      Value<String> params,
      Value<String?> requestId,
      Value<String?> entity,
      Value<String?> localId,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncQueueItemsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rpc => $composableBuilder(
    column: $table.rpc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rpc => $composableBuilder(
    column: $table.rpc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get params => $composableBuilder(
    column: $table.params,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueItemsTable> {
  $$SyncQueueItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get rpc =>
      $composableBuilder(column: $table.rpc, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get params =>
      $composableBuilder(column: $table.params, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncQueueItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueItemsTable,
          SyncQueueRow,
          $$SyncQueueItemsTableFilterComposer,
          $$SyncQueueItemsTableOrderingComposer,
          $$SyncQueueItemsTableAnnotationComposer,
          $$SyncQueueItemsTableCreateCompanionBuilder,
          $$SyncQueueItemsTableUpdateCompanionBuilder,
          (
            SyncQueueRow,
            BaseReferences<_$AppDatabase, $SyncQueueItemsTable, SyncQueueRow>,
          ),
          SyncQueueRow,
          PrefetchHooks Function()
        > {
  $$SyncQueueItemsTableTableManager(
    _$AppDatabase db,
    $SyncQueueItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tenantId = const Value.absent(),
                Value<String> rpc = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> params = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<String?> entity = const Value.absent(),
                Value<String?> localId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueItemsCompanion(
                id: id,
                tenantId: tenantId,
                rpc: rpc,
                op: op,
                params: params,
                requestId: requestId,
                entity: entity,
                localId: localId,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tenantId,
                required String rpc,
                Value<String> op = const Value.absent(),
                required String params,
                Value<String?> requestId = const Value.absent(),
                Value<String?> entity = const Value.absent(),
                Value<String?> localId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueItemsCompanion.insert(
                id: id,
                tenantId: tenantId,
                rpc: rpc,
                op: op,
                params: params,
                requestId: requestId,
                entity: entity,
                localId: localId,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncQueueItemsTable, SyncQueueRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncQueueItemsTable,
                    SyncQueueRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueItemsTable,
      SyncQueueRow,
      $$SyncQueueItemsTableFilterComposer,
      $$SyncQueueItemsTableOrderingComposer,
      $$SyncQueueItemsTableAnnotationComposer,
      $$SyncQueueItemsTableCreateCompanionBuilder,
      $$SyncQueueItemsTableUpdateCompanionBuilder,
      (
        SyncQueueRow,
        BaseReferences<_$AppDatabase, $SyncQueueItemsTable, SyncQueueRow>,
      ),
      SyncQueueRow,
      PrefetchHooks Function()
    >;
typedef $$IdMappingsTableCreateCompanionBuilder = IdMappingsCompanion Function({
  required String entity,
  required String localId,
  required String serverId,
  Value<DateTime> syncedAt,
  Value<int> rowid,
});
typedef $$IdMappingsTableUpdateCompanionBuilder = IdMappingsCompanion Function({
  Value<String> entity,
  Value<String> localId,
  Value<String> serverId,
  Value<DateTime> syncedAt,
  Value<int> rowid,
});

class $$IdMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $IdMappingsTable> {
  $$IdMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IdMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $IdMappingsTable> {
  $$IdMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdMappingsTable> {
  $$IdMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$IdMappingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdMappingsTable,
          IdMappingRow,
          $$IdMappingsTableFilterComposer,
          $$IdMappingsTableOrderingComposer,
          $$IdMappingsTableAnnotationComposer,
          $$IdMappingsTableCreateCompanionBuilder,
          $$IdMappingsTableUpdateCompanionBuilder,
          (
            IdMappingRow,
            BaseReferences<_$AppDatabase, $IdMappingsTable, IdMappingRow>,
          ),
          IdMappingRow,
          PrefetchHooks Function()
        > {
  $$IdMappingsTableTableManager(_$AppDatabase db, $IdMappingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdMappingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdMappingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String> localId = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdMappingsCompanion(
                entity: entity,
                localId: localId,
                serverId: serverId,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required String localId,
                required String serverId,
                Value<DateTime> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdMappingsCompanion.insert(
                entity: entity,
                localId: localId,
                serverId: serverId,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IdMappingsTable, IdMappingRow>(table),
                  BaseReferences<_$AppDatabase, $IdMappingsTable, IdMappingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IdMappingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdMappingsTable,
      IdMappingRow,
      $$IdMappingsTableFilterComposer,
      $$IdMappingsTableOrderingComposer,
      $$IdMappingsTableAnnotationComposer,
      $$IdMappingsTableCreateCompanionBuilder,
      $$IdMappingsTableUpdateCompanionBuilder,
      (
        IdMappingRow,
        BaseReferences<_$AppDatabase, $IdMappingsTable, IdMappingRow>,
      ),
      IdMappingRow,
      PrefetchHooks Function()
    >;
typedef $$LocalTenantSettingsTableCreateCompanionBuilder =
    LocalTenantSettingsCompanion Function({
      required String tenantId,
      required String key,
      Value<String?> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalTenantSettingsTableUpdateCompanionBuilder =
    LocalTenantSettingsCompanion Function({
      Value<String> tenantId,
      Value<String> key,
      Value<String?> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalTenantSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTenantSettingsTable> {
  $$LocalTenantSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTenantSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTenantSettingsTable> {
  $$LocalTenantSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTenantSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTenantSettingsTable> {
  $$LocalTenantSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalTenantSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTenantSettingsTable,
          LocalTenantSettingRow,
          $$LocalTenantSettingsTableFilterComposer,
          $$LocalTenantSettingsTableOrderingComposer,
          $$LocalTenantSettingsTableAnnotationComposer,
          $$LocalTenantSettingsTableCreateCompanionBuilder,
          $$LocalTenantSettingsTableUpdateCompanionBuilder,
          (
            LocalTenantSettingRow,
            BaseReferences<
              _$AppDatabase,
              $LocalTenantSettingsTable,
              LocalTenantSettingRow
            >,
          ),
          LocalTenantSettingRow,
          PrefetchHooks Function()
        > {
  $$LocalTenantSettingsTableTableManager(
    _$AppDatabase db,
    $LocalTenantSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTenantSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTenantSettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalTenantSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> tenantId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTenantSettingsCompanion(
                tenantId: tenantId,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tenantId,
                required String key,
                Value<String?> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTenantSettingsCompanion.insert(
                tenantId: tenantId,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalTenantSettingsTable, LocalTenantSettingRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalTenantSettingsTable,
                    LocalTenantSettingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTenantSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTenantSettingsTable,
      LocalTenantSettingRow,
      $$LocalTenantSettingsTableFilterComposer,
      $$LocalTenantSettingsTableOrderingComposer,
      $$LocalTenantSettingsTableAnnotationComposer,
      $$LocalTenantSettingsTableCreateCompanionBuilder,
      $$LocalTenantSettingsTableUpdateCompanionBuilder,
      (
        LocalTenantSettingRow,
        BaseReferences<
          _$AppDatabase,
          $LocalTenantSettingsTable,
          LocalTenantSettingRow
        >,
      ),
      LocalTenantSettingRow,
      PrefetchHooks Function()
    >;
typedef $$ReportCacheEntriesTableCreateCompanionBuilder =
    ReportCacheEntriesCompanion Function({
      required String tenantId,
      required String key,
      required String payload,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });
typedef $$ReportCacheEntriesTableUpdateCompanionBuilder =
    ReportCacheEntriesCompanion Function({
      Value<String> tenantId,
      Value<String> key,
      Value<String> payload,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$ReportCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ReportCacheEntriesTable> {
  $$ReportCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReportCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReportCacheEntriesTable> {
  $$ReportCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tenantId => $composableBuilder(
    column: $table.tenantId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReportCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReportCacheEntriesTable> {
  $$ReportCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tenantId =>
      $composableBuilder(column: $table.tenantId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$ReportCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReportCacheEntriesTable,
          ReportCacheRow,
          $$ReportCacheEntriesTableFilterComposer,
          $$ReportCacheEntriesTableOrderingComposer,
          $$ReportCacheEntriesTableAnnotationComposer,
          $$ReportCacheEntriesTableCreateCompanionBuilder,
          $$ReportCacheEntriesTableUpdateCompanionBuilder,
          (
            ReportCacheRow,
            BaseReferences<
              _$AppDatabase,
              $ReportCacheEntriesTable,
              ReportCacheRow
            >,
          ),
          ReportCacheRow,
          PrefetchHooks Function()
        > {
  $$ReportCacheEntriesTableTableManager(
    _$AppDatabase db,
    $ReportCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReportCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReportCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReportCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> tenantId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportCacheEntriesCompanion(
                tenantId: tenantId,
                key: key,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tenantId,
                required String key,
                required String payload,
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReportCacheEntriesCompanion.insert(
                tenantId: tenantId,
                key: key,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReportCacheEntriesTable, ReportCacheRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ReportCacheEntriesTable,
                    ReportCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReportCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReportCacheEntriesTable,
      ReportCacheRow,
      $$ReportCacheEntriesTableFilterComposer,
      $$ReportCacheEntriesTableOrderingComposer,
      $$ReportCacheEntriesTableAnnotationComposer,
      $$ReportCacheEntriesTableCreateCompanionBuilder,
      $$ReportCacheEntriesTableUpdateCompanionBuilder,
      (
        ReportCacheRow,
        BaseReferences<_$AppDatabase, $ReportCacheEntriesTable, ReportCacheRow>,
      ),
      ReportCacheRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalCustomersTableTableManager get localCustomers =>
      $$LocalCustomersTableTableManager(_db, _db.localCustomers);
  $$LocalSuppliersTableTableManager get localSuppliers =>
      $$LocalSuppliersTableTableManager(_db, _db.localSuppliers);
  $$LocalProductsTableTableManager get localProducts =>
      $$LocalProductsTableTableManager(_db, _db.localProducts);
  $$LocalEmployeesTableTableManager get localEmployees =>
      $$LocalEmployeesTableTableManager(_db, _db.localEmployees);
  $$LocalAccountsTableTableManager get localAccounts =>
      $$LocalAccountsTableTableManager(_db, _db.localAccounts);
  $$LocalInvoicesTableTableManager get localInvoices =>
      $$LocalInvoicesTableTableManager(_db, _db.localInvoices);
  $$LocalInvoiceItemsTableTableManager get localInvoiceItems =>
      $$LocalInvoiceItemsTableTableManager(_db, _db.localInvoiceItems);
  $$LocalPaymentsTableTableManager get localPayments =>
      $$LocalPaymentsTableTableManager(_db, _db.localPayments);
  $$LocalCommissionDuesTableTableManager get localCommissionDues =>
      $$LocalCommissionDuesTableTableManager(_db, _db.localCommissionDues);
  $$LocalJournalEntriesTableTableManager get localJournalEntries =>
      $$LocalJournalEntriesTableTableManager(_db, _db.localJournalEntries);
  $$LocalEmployeeMovementsTableTableManager get localEmployeeMovements =>
      $$LocalEmployeeMovementsTableTableManager(
        _db,
        _db.localEmployeeMovements,
      );
  $$LocalSalariesTableTableManager get localSalaries =>
      $$LocalSalariesTableTableManager(_db, _db.localSalaries);
  $$SyncQueueItemsTableTableManager get syncQueueItems =>
      $$SyncQueueItemsTableTableManager(_db, _db.syncQueueItems);
  $$IdMappingsTableTableManager get idMappings =>
      $$IdMappingsTableTableManager(_db, _db.idMappings);
  $$LocalTenantSettingsTableTableManager get localTenantSettings =>
      $$LocalTenantSettingsTableTableManager(_db, _db.localTenantSettings);
  $$ReportCacheEntriesTableTableManager get reportCacheEntries =>
      $$ReportCacheEntriesTableTableManager(_db, _db.reportCacheEntries);
}
