import 'package:flutter/material.dart';
import 'proof.dart';

enum MissionStatus {
  created,
  accepted,
  onTheWay,
  inProgress,
  completed,
  cancelled,
}

extension MissionStatusExtension on MissionStatus {
  Color get color {
    switch (this) {
      case MissionStatus.created:
        return const Color(0xFF94A3B8);
      case MissionStatus.accepted:
        return const Color(0xFF60A5FA);
      case MissionStatus.onTheWay:
        return const Color(0xFFF59E0B);
      case MissionStatus.inProgress:
        return const Color(0xFF00C896);
      case MissionStatus.completed:
        return const Color(0xFF22C55E);
      case MissionStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  String get label {
    switch (this) {
      case MissionStatus.created:
        return 'Demande reçue';
      case MissionStatus.accepted:
        return 'Expert assigné';
      case MissionStatus.onTheWay:
        return 'Prise en charge';
      case MissionStatus.inProgress:
        return 'Démarche en cours';
      case MissionStatus.completed:
        return 'Dossier clôturé';
      case MissionStatus.cancelled:
        return 'Annulée';
    }
  }

  String get emoji {
    switch (this) {
      case MissionStatus.created:
        return '📋';
      case MissionStatus.accepted:
        return '👤';
      case MissionStatus.onTheWay:
        return '🔄';
      case MissionStatus.inProgress:
        return '⚙️';
      case MissionStatus.completed:
        return '✅';
      case MissionStatus.cancelled:
        return '✖️';
    }
  }
}

class Mission {
  final String id;
  final String category;
  final String address;
  final String timeSlot;
  final String note;
  final MissionStatus status;
  final String clientId;
  final String? agentId;
  final Proof? proof;
  final double basePrice;
  final bool isExpress;
  final double totalPrice;

  // Rating — rempli par le client après completed
  final int? ratingScore;       // 1 à 5
  final String? ratingComment;  // optionnel

  const Mission({
    required this.id,
    required this.category,
    required this.address,
    required this.timeSlot,
    required this.note,
    required this.status,
    required this.basePrice,
    required this.isExpress,
    required this.totalPrice,
    required this.clientId,
    this.agentId,
    this.proof,
    this.ratingScore,
    this.ratingComment,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'].toString(),
      category: json['category'] as String,
      address: json['address'] as String,
      timeSlot: json['timeSlot'] as String,
      note: json['note'] as String? ?? '',
      status: _statusFromString(json['status'] as String),
      clientId: json['clientId'].toString(),
      agentId: json['agentId']?.toString(),
      basePrice: (json['basePrice'] as num).toDouble(),
      isExpress: json['isExpress'] as bool? ?? false,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      proof: json['proof'] != null
          ? Proof.fromJson(json['proof'] as Map<String, dynamic>)
          : null,
      ratingScore: json['ratingScore'] as int?,
      ratingComment: json['ratingComment'] as String?,
    );
  }

  /// Maps a backend Appointment JSON to our Mission model.
  factory Mission.fromAppointmentJson(Map<String, dynamic> json) {
    final service = json['service'] as Map<String, dynamic>?;
    final employee = json['employee'] as Map<String, dynamic>?;
    final salon = json['salon'] as Map<String, dynamic>?;
    final price = (service?['price'] as num?)?.toDouble() ?? 0.0;

    return Mission(
      id: json['id'].toString(),
      category: service?['name'] as String? ?? 'Service beauté',
      address: salon?['address'] as String? ?? '',
      timeSlot: json['date'] as String? ?? '',
      note: json['note'] as String? ?? '',
      status: _statusFromBackend(json['status'] as String? ?? 'PENDING'),
      clientId: json['userId'].toString(),
      agentId: employee?['id']?.toString(),
      basePrice: price,
      isExpress: false,
      totalPrice: price,
      ratingScore: null,
      ratingComment: null,
    );
  }

  /// Maps the real backend /tasks JSON (NestJS TaskEntity) to Mission.
  factory Mission.fromTaskJson(Map<String, dynamic> json) {
    final price = (json['priceTotal'] as num?)?.toDouble() ?? 0.0;
    final pickupLat = json['pickupLat']?.toString() ?? '';
    final pickupLng = json['pickupLng']?.toString() ?? '';
    final address = (pickupLat.isNotEmpty && pickupLng.isNotEmpty)
        ? '$pickupLat, $pickupLng'
        : 'Adresse non définie';

    return Mission(
      id: json['id'].toString(),
      category: _mapBackendCategory(json['category'] as String? ?? 'QUEUE'),
      address: address,
      timeSlot: json['createdAt'] as String? ?? '',
      note: json['description'] as String? ?? '',
      status: statusFromTaskBackend(json['status'] as String? ?? 'REQUESTED'),
      clientId: json['clientId']?.toString() ?? '',
      agentId: json['agentId']?.toString(),
      basePrice: price,
      isExpress: false,
      totalPrice: price,
      ratingScore: null,
      ratingComment: null,
    );
  }

  /// Backend TaskStatus → MissionStatus Flutter
  static MissionStatus statusFromTaskBackend(String value) {
    switch (value.toUpperCase()) {
      case 'REQUESTED':
      case 'PAID':
        return MissionStatus.created;
      case 'ASSIGNED':
        return MissionStatus.accepted;
      case 'IN_PROGRESS':
      case 'PROOF_SUBMITTED':
        return MissionStatus.inProgress;
      case 'COMPLETED':
        return MissionStatus.completed;
      case 'CANCELLED':
      case 'DISPUTED':
        return MissionStatus.cancelled;
      case 'DRAFT':
      default:
        return MissionStatus.created;
    }
  }

  /// MissionStatus Flutter → Backend TaskStatus string
  static String statusToTaskBackend(MissionStatus status) {
    switch (status) {
      case MissionStatus.created:
        return 'REQUESTED';
      case MissionStatus.accepted:
      case MissionStatus.onTheWay:
        return 'ASSIGNED';
      case MissionStatus.inProgress:
        return 'IN_PROGRESS';
      case MissionStatus.completed:
        return 'COMPLETED';
      case MissionStatus.cancelled:
        return 'CANCELLED';
    }
  }

  /// Backend category enum → label lisible
  static String _mapBackendCategory(String backendCat) {
    switch (backendCat.toUpperCase()) {
      case 'QUEUE':        return "File d'attente";
      case 'DEPOT':        return 'Dépôt de documents';
      case 'RECUPERATION': return 'Récupération de documents';
      case 'COURSE_URGENTE': return 'Course urgente';
      default:             return backendCat;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'address': address,
      'timeSlot': timeSlot,
      'note': note,
      'status': status.name,
      'clientId': clientId,
      'agentId': agentId,
      'basePrice': basePrice,
      'isExpress': isExpress,
      'totalPrice': totalPrice,
      'proof': proof?.toJson(),
      'ratingScore': ratingScore,
      'ratingComment': ratingComment,
    };
  }

  Mission copyWith({
    String? id,
    String? category,
    String? address,
    String? timeSlot,
    String? note,
    MissionStatus? status,
    String? clientId,
    String? agentId,
    double? basePrice,
    bool? isExpress,
    double? totalPrice,
    Proof? proof,
    int? ratingScore,
    String? ratingComment,
  }) {
    return Mission(
      id: id ?? this.id,
      category: category ?? this.category,
      address: address ?? this.address,
      timeSlot: timeSlot ?? this.timeSlot,
      note: note ?? this.note,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      agentId: agentId ?? this.agentId,
      basePrice: basePrice ?? this.basePrice,
      isExpress: isExpress ?? this.isExpress,
      totalPrice: totalPrice ?? this.totalPrice,
      proof: proof ?? this.proof,
      ratingScore: ratingScore ?? this.ratingScore,
      ratingComment: ratingComment ?? this.ratingComment,
    );
  }

  static MissionStatus _statusFromString(String value) {
    switch (value) {
      case 'accepted':
        return MissionStatus.accepted;
      case 'onTheWay':
        return MissionStatus.onTheWay;
      case 'inProgress':
        return MissionStatus.inProgress;
      case 'completed':
        return MissionStatus.completed;
      case 'cancelled':
        return MissionStatus.cancelled;
      case 'created':
      default:
        return MissionStatus.created;
    }
  }

  static MissionStatus _statusFromBackend(String value) {
    switch (value.toUpperCase()) {
      case 'CONFIRMED':
        return MissionStatus.accepted;
      case 'COMPLETED':
        return MissionStatus.completed;
      case 'CANCELLED':
      case 'NO_SHOW':
        return MissionStatus.cancelled;
      case 'PENDING':
      default:
        return MissionStatus.created;
    }
  }

  String toBackendStatus() {
    switch (status) {
      case MissionStatus.accepted:
      case MissionStatus.onTheWay:
      case MissionStatus.inProgress:
        return 'CONFIRMED';
      case MissionStatus.completed:
        return 'COMPLETED';
      case MissionStatus.cancelled:
        return 'CANCELLED';
      case MissionStatus.created:
        return 'PENDING';
    }
  }
}