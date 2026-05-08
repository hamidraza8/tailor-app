class Order {
  final int? id;
  final String? serverId;
  final int? customerId;
  final String? customerServerId;
  final String? customerName;
  final String? customerPhone;
  final String orderType;
  final String status;
  final double stitchingAmount;
  final double materialAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final double discount;
  final String? designPhotoPath;
  final String? designPhotoUrl;
  final int? measurementId;
  final String? measurementServerId;
  final String? orderNumber;
  final String? notes;
  final String? specialInstructions;
  final bool isUrgent;
  final double labourSharePercentage;
  final double labourAmount;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  Order({
    this.id,
    this.serverId,
    this.customerId,
    this.customerServerId,
    this.customerName,
    this.customerPhone,
    required this.orderType,
    this.status = 'Pending',
    required this.stitchingAmount,
    this.materialAmount = 0,
    double? totalAmount,
    this.paidAmount = 0,
    double? balanceAmount,
    this.discount = 0,
    this.designPhotoPath,
    this.designPhotoUrl,
    this.measurementId,
    this.measurementServerId,
    this.orderNumber,
    this.notes,
    this.specialInstructions,
    this.isUrgent = false,
    this.labourSharePercentage = 35,
    this.labourAmount = 0,
    this.dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
  })  : totalAmount = totalAmount ?? (stitchingAmount + materialAmount),
        balanceAmount = balanceAmount ??
            ((totalAmount ?? (stitchingAmount + materialAmount)) - paidAmount),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'server_id': serverId,
      'customer_id': customerId,
      'customer_server_id': customerServerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'order_type': orderType,
      'status': status,
      'stitching_amount': stitchingAmount,
      'material_amount': materialAmount,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'balance_amount': balanceAmount,
      'design_photo_path': designPhotoPath,
      'design_photo_url': designPhotoUrl,
      'measurement_id': measurementId,
      'notes': notes,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      customerId: map['customer_id'] as int?,
      customerServerId: map['customer_server_id'] as String?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      orderType: map['order_type'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      stitchingAmount: (map['stitching_amount'] as num?)?.toDouble() ?? 0,
      materialAmount: (map['material_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
      balanceAmount: (map['balance_amount'] as num?)?.toDouble() ?? 0,
      designPhotoPath: map['design_photo_path'] as String?,
      designPhotoUrl: map['design_photo_url'] as String?,
      measurementId: map['measurement_id'] as int?,
      notes: map['notes'] as String?,
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
      synced: (map['synced'] as int?) == 1,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    String? photoUrl;
    if (json['photos'] is List && (json['photos'] as List).isNotEmpty) {
      photoUrl = (json['photos'] as List).first['url']?.toString();
    }
    return Order(
      serverId: json['id']?.toString(),
      customerServerId: json['customerId']?.toString(),
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      orderType: json['orderType'] as String? ?? '',
      status: json['status'] as String? ?? 'Received',
      stitchingAmount: (json['stitchingAmount'] as num?)?.toDouble() ?? 0,
      materialAmount: (json['materialAmount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      designPhotoUrl: photoUrl,
      measurementServerId: json['measurementId']?.toString(),
      orderNumber: json['orderNumber'] as String?,
      notes: json['designNotes'] as String? ?? json['notes'] as String?,
      specialInstructions: json['specialInstructions'] as String?,
      isUrgent: json['isUrgent'] as bool? ?? false,
      labourSharePercentage: (json['labourSharePercentage'] as num?)?.toDouble() ?? 35,
      labourAmount: (json['labourAmount'] as num?)?.toDouble() ?? 0,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      synced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'orderType': orderType,
      'status': status,
      'stitchingAmount': stitchingAmount,
      'materialAmount': materialAmount,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'notes': notes,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  Order copyWith({
    int? id,
    String? serverId,
    int? customerId,
    String? customerServerId,
    String? customerName,
    String? customerPhone,
    String? orderType,
    String? status,
    double? stitchingAmount,
    double? materialAmount,
    double? totalAmount,
    double? paidAmount,
    double? balanceAmount,
    double? discount,
    String? designPhotoPath,
    String? designPhotoUrl,
    int? measurementId,
    String? measurementServerId,
    String? orderNumber,
    String? notes,
    String? specialInstructions,
    bool? isUrgent,
    double? labourSharePercentage,
    double? labourAmount,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return Order(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      customerId: customerId ?? this.customerId,
      customerServerId: customerServerId ?? this.customerServerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderType: orderType ?? this.orderType,
      status: status ?? this.status,
      stitchingAmount: stitchingAmount ?? this.stitchingAmount,
      materialAmount: materialAmount ?? this.materialAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      discount: discount ?? this.discount,
      designPhotoPath: designPhotoPath ?? this.designPhotoPath,
      designPhotoUrl: designPhotoUrl ?? this.designPhotoUrl,
      measurementId: measurementId ?? this.measurementId,
      measurementServerId: measurementServerId ?? this.measurementServerId,
      orderNumber: orderNumber ?? this.orderNumber,
      notes: notes ?? this.notes,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      isUrgent: isUrgent ?? this.isUrgent,
      labourSharePercentage: labourSharePercentage ?? this.labourSharePercentage,
      labourAmount: labourAmount ?? this.labourAmount,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }
}
