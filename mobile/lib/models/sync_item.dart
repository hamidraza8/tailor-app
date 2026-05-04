class SyncItem {
  final int? id;
  final String entityType;
  final int entityId;
  final String action;
  final String? payload;
  final String? filePath;
  final String status;
  final int retryCount;
  final String? errorMessage;
  final DateTime createdAt;

  SyncItem({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.payload,
    this.filePath,
    this.status = 'pending',
    this.retryCount = 0,
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': payload,
      'file_path': filePath,
      'status': status,
      'retry_count': retryCount,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SyncItem.fromMap(Map<String, dynamic> map) {
    return SyncItem(
      id: map['id'] as int?,
      entityType: map['entity_type'] as String? ?? '',
      entityId: map['entity_id'] as int? ?? 0,
      action: map['action'] as String? ?? 'create',
      payload: map['payload'] as String?,
      filePath: map['file_path'] as String?,
      status: map['status'] as String? ?? 'pending',
      retryCount: map['retry_count'] as int? ?? 0,
      errorMessage: map['error_message'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  SyncItem copyWith({
    int? id,
    String? entityType,
    int? entityId,
    String? action,
    String? payload,
    String? filePath,
    String? status,
    int? retryCount,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return SyncItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      filePath: filePath ?? this.filePath,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
