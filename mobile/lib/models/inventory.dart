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
