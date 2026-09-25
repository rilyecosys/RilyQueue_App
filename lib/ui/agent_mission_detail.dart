import 'package:flutter/material.dart';
import '../models/mission.dart';
import '../services/mission_service.dart';
import '../services/task_api_service.dart';
import '../services/proof_upload_service.dart';
import '../services/connectivity_service.dart';
import 'theme/app_theme.dart';
import 'widgets/rily_widgets.dart';

class AgentMissionDetail extends StatefulWidget {
  final Mission mission;
  const AgentMissionDetail({super.key, required this.mission});

  @override
  State<AgentMissionDetail> createState() => _AgentMissionDetailState();
}

class _AgentMissionDetailState extends State<AgentMissionDetail> {
  final MissionService _ms = MissionService();
  final TaskApiService _taskApi = TaskApiService();
  final ConnectivityService _conn = ConnectivityService();
  final ProofUploadService _uploader = ProofUploadService();
  final TextEditingController _proofCtrl = TextEditingController();

  late Mission _currentMission;
  bool _isOffline = false;
  bool _isUpdating = false;
  bool _isCancelling = false;
  ProofUploadStatus _proofStatus = ProofUploadStatus.idle;
  String? _pickedImageName;

  bool get _anyBusy =>
      _isUpdating || _isCancelling ||
      _proofStatus == ProofUploadStatus.compressing ||
      _proofStatus == ProofUploadStatus.uploading;

  @override
  void initState() {
    super.initState();
    _currentMission = widget.mission;
    _isOffline = !_conn.isConnected;
    _conn.onConnectivityChanged
        .listen((c) => mounted ? setState(() => _isOffline = !c) : null);
    _uploader.onStatusChanged = (s) {
      if (mounted) setState(() => _proofStatus = s);
    };
  }

  @override
  void dispose() {
    _proofCtrl.dispose();
    super.dispose();
  }

  Mission get _m => _currentMission;

  // ─── Progression ─────────────────────────────────────────────────────────

