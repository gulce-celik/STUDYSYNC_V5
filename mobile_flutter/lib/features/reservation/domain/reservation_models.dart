enum ReservationType { individual, group }

class Workspace {
  Workspace({
    required this.id,
    required this.type,
    required this.capacity,
    required this.status,
    required this.x,
    required this.y,
  });

  final String id;
  final String type;
  final int capacity;
  final String status;
  final int x;
  final int y;

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      type: json['type'] as String,
      capacity: (json['capacity'] as num).toInt(),
      status: json['status'] as String,
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
    );
  }
}

/// Backend `ReservationDetailDto` + istemci tarafı ek alanlar (`checkedIn`, `qrPayload`) — api-contract-v1.
class ReservationDetail {
  const ReservationDetail({
    required this.id,
    required this.workspaceId,
    required this.date,
    required this.slotId,
    required this.slotLabel,
    required this.status,
    required this.courseCode,
    required this.participants,
    this.checkedIn = false,
    this.qrPayload,
    this.scoreChange,
  });

  final String id;
  final String workspaceId;
  final String date;
  final String slotId;
  final String slotLabel;
  final String status;
  final String courseCode;
  final List<String> participants;
  final bool checkedIn;
  final String? qrPayload;
  /// Responsibility score delta from backend when status is terminal (COMPLETED, CANCELLED, NO_SHOW).
  final int? scoreChange;

  bool get isGroup => participants.length > 1;

  factory ReservationDetail.fromJson(Map<String, dynamic> json) {
    final parts = json['participants'];
    final pList = parts is List ? parts.map((e) => e.toString()).toList() : <String>[];
    return ReservationDetail(
      id: json['id']?.toString() ?? '',
      workspaceId: json['workspaceId']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      slotId: json['slotId']?.toString() ?? '',
      slotLabel: json['slotLabel']?.toString() ?? '',
      status: (json['status']?.toString() ?? 'PENDING').toUpperCase(),
      courseCode: json['courseCode']?.toString() ?? '',
      participants: pList,
      checkedIn: json['checkedIn'] == true,
      qrPayload: json['qrPayload']?.toString(),
      scoreChange: _parseScoreChange(json['scoreChange']),
    );
  }

  static int? _parseScoreChange(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }
}
