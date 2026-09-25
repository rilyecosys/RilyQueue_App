import 'package:flutter/material.dart';
import '../models/mission.dart';
import '../services/mission_service.dart';
import '../services/task_api_service.dart';
import '../services/connectivity_service.dart';
import 'theme/app_theme.dart';
import 'widgets/rily_widgets.dart';


class MissionStatusScreen extends StatefulWidget {
  final Mission mission;
  const MissionStatusScreen({super.key, required this.mission});

  @override
  State<MissionStatusScreen> createState() => _MissionStatusScreenState();
}

class _MissionStatusScreenState extends State<MissionStatusScreen> {
  final MissionService _ms = MissionService();
  final TaskApiService _taskApi = TaskApiService();
  final ConnectivityService _conn = ConnectivityService();

  bool _isOffline = false;
  bool _isCancelling = false;
  bool _isRating = false;
  int _ratingScore = 0;
  final _ratingCommentCtrl = TextEditingController();

  static const _timeline = [
    MissionStatus.created,
    MissionStatus.accepted,
    MissionStatus.onTheWay,
    MissionStatus.inProgress,
    MissionStatus.completed,
  ];

  static const _timelineLabels = {
    MissionStatus.created: 'Demande reçue',
    MissionStatus.accepted: 'Expert assigné',
    MissionStatus.onTheWay: 'Expert en déplacement',
    MissionStatus.inProgress: 'Démarche en cours',
    MissionStatus.completed: 'Dossier clôturé',
  };

  @override
  void initState() {
    super.initState();
    _isOffline = !_conn.isConnected;
    _conn.onConnectivityChanged.listen((c) {
      if (mounted) setState(() => _isOffline = !c);
    });
  }

  @override
  void dispose() {
    _ratingCommentCtrl.dispose();
    super.dispose();
  }

  Mission get _m =>
      _ms.missions.firstWhere((m) => m.id == widget.mission.id,
          orElse: () => widget.mission);

