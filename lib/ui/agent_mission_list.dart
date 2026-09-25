import 'package:flutter/material.dart';
import '../models/mission.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/mission_service.dart';
import '../services/task_api_service.dart';
import '../services/connectivity_service.dart';
import 'theme/app_theme.dart';
import 'widgets/rily_widgets.dart';

class AgentMissionList extends StatefulWidget {
  const AgentMissionList({super.key});

  @override
  State<AgentMissionList> createState() => _AgentMissionListState();
}

class _AgentMissionListState extends State<AgentMissionList>
    with SingleTickerProviderStateMixin {
  final MissionService _ms = MissionService();
  final TaskApiService _taskApi = TaskApiService();
  final AuthService _auth = AuthService();
  final ConnectivityService _conn = ConnectivityService();

  late TabController _tabCtrl;
  bool _isOffline = false;
  String? _acceptingId;

  List<Mission> _availableMissions = [];
  List<Mission> _myMissions = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _isOffline = !_conn.isConnected;
    _conn.onConnectivityChanged.listen((c) {
      if (mounted) setState(() => _isOffline = !c);
    });
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    try {
      final available = await _taskApi.getAvailableMissions();
      final my = await _taskApi.getAgentMissions();
      if (mounted) {
        setState(() {
          _availableMissions = available;
          _myMissions = my;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        final user = _auth.currentUser;
        setState(() {
          _availableMissions = _ms.getAvailableMissions();
          _myMissions = user != null ? _ms.getAgentMissions(user.id) : [];
          _loaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept(String missionId) async {
    if (_acceptingId != null) return;
    setState(() => _acceptingId = missionId);
    try {
      await _taskApi.acceptTask(missionId);
      await _loadMissions();
      if (!mounted) return;
      showSuccessSnack(context, 'Mission acceptée !');
      // Switcher sur l'onglet "Mes missions"
      _tabCtrl.animateTo(1);
    } catch (e) {
      try {
        await _ms.acceptMission(missionId);
        await _loadMissions();
        if (!mounted) return;
        showSuccessSnack(context, 'Mission acceptée !');
        _tabCtrl.animateTo(1);
      } catch (err) {
        if (!mounted) return;
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  void _goDetail(Mission m) {
    Navigator.pushNamed(context, '/missionDetail', arguments: m)
        .then((_) => _loadMissions());
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    if (user.role != UserRole.agent) {
      return const Scaffold(
        body: Center(child: Text('Accès réservé aux agents.')),
      );
    }

    final available = _loaded ? _availableMissions : _ms.getAvailableMissions();
    final myMissions = _loaded ? _myMissions : _ms.getAgentMissions(user.id);

    return Scaffold(
      body: Column(
        children: [
          ConnectivityBanner(
            isOffline: _isOffline,
            onRetry: _loadMissions,
          ),
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  floating: true,
                  backgroundColor: RilyColors.bg,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text('Dossiers'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: RilyColors.textSecondary),
                      onPressed: _loadMissions,
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabCtrl,
                    indicatorColor: RilyColors.accent,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelColor: RilyColors.accent,
                    unselectedLabelColor: RilyColors.textSecondary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: [
                      Tab(
                        text:
                            'À prendre en charge${available.isNotEmpty ? ' (${available.length})' : ''}',
                      ),
                      Tab(
                        text:
                            'Mes dossiers${myMissions.isNotEmpty ? ' (${myMissions.length})' : ''}',
                      ),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab 1 : disponibles ──
                  RefreshIndicator(
                    color: RilyColors.accent,
                    onRefresh: _loadMissions,
                    child: available.isEmpty
                        ? const EmptyState(
                            emoji: '🔍',
                            title: 'Aucun dossier disponible',
                            subtitle:
                                'De nouveaux dossiers clients apparaîtront ici dès leur soumission.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: available.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AgentMissionCard(
                                mission: available[i],
                                isAccepting:
                                    _acceptingId == available[i].id,
                                onAccept: () => _accept(available[i].id),
                                onDetail: () => _goDetail(available[i]),
                                showAcceptButton: true,
                              ),
                            ),
                          ),
                  ),

                  // ── Tab 2 : mes missions ──
                  RefreshIndicator(
                    color: RilyColors.accent,
                    onRefresh: _loadMissions,
                    child: myMissions.isEmpty
                        ? const EmptyState(
                            emoji: '📋',
                            title: 'Aucun dossier en cours',
                            subtitle:
                                'Acceptez un dossier dans l\'onglet de gauche.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: myMissions.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AgentMissionCard(
                                mission: myMissions[i],
                                isAccepting: false,
                                onAccept: () {},
                                onDetail: () => _goDetail(myMissions[i]),
                                showAcceptButton: false,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte agent ─────────────────────────────────────────────────────────────

class AgentMissionCard extends StatelessWidget {
  final Mission mission;
  final bool isAccepting;
  final VoidCallback onAccept;
  final VoidCallback onDetail;
  final bool showAcceptButton;

  const AgentMissionCard({
    super.key,
    required this.mission,
    required this.isAccepting,
    required this.onAccept,
    required this.onDetail,
    required this.showAcceptButton,
  });

  @override
  Widget build(BuildContext context) {
    return RilyCard(
      onTap: onDetail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre + badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  mission.category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: RilyColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (mission.isExpress) ...[
                const ExpressBadge(),
                const SizedBox(width: 6),
              ],
              StatusBadge(mission.status, small: true),
            ],
          ),

          const SizedBox(height: 12),

          // Adresse
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: RilyColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mission.address,
                  style: const TextStyle(
                      fontSize: 13, color: RilyColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Créneau + prix
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: RilyColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mission.timeSlot,
                  style: const TextStyle(
                      fontSize: 13, color: RilyColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${mission.totalPrice.toStringAsFixed(0)} MAD',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: RilyColors.accent,
                ),
              ),
            ],
          ),

          if (mission.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              mission.note,
              style: const TextStyle(
                  fontSize: 12, color: RilyColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 14),

          // Boutons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onDetail,
                    child: const Text('Détail'),
                  ),
                ),
              ),
              if (showAcceptButton) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: isAccepting ? null : onAccept,
                      child: isAccepting
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Text('Accepter'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}