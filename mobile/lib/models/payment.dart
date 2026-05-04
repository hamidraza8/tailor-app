class Payment {
  final int? id;
  final String? serverId;
  final int? orderId;
  final String? orderServerId;
  final double amount;
  final String method;
  final String? reference;
  final String? notes;
  final DateTime paidAt;
  final DateTime createdAt;
  final bool synced;

  Payment({
    this.id,
    this.serverId,
    this.orderId,
    this.orderServerId,
    required this.amount,
    required this.method,
    this.reference,
    this.notes,
    DateTime? paidAt,
    DateTime? createdAt,
    this.synced = false,
  })  : paidAt = paidAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'order_id': orderId,
      'order_server_id': orderServerId,
      'amount': amount,
      'method': method,
      'reference': reference,
      'notes': notes,
      'paid_at': paidAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      orderId: map['order_id'] as int?,
      orderServerId: map['order_server_id'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      method: map['method'] as String? ?? 'Cash',
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'] as String)
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      synced: (map['synced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderServerId ?? orderId?.toString(),
      'amount': amount,
      'method': method,
      'reference': reference,
      'notes': notes,
      'paidAt': paidAt.toIso8601String(),
    };
  }
}
