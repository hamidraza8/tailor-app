class Asset {
  final int? id;
  final String? serverId;
  final String name;
  final String type;
  final int quantity;
  final double unitValue;
  final double totalValue;
  final String? owner;
  final String? photoPath;
  final String? photoUrl;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final bool synced;

  Asset({
    this.id,
    this.serverId,
    required this.name,
    required this.type,
    this.quantity = 1,
    required this.unitValue,
    double? totalValue,
    this.owner,
    this.photoPath,
    this.photoUrl,
    this.status = 'Pending',
    this.notes,
    DateTime? createdAt,
    this.synced = false,
  })  : totalValue = totalValue ?? (unitValue * quantity),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'name': name,
      'type': type,
      'quantity': quantity,
      'unit_value': unitValue,
      'total_value': totalValue,
      'owner': owner,
      'photo_path': photoPath,
      'photo_url': photoUrl,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? '',
      quantity: (map['quantity'] as int?) ?? 1,
      unitValue: (map['unit_value'] as num?)?.toDouble() ?? 0,
      totalValue: (map['total_value'] as num?)?.toDouble() ?? 0,
      owner: map['owner'] as String?,
      photoPath: map['photo_path'] as String?,
      photoUrl: map['photo_url'] as String?,
      status: map['status'] as String? ?? 'Pending',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      synced: (map['synced'] as int?) == 1,
    );
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      serverId: json['id']?.toString(),
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitValue: (json['unitValue'] as num?)?.toDouble() ?? 0,
      totalValue: (json['totalValue'] as num?)?.toDouble() ?? 0,
      owner: json['owner'] as String?,
      photoUrl: json['photoUrl'] as String?,
      status: json['approvalStatus'] as String? ?? json['status'] as String? ?? 'Pending',
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      synced: true,
    );
  }

  Asset copyWith({
    int? id,
    String? serverId,
    String? name,
    String? type,
    int? quantity,
    double? unitValue,
    double? totalValue,
    String? owner,
    String? photoPath,
    String? photoUrl,
    String? status,
    String? notes,
    DateTime? createdAt,
    bool? synced,
  }) {
    return Asset(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      unitValue: unitValue ?? this.unitValue,
      totalValue: totalValue ?? this.totalValue,
      owner: owner ?? this.owner,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'quantity': quantity,
      'unitValue': unitValue,
      'totalValue': totalValue,
      'owner': owner,
      'status': status,
      'notes': notes,
    };
  }
}
