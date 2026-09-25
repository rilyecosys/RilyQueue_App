import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/mission_service.dart';
import '../services/task_api_service.dart';
import '../models/mission.dart';
import 'theme/app_theme.dart';
import 'widgets/rily_widgets.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  final AuthService _auth = AuthService();
  final TaskApiService _taskApi = TaskApiService();
  final MissionService _ms = MissionService();

  List<Mission> _availableMissions = [];
  List<Mission> _myMissions = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final available = _loaded ? _availableMissions.length : _ms.getAvailableMissions().length;
    final myMissions = _loaded ? _myMissions : _ms.getAgentMissions(user.id);
    final inProgress = myMissions
        .where((m) =>
            m.status == MissionStatus.accepted ||
            m.status == MissionStatus.onTheWay ||
            m.status == MissionStatus.inProgress)
        .length;
    final completed = myMissions
        .where((m) => m.status == MissionStatus.completed)
        .length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: RilyColors.accent,
          child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: RilyColors.bg,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RileyQueue — Expert',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: RilyColors.accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Bonjour 🤝',
                    style: TextStyle(
                      fontSize: 13,
                      color: RilyColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_outline_rounded,
                      color: RilyColors.textSecondary),
                  onPressed: () => Navigator.pushNamed(context, '/agentProfile')
                      .then((_) => mounted ? setState(() {}) : null),
                  tooltip: 'Mon espace',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child:
                    Container(height: 1, color: RilyColors.surfaceBorder),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Stats ──
                  Row(
                    children: [
                      Expanded(
                          child: _StatCard(
                              label: 'Disponibles',
                              value: '$available',
                              color: RilyColors.info,
                              emoji: '📋')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              label: 'En traitement',
                              value: '$inProgress',
                              color: RilyColors.statusInProgress,
                              emoji: '⚡')),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _StatCard(
                              label: 'Clôturés',
                              value: '$completed',
                              color: RilyColors.success,
                              emoji: '✅')),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── CTA principal ──
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/agentMissions')
                        .then((_) => _loadData()),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [RilyColors.gradientStart, RilyColors.gradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: RilyColors.accent.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  available > 0
                                      ? '$available dossier${available > 1 ? 's' : ''} disponible${available > 1 ? 's' : ''}'
                                      : 'Mes dossiers en cours',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  available > 0
                                      ? 'Prendre en charge un dossier'
                                      : 'Gérer ma progression',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Missions en cours ──
                  if (inProgress > 0) ...[
                    const SectionHeader('DOSSIERS EN TRAITEMENT'),
                    const SizedBox(height: 14),
                    ...myMissions
                        .where((m) =>
                            m.status == MissionStatus.accepted ||
                            m.status == MissionStatus.onTheWay ||
                            m.status == MissionStatus.inProgress)
                        .map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ActiveMissionCard(
                                mission: m,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/missionDetail',
                                  arguments: m,
                                ).then((_) => _loadData()),
                              ),
                            )),
                    const SizedBox(height: 16),
                  ],

                  if (available == 0 && inProgress == 0)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - v)),
                          child: child,
                        ),
                      ),
                      child: const EmptyState(
                        emoji: '📋',
                        title: 'Aucun dossier pour le moment',
                        subtitle:
                            'De nouveaux dossiers clients arrivent régulièrement.',
                      ),
                    ),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String emoji;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return RilyCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: RilyColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveMissionCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback onTap;
  const _ActiveMissionCard({required this.mission, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RilyCard(
      onTap: onTap,
      borderColor: mission.status.color.withValues(alpha: 0.25),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: mission.status.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child:
                  Text(mission.status.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.category,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: RilyColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mission.address,
                  style: const TextStyle(
                      fontSize: 13, color: RilyColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: RilyColors.textMuted),
        ],
      ),
    );
  }
}