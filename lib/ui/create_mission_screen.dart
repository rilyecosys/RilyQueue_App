import 'package:flutter/material.dart';
import '../models/service_category.dart';
import '../services/task_api_service.dart';
import '../services/connectivity_service.dart';
import 'theme/app_theme.dart';
import 'widgets/rily_widgets.dart';

class CreateMissionScreen extends StatefulWidget {
  const CreateMissionScreen({super.key});

  @override
  State<CreateMissionScreen> createState() => _CreateMissionScreenState();
}

class _CreateMissionScreenState extends State<CreateMissionScreen> {
  final TaskApiService _api = TaskApiService();
  final ConnectivityService _conn = ConnectivityService();

  // ── Wizard state ──────────────────────────────────────────────────────────
  int _step = 0; // 0: category  1: details  2: options

  // Step 0
  ServiceCategory? _selectedCategory;

  // Step 1
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  DateTime? _selectedDateTime;

  // Step 2
  bool _isPrioritaire = false;
  final _noteCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _showErrors = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg =
        ModalRoute.of(context)?.settings.arguments as ServiceCategory?;
    if (arg != null && _selectedCategory == null) {
      _selectedCategory = arg;
      if (_step == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _step = 1);
        });
      }
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Choisir la date',
      confirmText: 'Suivant',
      cancelText: 'Annuler',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Choisir le créneau',
      confirmText: 'Valider',
      cancelText: 'Retour',
    );
    if (!mounted) return;

    setState(() {
      if (time != null) {
        _selectedDateTime = DateTime(
            date.year, date.month, date.day, time.hour, time.minute);
      } else {
        _selectedDateTime =
            DateTime(date.year, date.month, date.day, 9, 0);
      }
    });
  }

  String get _formattedSlot {
    if (_selectedDateTime == null) return '';
    final d = _selectedDateTime!;
    const weekdays = [
      'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'
    ];
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'
    ];
    final wd = weekdays[d.weekday - 1];
    final mo = months[d.month - 1];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$wd ${d.day} $mo — ${h}h$m';
  }

  // ── Pricing ───────────────────────────────────────────────────────────────

  double get _basePrice {
    switch (_selectedCategory?.id) {
      case 'personal':   return 149;
      case 'mobility':   return 199;
      case 'business':   return 299;
      case 'immigration':return 249;
      case 'queue':      return 99;
      case 'notary':     return 199;
      default:           return 149;
    }
  }

  double get _totalPrice => _isPrioritaire ? _basePrice + 50 : _basePrice;

  // ── Navigation ────────────────────────────────────────────────────────────

  void _next() {
    if (_step == 0) {
      if (_selectedCategory == null) {
        setState(() => _showErrors = true);
        showErrorSnack(context, 'Veuillez sélectionner un type de démarche.');
        return;
      }
      setState(() { _step = 1; _showErrors = false; });
      return;
    }
    if (_step == 1) {
      final hasDesc = _descCtrl.text.trim().isNotEmpty;
      final hasLoc  = _locationCtrl.text.trim().isNotEmpty;
      final hasDate = _selectedDateTime != null;
      if (!hasDesc || !hasLoc || !hasDate) {
        setState(() => _showErrors = true);
        return;
      }
      setState(() { _step = 2; _showErrors = false; });
      return;
    }
    _submit();
  }

  void _back() {
    if (_step > 0) {
      setState(() { _step--; _showErrors = false; });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    if (!_conn.isConnected) {
      showErrorSnack(context, 'Connexion requise. Vérifiez votre réseau.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final desc = _descCtrl.text.trim();
      final note = _noteCtrl.text.trim();
      final combined = note.isEmpty ? desc : '$desc\n\n$note';

      // MVP: coordonnées par défaut de Casablanca
      // TODO: Remplacer par geocoding de _locationCtrl quand dispo
      const double defaultLat = 33.5731;
      const double defaultLng = -7.5898;

      final mission = await _api.createTask(
        categoryId: _selectedCategory!.id,
        description: combined,
        pickupLat: defaultLat,
        pickupLng: defaultLng,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
          context, '/missionStatus',
          arguments: mission);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  static const _stepTitles = [
    'Type de démarche',
    'Détails du dossier',
    'Options & tarif',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _back,
        ),
        title: Text(_stepTitles[_step]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: RilyColors.surfaceBorder,
            color: RilyColors.accent,
            minHeight: 3,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:  return _buildStepCategory();
      case 1:  return _buildStepDetails();
      case 2:  return _buildStepOptions();
      default: return const SizedBox.shrink();
    }
  }

  // ── Step 0 : category ─────────────────────────────────────────────────────

  Widget _buildStepCategory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quel type de démarche\nsouhaitez-vous déléguer ?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: RilyColors.textPrimary,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sélectionnez la catégorie correspondant\nà votre besoin.',
          style: TextStyle(
              fontSize: 14, color: RilyColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        ...kServiceCategories.map((cat) {
          final selected = _selectedCategory?.id == cat.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? cat.accentColor.withValues(alpha: 0.08)
                      : RilyColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        selected ? cat.accentColor : RilyColors.surfaceBorder,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cat.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                          child: Text(cat.emoji,
                              style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? cat.accentColor
                                  : RilyColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat.subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: RilyColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      color:
                          selected ? cat.accentColor : RilyColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Step 1 : details ──────────────────────────────────────────────────────

  Widget _buildStepDetails() {
    final descEmpty = _showErrors && _descCtrl.text.trim().isEmpty;
    final locEmpty  = _showErrors && _locationCtrl.text.trim().isEmpty;
    final dateEmpty = _showErrors && _selectedDateTime == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryChip(category: _selectedCategory!),
        const SizedBox(height: 24),
        const Text(
          'Décrivez votre démarche',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: RilyColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Plus vous êtes précis, mieux notre expert\npourra prendre en charge votre dossier.',
          style: TextStyle(
              fontSize: 14, color: RilyColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),

        // Description
        RilyTextField(
          controller: _descCtrl,
          label: 'Description de la démarche *',
          hint: 'Ex : Renouvellement de titre de séjour suite à un changement d\'adresse...',
          maxLines: 4,
          onChanged: (_) { if (_showErrors) setState(() {}); },
        ),
        if (descEmpty) const _FieldError('Veuillez décrire votre démarche.'),
        const SizedBox(height: 14),

        // Lieu
        RilyTextField(
          controller: _locationCtrl,
          label: 'Lieu de la démarche *',
          hint: 'Ex : Préfecture de Casablanca, Consulat de France...',
          onChanged: (_) { if (_showErrors) setState(() {}); },
        ),
        if (locEmpty) const _FieldError('Veuillez préciser le lieu.'),
        const SizedBox(height: 14),

        // Date picker
        GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: RilyColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: dateEmpty
                    ? RilyColors.error
                    : _selectedDateTime != null
                        ? RilyColors.accent.withValues(alpha: 0.5)
                        : RilyColors.surfaceBorder,
                width: _selectedDateTime != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: _selectedDateTime != null
                      ? RilyColors.accent
                      : RilyColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedDateTime != null
                      ? Text(
                          _formattedSlot,
                          style: const TextStyle(
                            fontSize: 15,
                            color: RilyColors.textPrimary,
                          ),
                        )
                      : const Text(
                          'Date / créneau souhaité *',
                          style: TextStyle(
                              fontSize: 15, color: RilyColors.textMuted),
                        ),
                ),
                if (_selectedDateTime != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedDateTime = null),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: RilyColors.textMuted),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: RilyColors.textMuted),
              ],
            ),
          ),
        ),
        if (dateEmpty) const _FieldError('Veuillez choisir une date.'),

        const SizedBox(height: 20),
        const AlertBanner(
          type: AlertType.info,
          message:
              'Vos informations sont strictement confidentielles et uniquement partagées avec l\'expert assigné à votre dossier.',
        ),
      ],
    );
  }

  // ── Step 2 : options & pricing ────────────────────────────────────────────

  Widget _buildStepOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CategoryChip(category: _selectedCategory!),
        const SizedBox(height: 24),
        const Text(
          'Options & tarification',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: RilyColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),

        const SectionHeader("NIVEAU D'URGENCE"),
        const SizedBox(height: 12),
        _UrgencyOption(
          title: 'Standard',
          subtitle: 'Prise en charge sous 48h ouvrées',
          detail: 'Tarif de base',
          isSelected: !_isPrioritaire,
          onTap: () => setState(() => _isPrioritaire = false),
        ),
        const SizedBox(height: 10),
        _UrgencyOption(
          title: 'Prioritaire',
          subtitle: 'Expert dédié — traitement sous 24h',
          detail: '+50 MAD',
          isSelected: _isPrioritaire,
          onTap: () => setState(() => _isPrioritaire = true),
          highlighted: true,
        ),

        const SizedBox(height: 24),

        const SectionHeader('INSTRUCTIONS PARTICULIÈRES'),
        const SizedBox(height: 12),
        RilyTextField(
          controller: _noteCtrl,
          label: 'Notes complémentaires (optionnel)',
          hint: 'Documents spécifiques à apporter, accès, contact sur place...',
          maxLines: 3,
        ),

        const SizedBox(height: 24),

        const SectionHeader('RÉCAPITULATIF TARIFAIRE'),
        const SizedBox(height: 12),
        RilyCard(
          borderColor: RilyColors.accent.withValues(alpha: 0.2),
          child: Column(
            children: [
              PriceRow(
                'Prestation — ${_selectedCategory!.title}',
                '${_basePrice.toStringAsFixed(0)} MAD',
              ),
              if (_isPrioritaire)
                const PriceRow(
                  'Supplément prioritaire',
                  '+50 MAD',
                  valueColor: RilyColors.express,
                ),
              const Divider(height: 20),
              PriceRow(
                'Total estimé',
                '${_totalPrice.toStringAsFixed(0)} MAD',
                isTotal: true,
              ),
              const SizedBox(height: 10),
              const Text(
                'Règlement confirmé après validation du dossier par notre équipe.',
                style: TextStyle(
                    fontSize: 11, color: RilyColors.textMuted, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const AlertBanner(
          type: AlertType.success,
          message:
              'Vos documents sont traités par des experts vérifiés, sous accord de confidentialité.',
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isLastStep = _step == 2;
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: RilyColors.bg,
        border: Border(top: BorderSide(color: RilyColors.surfaceBorder)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _back,
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: RilyButton(
              label: isLastStep ? 'Soumettre le dossier' : 'Continuer',
              loadingLabel: 'Soumission en cours...',
              isLoading: _isSubmitting,
              icon: isLastStep
                  ? Icons.send_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Inline field error
// ─────────────────────────────────────────────────────────────────────────────

class _FieldError extends StatelessWidget {
  final String message;
  const _FieldError(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 13, color: RilyColors.error),
          const SizedBox(width: 5),
          Text(
            message,
            style: const TextStyle(
                fontSize: 12, color: RilyColors.error),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Category chip (shown on steps 1 & 2)
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final ServiceCategory category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: category.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: category.accentColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            category.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: category.accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Urgency option row
// ─────────────────────────────────────────────────────────────────────────────

class _UrgencyOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String detail;
  final bool isSelected;
  final bool highlighted;
  final VoidCallback onTap;

  const _UrgencyOption({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.isSelected,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? RilyColors.express : RilyColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.08)
              : RilyColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : RilyColors.surfaceBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : RilyColors.textMuted,
                  width: isSelected ? 0 : 1.5,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : RilyColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: RilyColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              detail,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlighted
                    ? RilyColors.express
                    : RilyColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
