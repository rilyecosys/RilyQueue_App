// ─────────────────────────────────────────────────────────────────────────────
//  TaskApiService — connecte le mobile au vrai backend NestJS /tasks
//
//  Remplace AppointmentService (ancienne version).
//  Toutes les méthodes retournent des objets Mission pour
//  que les écrans existants n'aient pas besoin de changer.
// ─────────────────────────────────────────────────────────────────────────────

import '../data/remote/api_client.dart';
import '../models/mission.dart';

class TaskApiService {
  static final TaskApiService _instance = TaskApiService._internal();
  factory TaskApiService() => _instance;
  TaskApiService._internal();

  final ApiClient _api = ApiClient();

  // ── Client : ses missions ──────────────────────────────────────────────────

  Future<List<Mission>> getClientMissions() async {
    final data = await _api.get('/tasks?role=client');
    final list = _asList(data);
    return list
        .map((e) => Mission.fromTaskJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Agent : missions disponibles (PAID = prêtes à être acceptées) ──────────

  Future<List<Mission>> getAvailableMissions({
    double lat = 33.5731,
    double lng = -7.5898,
  }) async {
    final data = await _api.get('/tasks?role=agent&lat=$lat&lng=$lng');
    final list = _asList(data);
    return list
        .map((e) => Mission.fromTaskJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Agent : ses missions assignées ────────────────────────────────────────

  Future<List<Mission>> getAgentMissions() async {
    final data = await _api.get('/tasks?role=agent');
    final list = _asList(data);
    return list
        .map((e) => Mission.fromTaskJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Détails d'une mission ─────────────────────────────────────────────────

  Future<Mission> getMission(String id) async {
    final data = await _api.get('/tasks/$id');
    return Mission.fromTaskJson(data);
  }

  // ── Statut d'une mission (polling) ────────────────────────────────────────

  Future<MissionStatus> getMissionStatus(String id) async {
    final data = await _api.get('/tasks/$id/status');
    final statusStr = data['status'] as String? ?? 'REQUESTED';
    return Mission.statusFromTaskBackend(statusStr);
  }

  // ── Client crée une mission ───────────────────────────────────────────────

  Future<Mission> createTask({
    required String categoryId,   // ex: 'queue', 'personal', etc.
    required String description,
    required double pickupLat,
    required double pickupLng,
    double? dropoffLat,
    double? dropoffLng,
  }) async {
    final data = await _api.post('/tasks', {
      'category': _mapCategoryToBackend(categoryId),
      'description': description,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat ?? pickupLat + 0.01,
      'dropoffLng': dropoffLng ?? pickupLng + 0.01,
    });
    return Mission.fromTaskJson(data);
  }

  // ── Agent accepte une mission ─────────────────────────────────────────────

  Future<void> acceptTask(String taskId) async {
    await _api.post('/assignments/accept', {'taskId': taskId});
  }

  // ── Changer le statut d'une mission ──────────────────────────────────────

  Future<Mission> updateStatus(String taskId, MissionStatus newStatus) async {
    final backendStatus = Mission.statusToTaskBackend(newStatus);
    final data = await _api.patch('/tasks/$taskId/status', {
      'status': backendStatus,
    });
    return Mission.fromTaskJson(data);
  }

  // ── Évaluer une mission (Rating) ──────────────────────────────────────────

  Future<void> rateMission({
    required String taskId,
    required String ratedId,
    required int score,
    String? comment,
  }) async {
    await _api.post('/ratings', {
      'taskId': taskId,
      'ratedId': ratedId,
      'score': score,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return [];
  }

  /// Mappe l'id de catégorie Flutter → enum backend
  static String _mapCategoryToBackend(String categoryId) {
    switch (categoryId) {
      case 'queue':
        return 'QUEUE';
      case 'personal':
      case 'mobility':
      case 'business':
      case 'immigration':
      case 'notary':
        return 'DEPOT';
      default:
        return 'QUEUE';
    }
  }
}