  Future<void> _updateStatus(MissionStatus s, String msg) async {
    if (_anyBusy) return;
    setState(() => _isUpdating = true);
    try {
      final updated = await _taskApi.updateStatus(_currentMission.id, s);
      if (mounted) {
        setState(() {
          _currentMission = updated;
        });
        showSuccessSnack(context, msg);
      }
    } catch (e) {
      try {
        await _ms.updateMissionStatus(_currentMission.id, s);
        if (mounted) {
          setState(() {
            _currentMission = _ms.missions.firstWhere(
              (m) => m.id == widget.mission.id,
              orElse: () => _currentMission.copyWith(status: s),
            );
          });
          showSuccessSnack(context, msg);
        }
      } catch (err) {
        if (!mounted) return;
        showErrorSnack(context, e);
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  // ─── Upload preuve (robust) ───────────────────────────────────────────────

  Future<void> _pickImageSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: RilyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: RilyColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ajouter une photo',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: RilyColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _PhotoSourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Prendre une photo',
                onTap: () => Navigator.pop(ctx, 'camera_photo.jpg'),
              ),
              const SizedBox(height: 10),
              _PhotoSourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choisir depuis la galerie',
                onTap: () => Navigator.pop(ctx, 'galerie_photo.jpg'),
              ),
              const SizedBox(height: 10),
              if (true) // always shown for cancel
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler',
                      style: TextStyle(color: RilyColors.textSecondary)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _pickedImageName = picked);
    }
  }

  Future<void> _uploadProof() async {
    final comment = _proofCtrl.text.trim();
    if (_pickedImageName == null) {
      showErrorSnack(context, 'Sélectionne d\'abord une photo.');
      return;
    }
    if (comment.isEmpty) {
      showErrorSnack(context, 'Saisis un commentaire de rapport.');
      return;
    }
    if (_anyBusy) return;

    _uploader.reset();

    final result = await _uploader.upload(
      localPath: _pickedImageName!,
    );

    if (!mounted) return;

    if (result.status == ProofUploadStatus.done) {
      try {
        await _ms.addProof(
          missionId: _m.id,
          imagePath: result.imagePath,
          comment: comment,
        );
        if (!mounted) return;
        _proofCtrl.clear();
        setState(() {});
        showSuccessSnack(context, "Rapport d'exécution soumis ✓");
      } catch (e) {
        if (!mounted) return;
        showErrorSnack(context, e);
      }
    } else {
      showErrorSnack(
          context, result.errorMessage ?? 'Échec de l\'upload. Réessaie.');
    }
  }

  // ─── Annulation ──────────────────────────────────────────────────────────

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Annuler la mission',
        body: 'Confirmes-tu l\'annulation de cette mission ?',
        confirmLabel: 'Oui, annuler',
        isDanger: true,
      ),
    );
    if (ok != true || !mounted) return;
    if (_anyBusy) return;

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

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final isCancelled = m.status == MissionStatus.cancelled;
    final isCompleted = m.status == MissionStatus.completed;
    final canAddProof = m.status == MissionStatus.inProgress && m.proof == null;
    final canCancel = _ms.canCancel(m);
    final isUploading = _proofStatus == ProofUploadStatus.compressing ||
        _proofStatus == ProofUploadStatus.uploading;
    final uploadFailed = _proofStatus == ProofUploadStatus.error;

    return Scaffold(
      body: Column(
        children: [
          ConnectivityBanner(
            isOffline: _isOffline,
            onRetry: () => setState(() {}),
          ),
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
                  title: const Text('Dossier client'),
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Info card ──
                      _MissionInfoCard(mission: m),

                      const SizedBox(height: 24),

                      // ── Annulée ──
                      if (isCancelled) ...[
                        AlertBanner(
                            type: AlertType.error,
                            message:
                                'Mission annulée. Aucune action disponible.'),
                        const SizedBox(height: 24),
                      ],

                      // ── Terminée ──
                      if (isCompleted) ...[
                        AlertBanner(
                            type: AlertType.success,
                            message: 'Mission terminée avec succès.'),
                        const SizedBox(height: 24),
                      ],

                      // ── Progression ──
                      if (!isCancelled && !isCompleted) ...[
                        const SectionHeader('PROGRESSION DU DOSSIER'),
                        const SizedBox(height: 16),

                        _ProgressionCard(
                          mission: m,
                          isLoading: _isUpdating,
                          onEnRoute: () => _updateStatus(
                              MissionStatus.onTheWay, 'Prise en charge confirmée ✔️'),
                          onDemarrer: () => _updateStatus(
                              MissionStatus.inProgress, 'Démarche lancée ⚙️'),
                          onTerminer: () => _updateStatus(
                              MissionStatus.completed, 'Dossier clôturé avec succès ✅'),
                        ),

                        const SizedBox(height: 24),
                      ],

                      // ── Preuve ──
                      if (!isCancelled && !isCompleted) ...[
                        const SectionHeader("RAPPORT D'EXÉCUTION"),
                        const SizedBox(height: 14),

                        if (m.proof == null)
                          _ProofUploadCard(
                            controller: _proofCtrl,
                            isEnabled: canAddProof && !_anyBusy,
                            isUploading: isUploading,
                            uploadFailed: uploadFailed,
                            uploadStatus: _proofStatus,
                            pickedImageName: _pickedImageName,
                            onPickImage: canAddProof && !_anyBusy
                                ? _pickImageSheet
                                : null,
                            onUpload: canAddProof ? _uploadProof : null,
                            hint: !canAddProof
                                ? 'Disponible quand la mission est en cours'
                                : null,
                          )
                        else
                          _ProofDoneCard(proof: m.proof!),

                        const SizedBox(height: 24),
                      ],

                      // ── Preuve visible si complété ──
                      if ((isCompleted || isCancelled) &&
                          m.proof != null) ...[
                        const SectionHeader('RAPPORT SOUMIS'),
                        const SizedBox(height: 14),
                        _ProofDoneCard(proof: m.proof!),
                        const SizedBox(height: 24),
                      ],

                      // ── Rating reçu ──
                      if (m.ratingScore != null) ...[
                        const SectionHeader('ÉVALUATION CLIENT'),
                        const SizedBox(height: 14),
                        RilyCard(
                          borderColor:
                              RilyColors.warning.withValues(alpha: 0.25),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  StarRating(
                                      selected: m.ratingScore!,
                                      size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${m.ratingScore}/5',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: RilyColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              if (m.ratingComment?.isNotEmpty == true) ...[
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

                      // ── Bouton annulation ──
                      if (canCancel) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: RilyColors.error,
                              side: BorderSide(
                                  color:
                                      RilyColors.error.withValues(alpha: 0.35)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            onPressed: _anyBusy ? null : _cancel,
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
                                : 'Annuler la mission'),
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
}

// ─── Info card ───────────────────────────────────────────────────────────────

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
          _Row(icon: Icons.location_on_rounded, text: mission.address),
          const SizedBox(height: 8),
          _Row(icon: Icons.schedule_rounded, text: mission.timeSlot),
          const SizedBox(height: 8),
          _Row(
              icon: Icons.payments_rounded,
              text: '${mission.totalPrice.toStringAsFixed(0)} MAD',
              accent: true),
          if (mission.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _Row(icon: Icons.notes_rounded, text: mission.note),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool accent;
  const _Row({required this.icon, required this.text, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 15,
            color: accent ? RilyColors.accent : RilyColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: accent ? RilyColors.accent : RilyColors.textSecondary,
              fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Progression card ────────────────────────────────────────────────────────

class _ProgressionCard extends StatelessWidget {
  final Mission mission;
  final bool isLoading;
  final VoidCallback onEnRoute;
  final VoidCallback onDemarrer;
  final VoidCallback onTerminer;

  const _ProgressionCard({
    required this.mission,
    required this.isLoading,
    required this.onEnRoute,
    required this.onDemarrer,
    required this.onTerminer,
  });

  @override
  Widget build(BuildContext context) {
    final s = mission.status;
    final needsProof =
        s == MissionStatus.inProgress && mission.proof == null;

    return RilyCard(
      child: Column(
        children: [
          _StepButton(
            label: '📍  Prise en charge',
            sublabel: 'Confirme la prise en charge du dossier',
            isActive: s == MissionStatus.accepted,
            isDone: s.index > MissionStatus.accepted.index,
            isLoading: isLoading && s == MissionStatus.accepted,
            onTap: s == MissionStatus.accepted ? onEnRoute : null,
          ),
          const SizedBox(height: 8),
          _StepButton(
            label: '⚙️  Lancer la démarche',
            sublabel: 'Tu es sur place, la démarche commence',
            isActive: s == MissionStatus.onTheWay,
            isDone: s.index > MissionStatus.onTheWay.index,
            isLoading: isLoading && s == MissionStatus.onTheWay,
            onTap: s == MissionStatus.onTheWay ? onDemarrer : null,
          ),
          const SizedBox(height: 8),
          _StepButton(
            label: '✔️  Clôturer le dossier',
            sublabel: needsProof
                ? 'Soumettre le rapport d\'exécution d\'abord'
                : 'Valider et clôturer le dossier',
            isActive: s == MissionStatus.inProgress && !needsProof,
            isDone: false,
            isLoading: isLoading && s == MissionStatus.inProgress,
            onTap: (s == MissionStatus.inProgress && !needsProof)
                ? onTerminer
                : null,
            disabled: needsProof,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isActive;
  final bool isDone;
  final bool isLoading;
  final bool disabled;
  final VoidCallback? onTap;

  const _StepButton({
    required this.label,
    required this.sublabel,
    required this.isActive,
    required this.isDone,
    required this.isLoading,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    if (isDone) {
      bg = RilyColors.success.withValues(alpha: 0.08);
      fg = RilyColors.success;
      border = RilyColors.success.withValues(alpha: 0.2);
    } else if (isActive) {
      bg = RilyColors.accentDim;
      fg = RilyColors.accent;
      border = RilyColors.accent.withValues(alpha: 0.4);
    } else {
      bg = RilyColors.surfaceElevated;
      fg = disabled ? RilyColors.error : RilyColors.textMuted;
      border = disabled
          ? RilyColors.error.withValues(alpha: 0.2)
          : RilyColors.surfaceBorder;
    }

    return GestureDetector(
      onTap: (!isLoading && isActive) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            // Indicateur état
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? RilyColors.success
                    : isActive
                        ? RilyColors.accent
                        : RilyColors.surfaceBorder,
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                    )
                  : Icon(
                      isDone ? Icons.check_rounded : Icons.circle,
                      size: isDone ? 16 : 8,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDone || isActive
                          ? fg
                          : RilyColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: disabled
                          ? RilyColors.error
                          : RilyColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive && !isLoading)
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: RilyColors.accent),
          ],
        ),
      ),
    );
  }
}

// ─── Proof upload card ───────────────────────────────────────────────────────

class _ProofUploadCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isEnabled;
  final bool isUploading;
  final bool uploadFailed;
  final ProofUploadStatus uploadStatus;
  final String? pickedImageName;
  final VoidCallback? onPickImage;
  final VoidCallback? onUpload;
  final String? hint;

  const _ProofUploadCard({
    required this.controller,
    required this.isEnabled,
    required this.isUploading,
    required this.uploadFailed,
    required this.uploadStatus,
    this.pickedImageName,
    this.onPickImage,
    this.onUpload,
    this.hint,
  });

  String get _buttonLabel {
    if (isUploading) {
      return uploadStatus == ProofUploadStatus.compressing
          ? 'Compression...'
          : 'Upload en cours...';
    }
    if (uploadFailed) return "Réessayer l'envoi";
    return 'Soumettre le rapport';
  }

  @override
  Widget build(BuildContext context) {
    return RilyCard(
      borderColor: uploadFailed
          ? RilyColors.error.withValues(alpha: 0.25)
          : RilyColors.surfaceBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AlertBanner(type: AlertType.info, message: hint!),
            ),

          // ── Photo picker area ──────────────────────────────────────
          GestureDetector(
            onTap: isEnabled && !isUploading ? onPickImage : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 90,
              decoration: BoxDecoration(
                color: pickedImageName != null
                    ? RilyColors.accent.withValues(alpha: 0.07)
                    : RilyColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: pickedImageName != null
                      ? RilyColors.accent.withValues(alpha: 0.4)
                      : RilyColors.surfaceBorder,
                  width: pickedImageName != null ? 1.5 : 1,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: pickedImageName != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: RilyColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.image_rounded,
                              color: RilyColors.accent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pickedImageName!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: RilyColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Appuie pour changer',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: RilyColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded,
                            color: RilyColors.accent, size: 20),
                        const SizedBox(width: 4),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          color: isEnabled
                              ? RilyColors.textSecondary
                              : RilyColors.textMuted,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isEnabled
                              ? 'Ajouter une photo *'
                              : 'Photo — non disponible',
                          style: TextStyle(
                            fontSize: 13,
                            color: isEnabled
                                ? RilyColors.textSecondary
                                : RilyColors.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          RilyTextField(
            controller: controller,
            label: "Rapport d'exécution *",
            hint: 'Décrivez les démarches réalisées, les documents déposés...',
            maxLines: 3,
            enabled: isEnabled && !isUploading,
          ),

          const SizedBox(height: 12),

          if (isUploading)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(
                backgroundColor: RilyColors.accent.withValues(alpha: 0.1),
                color: RilyColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: uploadFailed
                    ? RilyColors.error
                    : isEnabled
                        ? RilyColors.accent
                        : RilyColors.surfaceElevated,
                foregroundColor:
                    isEnabled ? Colors.white : RilyColors.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isEnabled && !isUploading ? onUpload : null,
              icon: isUploading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      uploadFailed
                          ? Icons.refresh_rounded
                          : Icons.upload_rounded,
                      size: 18),
              label: Text(
                _buttonLabel,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          if (uploadFailed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Upload échoué. Vérifie ta connexion et réessaie.',
                style: const TextStyle(fontSize: 12, color: RilyColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Proof done card ─────────────────────────────────────────────────────────

class _ProofDoneCard extends StatelessWidget {
  final dynamic proof;
  const _ProofDoneCard({required this.proof});

  @override
  Widget build(BuildContext context) {
    return RilyCard(
      borderColor: RilyColors.success.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified_rounded,
                  color: RilyColors.success, size: 18),
              SizedBox(width: 8),
              Text(
                "Rapport d'exécution soumis",
                style: TextStyle(
                  color: RilyColors.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            proof.comment ?? 'Aucun commentaire',
            style: const TextStyle(
                color: RilyColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Photo source tile ───────────────────────────────────────────────────────

class _PhotoSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PhotoSourceTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: RilyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RilyColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: RilyColors.accent, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: RilyColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
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