class InventoryTransaction {
  final int? id;
  final String? serverId;
  final String itemName;
  final String type;
  final int quantity;
  final String? unit;
  final double costPerUnit;
  final double totalCost;
  final String? supplier;
  final String? receiptPhotoPath;
  final String? receiptPhotoUrl;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final bool synced;

  InventoryTransaction({
    this.id,
    this.serverId,
    required this.itemName,
    this.type = 'Purchase',
    required this.quantity,
    this.unit,
    required this.costPerUnit,
    double? totalCost,
    this.supplier,
    this.receiptPhotoPath,
    this.receiptPhotoUrl,
    this.status = 'Pending',
    this.notes,
    DateTime? createdAt,
    this.synced = false,
  })  : totalCost = totalCost ?? (costPerUnit * quantity),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'item_name': itemName,
      'type': type,
      'quantity': quantity,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'supplier': supplier,
      'receipt_photo_path': receiptPhotoPath,
      'receipt_photo_url': receiptPhotoUrl,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory InventoryTransaction.fromMap(Map<String, dynamic> map) {
    return InventoryTransaction(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      itemName: map['item_name'] as String? ?? '',
      type: map['type'] as String? ?? 'Purchase',
      quantity: (map['quantity'] as int?) ?? 0,
      unit: map['unit'] as String?,
      costPerUnit: (map['cost_per_unit'] as num?)?.toDouble() ?? 0,
      totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0,
      supplier: map['supplier'] as String?,
      receiptPhotoPath: map['receipt_photo_path'] as String?,
      receiptPhotoUrl: map['receipt_photo_url'] as String?,
      status: map['status'] as String? ?? 'Pending',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      synced: (map['synced'] as int?) == 1,
    );
  }

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryTransaction(
      serverId: json['id']?.toString(),
      itemName: json['itemName'] as String? ?? '',
      type: json['type'] as String? ?? 'Purchase',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String?,
      costPerUnit: (json['costPerUnit'] as num?)?.toDouble() ?? 0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
      supplier: json['supplier'] as String?,
      receiptPhotoUrl: json['receiptPhotoUrl'] as String?,
      status: json['approvalStatus'] as String? ?? json['status'] as String? ?? 'Pending',
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      synced: true,
    );
  }

  InventoryTransaction copyWith({
    int? id,
    String? serverId,
    String? itemName,
    String? type,
    int? quantity,
    String? unit,
    double? costPerUnit,
    double? totalCost,
    String? supplier,
    String? receiptPhotoPath,
    String? receiptPhotoUrl,
    String? status,
    String? notes,
    DateTime? createdAt,
    bool? synced,
  }) {
    return InventoryTransaction(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      itemName: itemName ?? this.itemName,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      totalCost: totalCost ?? this.totalCost,
      supplier: supplier ?? this.supplier,
      receiptPhotoPath: receiptPhotoPath ?? this.receiptPhotoPath,
      receiptPhotoUrl: receiptPhotoUrl ?? this.receiptPhotoUrl,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'type': type,
      'quantity': quantity,
      'unit': unit,
      'costPerUnit': costPerUnit,
      'totalCost': totalCost,
      'supplier': supplier,
      'status': status,
      'notes': notes,
    };
  }
}