  int _currentIndex(Mission m) => m.status == MissionStatus.cancelled
      ? -1
      : _timeline.indexOf(m.status);

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Annuler le dossier',
        body: 'Cette action est irréversible.',
        confirmLabel: 'Oui, annuler',
        isDanger: true,
      ),
    );
    if (ok != true) return;

    setState(() => _isCancelling = true);
    try {
      await _ms.cancelMission(_m.id);
      if (!mounted) return;
      setState(() {});
      showSuccessSnack(context, 'Mission annulée.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _submitRating() async {
    if (_ratingScore == 0) {
      showErrorSnack(context, 'Sélectionne une note entre 1 et 5.');
      return;
    }
    setState(() => _isRating = true);
    try {
      final comment = _ratingCommentCtrl.text.trim().isEmpty
          ? null
          : _ratingCommentCtrl.text.trim();

      if (_m.agentId != null && _m.agentId!.isNotEmpty) {
        await _taskApi
            .rateMission(
              taskId: _m.id,
              ratedId: _m.agentId!,
              score: _ratingScore,
              comment: comment,
            )
            .catchError((_) {});
      }
      await _ms.rateMission(
        missionId: _m.id,
        score: _ratingScore,
        comment: comment,
      );
      if (!mounted) return;
      setState(() {});
      showSuccessSnack(context, 'Merci pour votre avis !');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isRating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final idx = _currentIndex(m);
    final isCancelled = m.status == MissionStatus.cancelled;
    final canCancel = _ms.canCancel(m);
    final canRate = _ms.canRate(m.id);
    final alreadyRated = m.ratingScore != null;

    return Scaffold(
      body: Column(
        children: [
          ConnectivityBanner(
              isOffline: _isOffline, onRetry: () => setState(() {})),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: RilyColors.bg,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text('Suivi du dossier'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: RilyColors.textSecondary),
                      onPressed: () => setState(() {}),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Infos mission ──
                      _MissionInfoCard(mission: m),

                      const SizedBox(height: 24),

                      // ── Annulée ──
                      if (isCancelled)
                        AlertBanner(
                          type: AlertType.error,
                          message: 'Cette mission a été annulée.',
                        ),

                      // ── Timeline ──
                      if (!isCancelled) ...[
                        const SectionHeader('AVANCEMENT DU DOSSIER'),
                        const SizedBox(height: 16),
                        _TimelineWidget(
                            timeline: _timeline,
                            labels: _timelineLabels,
                            currentIndex: idx),
                      ],

                      const SizedBox(height: 24),

                      // ── Preuve ──
                      if (m.proof != null) ...[
                        const SectionHeader("RAPPORT D'EXÉCUTION"),
                        const SizedBox(height: 14),
                        RilyCard(
                          borderColor:
                              RilyColors.success.withValues(alpha: 0.25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.verified_rounded,
                                      color: RilyColors.success, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    "Rapport d'exécution validé",
                                    style: TextStyle(
                                      color: RilyColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                m.proof!.comment ?? 'Aucun commentaire',
                                style: const TextStyle(
                                    color: RilyColors.textSecondary,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Rating à soumettre ──
                      if (canRate) ...[
                        const SectionHeader('ÉVALUER LA MISSION'),
                        const SizedBox(height: 16),
                        RilyCard(
                          child: Column(
                            children: [
                              const Text(
                                'Comment évaluez-vous cette prestation ?',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: RilyColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              StarRating(
                                selected: _ratingScore,
                                onSelect: (s) =>
                                    setState(() => _ratingScore = s),
                                size: 42,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _ratingScore == 0
                                    ? 'Tape une étoile'
                                    : _ratingLabel(_ratingScore),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _ratingScore == 0
                                      ? RilyColors.textMuted
                                      : RilyColors.warning,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              RilyTextField(
                                controller: _ratingCommentCtrl,
                                label: 'Commentaire (optionnel)',
                                hint:
                                    'Dis-nous ce que tu as pensé...',
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              RilyButton(
                                label: 'Envoyer mon avis',
                                loadingLabel: 'Envoi...',
                                isLoading: _isRating,
                                icon: Icons.send_rounded,
                                onPressed: _submitRating,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Rating déjà soumis ──
                      if (alreadyRated) ...[
                        const SectionHeader('TON ÉVALUATION'),
                        const SizedBox(height: 14),
                        RilyCard(
                          borderColor:
                              RilyColors.success.withValues(alpha: 0.25),
                          child: Row(
                            children: [
                              Column(
                                children: [
                                  StarRating(
                                    selected: m.ratingScore!,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${m.ratingScore}/5',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: RilyColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              if (m.ratingComment != null &&
                                  m.ratingComment!.isNotEmpty) ...[
                                const SizedBox(width: 16),
                                const VerticalDivider(width: 1),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    '"${m.ratingComment}"',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: RilyColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Annulation ──
                      if (canCancel) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: RilyColors.error,
                              side: BorderSide(
                                  color:
                                      RilyColors.error.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            onPressed:
                                _isCancelling ? null : _cancel,
                            icon: _isCancelling
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: RilyColors.error),
                                  )
                                : const Icon(Icons.cancel_outlined,
                                    size: 18),
                            label: Text(_isCancelling
                                ? 'Annulation...'
                                : 'Annuler le dossier'),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int score) {
    switch (score) {
      case 1:
        return 'Très décevant';
      case 2:
        return 'Peut mieux faire';
      case 3:
        return 'Correct';
      case 4:
        return 'Bien';
      case 5:
        return 'Excellent !';
      default:
        return '';
    }
  }
}

// ─── Info card mission ───────────────────────────────────────────────────────

class _MissionInfoCard extends StatelessWidget {
  final Mission mission;
  const _MissionInfoCard({required this.mission});

  @override
  Widget build(BuildContext context) {
    return RilyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  mission.category,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: RilyColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (mission.isExpress) ...[
                const ExpressBadge(),
                const SizedBox(width: 8),
              ],
              StatusBadge(mission.status),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.location_on_rounded, text: mission.address),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.schedule_rounded, text: mission.timeSlot),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.payments_rounded,
            text: '${mission.totalPrice.toStringAsFixed(0)} MAD',
            highlight: true,
          ),
          if (mission.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.notes_rounded, text: mission.note),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  const _InfoRow(
      {required this.icon, required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 16,
            color:
                highlight ? RilyColors.accent : RilyColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: highlight
                  ? RilyColors.accent
                  : RilyColors.textSecondary,
              fontWeight:
                  highlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Timeline widget ─────────────────────────────────────────────────────────

class _TimelineWidget extends StatelessWidget {
  final List<MissionStatus> timeline;
  final Map<MissionStatus, String> labels;
  final int currentIndex;

  const _TimelineWidget({
    required this.timeline,
    required this.labels,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(timeline.length, (i) {
        final status = timeline[i];
        final isDone = i <= currentIndex;
        final isCurrent = i == currentIndex;
        final isLast = i == timeline.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne + point
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? status.color
                          : RilyColors.surfaceElevated,
                      border: Border.all(
                        color: isDone
                            ? status.color
                            : RilyColors.surfaceBorder,
                        width: 2,
                      ),
                    ),
                    child: isDone
                        ? Icon(
                            isCurrent && !isLast
                                ? Icons.circle
                                : Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 32,
                      color: i < currentIndex
                          ? status.color.withValues(alpha: 0.4)
                          : RilyColors.surfaceBorder,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Label
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      labels[status] ?? status.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isDone
                            ? RilyColors.textPrimary
                            : RilyColors.textMuted,
                      ),
                    ),
                    if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Statut actuel',
                          style: TextStyle(
                            fontSize: 12,
                            color: status.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (isCurrent) ...[
              const SizedBox(width: 8),
              StatusBadge(status, small: true),
            ],
          ],
        );
      }),
    );
  }
}

// ─── Dialog confirmation ─────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final bool isDanger;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RilyColors.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              color: RilyColors.textPrimary,
              fontWeight: FontWeight.w700)),
      content: Text(body,
          style: const TextStyle(color: RilyColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler',
              style: TextStyle(color: RilyColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDanger ? RilyColors.error : RilyColors.accent,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}