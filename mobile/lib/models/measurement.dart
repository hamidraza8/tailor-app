class Measurement {
  final int? id;
  final String? serverId;
  final int? customerId;
  final String? customerServerId;
  final String orderType;
  final double? chest;
  final double? waist;
  final double? hip;
  final double? shoulder;
  final double? armLength;
  final double? shirtLength;
  final double? trouserLength;
  final double? trouserWaist;
  final double? inseam;
  final double? neckSize;
  final double? wristSize;
  final double? bottomWidth;
  final String? notes;
  final DateTime createdAt;
  final bool synced;

  Measurement({
    this.id,
    this.serverId,
    this.customerId,
    this.customerServerId,
    required this.orderType,
    this.chest,
    this.waist,
    this.hip,
    this.shoulder,
    this.armLength,
    this.shirtLength,
    this.trouserLength,
    this.trouserWaist,
    this.inseam,
    this.neckSize,
    this.wristSize,
    this.bottomWidth,
    this.notes,
    DateTime? createdAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'customer_id': customerId,
      'customer_server_id': customerServerId,
      'order_type': orderType,
      'chest': chest,
      'waist': waist,
      'hip': hip,
      'shoulder': shoulder,
      'arm_length': armLength,
      'shirt_length': shirtLength,
      'trouser_length': trouserLength,
      'trouser_waist': trouserWaist,
      'inseam': inseam,
      'neck_size': neckSize,
      'wrist_size': wristSize,
      'bottom_width': bottomWidth,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory Measurement.fromMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      customerId: map['customer_id'] as int?,
      customerServerId: map['customer_server_id'] as String?,
      orderType: map['order_type'] as String? ?? '',
      chest: (map['chest'] as num?)?.toDouble(),
      waist: (map['waist'] as num?)?.toDouble(),
      hip: (map['hip'] as num?)?.toDouble(),
      shoulder: (map['shoulder'] as num?)?.toDouble(),
      armLength: (map['arm_length'] as num?)?.toDouble(),
      shirtLength: (map['shirt_length'] as num?)?.toDouble(),
      trouserLength: (map['trouser_length'] as num?)?.toDouble(),
      trouserWaist: (map['trouser_waist'] as num?)?.toDouble(),
      inseam: (map['inseam'] as num?)?.toDouble(),
      neckSize: (map['neck_size'] as num?)?.toDouble(),
      wristSize: (map['wrist_size'] as num?)?.toDouble(),
      bottomWidth: (map['bottom_width'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      synced: (map['synced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderType': orderType,
      'chest': chest,
      'waist': waist,
      'hip': hip,
      'shoulder': shoulder,
      'armLength': armLength,
      'shirtLength': shirtLength,
      'trouserLength': trouserLength,
      'trouserWaist': trouserWaist,
      'inseam': inseam,
      'neckSize': neckSize,
      'wristSize': wristSize,
      'bottomWidth': bottomWidth,
      'notes': notes,
    };
  }
}
