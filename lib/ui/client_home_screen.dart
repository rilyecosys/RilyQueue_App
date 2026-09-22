import 'package:flutter/material.dart';
import '../models/mission.dart';
import '../models/service_category.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/task_api_service.dart';
import '../services/mission_service.dart';
import '../services/connectivity_service.dart';
import 'theme/app_theme.dart';
import 'widgets/rily_widgets.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final AuthService _auth = AuthService();
  final TaskApiService _taskApi = TaskApiService();
  final MissionService _ms = MissionService(); // fallback local
  final ConnectivityService _conn = ConnectivityService();
  bool _isOffline = false;
  List<Mission> _apiMissions = [];
  bool _apiLoaded = false;
  bool _apiError = false;

  @override
  void initState() {
    super.initState();
    _conn.onConnectivityChanged
        .listen((c) => mounted ? setState(() => _isOffline = !c) : null);
    _isOffline = !_conn.isConnected;
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    try {
      final missions = await _taskApi.getClientMissions();
      if (mounted) {
        setState(() {
          _apiMissions = missions;
          _apiLoaded = true;
          _apiError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _apiLoaded = true; _apiError = true; });
    }
  }

  void _openNewDossier({ServiceCategory? category}) async {
    await Navigator.pushNamed(context, '/createMission', arguments: category);
    if (mounted) _loadMissions(); // refresh depuis l'API après création
  }

  void _openDossier(Mission m) {
    Navigator.pushNamed(context, '/missionStatus', arguments: m)
        .then((_) => mounted ? _loadMissions() : null);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => Navigator.pushNamedAndRemoveUntil(
              context, '/login', (r) => false));
      return const Scaffold(body: SizedBox.shrink());
    }
    if (user.role != UserRole.client) {
      return const Scaffold(
          body: Center(child: Text('Accès réservé aux clients.')));
    }

    // Utilise les missions de l'API si dispo, sinon fallback local
    final missions = _apiLoaded && !_apiError
        ? _apiMissions
        : _ms.getClientMissions(user.id);

    final active = missions
        .where((m) =>
            m.status != MissionStatus.completed &&
            m.status != MissionStatus.cancelled)
        .toList();
    final past = missions
        .where((m) =>
            m.status == MissionStatus.completed ||
            m.status == MissionStatus.cancelled)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          ConnectivityBanner(
              isOffline: _isOffline, onRetry: () => setState(() {})),
          Expanded(
            child: RefreshIndicator(
              color: RilyColors.accent,
              onRefresh: () => _loadMissions(),
              child: CustomScrollView(
                slivers: [
                  // ── App Bar ────────────────────────────────────────────────
                  SliverAppBar(
                    floating: true,
                    backgroundColor: RilyColors.bg,
                    title: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: RilyColors.accentDim,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'R',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: RilyColors.accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'RileyQueue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: RilyColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.person_outline_rounded,
                            color: RilyColors.textSecondary),
                        onPressed: () => Navigator.pushNamed(context, '/profile'),
                        tooltip: 'Mon compte',
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child:
                          Container(height: 1, color: RilyColors.surfaceBorder),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero ──────────────────────────────────────────
                        _HeroSection(
                            onNewDossier: () => _openNewDossier()),

                        // ── Trust strip ───────────────────────────────────
                        const _TrustStrip(),

                        // ── Services ──────────────────────────────────────
                        const SizedBox(height: 28),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _ServicesSection(
                            onCategoryTap: (cat) =>
                                _openNewDossier(category: cat),
                          ),
                        ),

                        // ── Active dossiers ───────────────────────────────
                        if (active.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: _DossiersSection(
                              title: 'DOSSIERS EN COURS',
                              missions: active,
                              onTap: _openDossier,
                            ),
                          ),
                        ],

                        // ── History ───────────────────────────────────────
                        if (past.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: _DossiersSection(
                              title: 'HISTORIQUE',
                              missions: past,
                              onTap: _openDossier,
                              muted: true,
                            ),
                          ),
                        ],

                        // ── Empty state ───────────────────────────────────
                        if (active.isEmpty && past.isEmpty)
                          _EmptyDossiers(
                              onTap: () => _openNewDossier()),

                        const SizedBox(height: 48),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
//  Hero section
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final VoidCallback onNewDossier;
  const _HeroSection({required this.onNewDossier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: RilyColors.accentDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: RilyColors.accent.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'Votre concierge administratif',
              style: TextStyle(
                fontSize: 12,
                color: RilyColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Headline
          const Text(
            'Déléguez vos\ndémarches\nadministratives.',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: RilyColors.textPrimary,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          // Subline
          const Text(
            'Des experts certifiés prennent en charge\nvos formalités de A à Z. Confidentiellement.',
            style: TextStyle(
              fontSize: 15,
              color: RilyColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          // CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: RilyColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onNewDossier,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Soumettre un dossier',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Trust strip
// ─────────────────────────────────────────────────────────────────────────────

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: RilyColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: RilyColors.surfaceBorder),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: const [
            _TrustItem(
                icon: Icons.verified_user_outlined,
                label: 'Experts vérifiés'),
            SizedBox(width: 24),
            _TrustItem(
                icon: Icons.lock_outline_rounded,
                label: 'Documents sécurisés'),
            SizedBox(width: 24),
            _TrustItem(
                icon: Icons.track_changes_rounded,
                label: 'Suivi en temps réel'),
            SizedBox(width: 24),
            _TrustItem(
                icon: Icons.shield_outlined,
                label: 'Confidentialité garantie'),
          ],
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: RilyColors.accent),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: RilyColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Services grid
// ─────────────────────────────────────────────────────────────────────────────

class _ServicesSection extends StatelessWidget {
  final void Function(ServiceCategory) onCategoryTap;
  const _ServicesSection({required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('NOS SERVICES'),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: kServiceCategories
              .map((cat) => _ServiceCard(
                    category: cat,
                    onTap: () => onCategoryTap(cat),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;
  const _ServiceCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RilyColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RilyColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: category.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child:
                    Text(category.emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const Spacer(),
            Text(
              category.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: RilyColors.textPrimary,
                height: 1.3,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 3),
            Text(
              category.subtitle,
              style: const TextStyle(fontSize: 10, color: RilyColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dossiers section
// ─────────────────────────────────────────────────────────────────────────────

class _DossiersSection extends StatelessWidget {
  final String title;
  final List<Mission> missions;
  final void Function(Mission) onTap;
  final bool muted;

  const _DossiersSection({
    required this.title,
    required this.missions,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        const SizedBox(height: 14),
        ...missions.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  _DossierCard(mission: m, onTap: () => onTap(m), muted: muted),
            )),
      ],
    );
  }
}

class _DossierCard extends StatelessWidget {
  final Mission mission;
  final VoidCallback onTap;
  final bool muted;
  const _DossierCard(
      {required this.mission, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final emoji = kCategoryEmojis[mission.category] ?? '📋';
    return RilyCard(
      onTap: onTap,
      borderColor:
          muted ? null : mission.status.color.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: mission.status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child:
                        Text(emoji, style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.category,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: muted
                            ? RilyColors.textSecondary
                            : RilyColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mission.address,
                      style: const TextStyle(
                          fontSize: 12, color: RilyColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(mission.status, small: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 13, color: RilyColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  mission.timeSlot,
                  style:
                      const TextStyle(fontSize: 12, color: RilyColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (mission.isExpress) ...[
                const SizedBox(width: 8),
                const ExpressBadge(),
                const SizedBox(width: 8),
              ],
              Text(
                '${mission.totalPrice.toStringAsFixed(0)} MAD',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: RilyColors.accent,
                ),
              ),
            ],
          ),
          if (mission.status == MissionStatus.completed &&
              mission.ratingScore != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < mission.ratingScore!
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: RilyColors.warning,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${mission.ratingScore}/5',
                  style: const TextStyle(
                      fontSize: 11, color: RilyColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyDossiers extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyDossiers({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: RilyColors.accentDim,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
                child: Text('📋', style: TextStyle(fontSize: 30))),
          ),
          const SizedBox(height: 18),
          const Text(
            'Aucun dossier en cours',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: RilyColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Soumettez votre première demande.\nUn expert prend en charge vos formalités.',
            style: TextStyle(
                fontSize: 14,
                color: RilyColors.textSecondary,
                height: 1.55),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 200,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: RilyColors.accent,
                side: const BorderSide(color: RilyColors.accent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTap,
              child: const Text('Première demande'),
            ),
          ),
        ],
      ),
    );
  }
}
