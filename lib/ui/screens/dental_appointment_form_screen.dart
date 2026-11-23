import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/dental_appointment_service.dart';
import '../../core/services/device_calendar_service.dart';
import '../../data/models/dental_appointment.dart';
import '../../data/models/toothbrush.dart';
import '../widgets/app_banner.dart';

class DentalAppointmentFormScreen extends StatefulWidget {
  final List<Toothbrush> familyBrushes;
  final DentalAppointment? existingAppointment;
  final String? initialMemberName;
  final String? initialBrushId;
  final DateTime? initialDateTime;

  const DentalAppointmentFormScreen({
    super.key,
    required this.familyBrushes,
    this.existingAppointment,
    this.initialMemberName,
    this.initialBrushId,
    this.initialDateTime,
  });

  @override
  State<DentalAppointmentFormScreen> createState() =>
      _DentalAppointmentFormScreenState();
}

class _DentalAppointmentFormScreenState
    extends State<DentalAppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorController = TextEditingController();
  final _clinicController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _customMemberController = TextEditingController();

  late String _selectedMemberName;
  String? _selectedBrushId;
  String _selectedType = 'Rutin Kontrol';
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late List<String> _selectedReminders;
  bool _syncWithCalendar = true;
  bool _isSaving = false;

  static const List<Map<String, String>> _appointmentTypes = [
    {'label': 'Rutin Kontrol', 'icon': '🩺'},
    {'label': 'Diş Taşı Temizliği', 'icon': '✨'},
    {'label': 'Dolgu', 'icon': '🦷'},
    {'label': 'Ortodonti', 'icon': '😁'},
    {'label': 'Florür Uygulaması', 'icon': '🛡️'},
    {'label': 'Acil', 'icon': '🚨'},
  ];

  static const List<String> _reminderOptions = [
    '1 hafta önce',
    '1 gün önce',
    '2 saat önce',
  ];

  bool get _isEditing => widget.existingAppointment != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAppointment;
    if (existing != null) {
      _selectedMemberName = existing.memberName;
      _selectedBrushId = existing.brushId;
      _selectedType = existing.appointmentType;
      _selectedDate = DateTime(
        existing.dateTime.year,
        existing.dateTime.month,
        existing.dateTime.day,
      );
      _selectedTime = TimeOfDay(
        hour: existing.dateTime.hour,
        minute: existing.dateTime.minute,
      );
      _doctorController.text = existing.doctorName;
      _clinicController.text = existing.clinicName;
      _addressController.text = existing.address;
      _notesController.text = existing.notes;
      _selectedReminders = List<String>.from(existing.reminders);
      _syncWithCalendar = existing.syncWithCalendar;
    } else {
      final defaultDt =
          widget.initialDateTime ?? DateTime.now().add(const Duration(days: 7));
      _selectedDate = DateTime(defaultDt.year, defaultDt.month, defaultDt.day);
      _selectedTime = const TimeOfDay(hour: 14, minute: 30);
      _selectedReminders = ['1 gün önce', '2 saat önce'];

      if (widget.initialMemberName != null &&
          widget.initialMemberName!.isNotEmpty) {
        _selectedMemberName = widget.initialMemberName!;
        _selectedBrushId = widget.initialBrushId;
      } else if (widget.familyBrushes.isNotEmpty) {
        _selectedMemberName = widget.familyBrushes.first.userName;
        _selectedBrushId = widget.familyBrushes.first.fircaId;
      } else {
        _selectedMemberName = '';
        _selectedBrushId = null;
      }
    }
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _clinicController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _customMemberController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final memberName = widget.familyBrushes.isEmpty
        ? _customMemberController.text.trim()
        : _selectedMemberName.trim();

    if (memberName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir aile üyesi seçin veya ad girin.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final combinedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final existing = widget.existingAppointment;
    final appointment = DentalAppointment(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      memberName: memberName,
      brushId: _selectedBrushId,
      appointmentType: _selectedType,
      dateTime: combinedDateTime,
      doctorName: _doctorController.text.trim(),
      clinicName: _clinicController.text.trim(),
      address: _addressController.text.trim(),
      notes: _notesController.text.trim(),
      reminders: _selectedReminders,
      syncWithCalendar: _syncWithCalendar,
      isCompleted: existing?.isCompleted ?? false,
      checklist: existing?.checklist.isNotEmpty == true
          ? existing!.checklist
          : DentalAppointment.defaultChecklistFor(_selectedType),
    );

    await DentalAppointmentService().saveAppointment(appointment);

    if (_syncWithCalendar) {
      final calResult =
          await DeviceCalendarService.upsertAppointmentInCalendar(appointment);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(calResult.message),
            backgroundColor: calResult.success
                ? AppColors.greenSuccess
                : AppColors.amberAccent,
          ),
        );
      }
    } else if (_isEditing) {
      final delResult = await DeviceCalendarService
          .deleteAppointmentFromCalendar(appointment.id);
      if (mounted && delResult.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(delResult.message)),
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop(appointment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? AppColors.cardDark : Colors.white);
    final mutedColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryTextLight;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppBanner(
              title: _isEditing ? 'Randevuyu Düzenle' : 'Yeni Randevu Ekle',
              showBackButton: true,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            // Kimin İçin?
            _buildSectionLabel('Kimin İçin?', mutedColor),
            const SizedBox(height: 8),
            if (widget.familyBrushes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.familyBrushes.map((brush) {
                  final isSelected = _selectedMemberName == brush.userName;
                  return ChoiceChip(
                    label: Text(brush.userName),
                    avatar: CircleAvatar(
                      backgroundColor: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        brush.userName.isNotEmpty
                            ? brush.userName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedMemberName = brush.userName;
                        _selectedBrushId = brush.fircaId;
                      });
                    },
                  );
                }).toList(),
              )
            else
              TextFormField(
                controller: _customMemberController,
                decoration: _inputDecoration(
                  context,
                  hint: 'Kişi adı (örn. Ali)',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Kişi adı gerekli' : null,
              ),

            const SizedBox(height: 20),

            // İşlem Türü
            _buildSectionLabel('İşlem Türü', mutedColor),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _appointmentTypes.map((item) {
                final label = item['label']!;
                final icon = item['icon']!;
                final isSelected = _selectedType == label;
                return ChoiceChip(
                  label: Text('$icon $label'),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  onSelected: (_) => setState(() => _selectedType = label),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Tarih ve Saat
            _buildSectionLabel('Tarih ve Saat', mutedColor),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              DateFormat('d MMM yyyy', 'tr').format(_selectedDate),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Diş Hekimi & Klinik
            _buildSectionLabel('Diş Hekimi ve Klinik', mutedColor),
            const SizedBox(height: 8),
            TextFormField(
              controller: _doctorController,
              decoration: _inputDecoration(
                context,
                hint: 'Diş Hekimi (örn. Dt. Selin Kaya)',
                icon: Icons.medical_services_outlined,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Lütfen hekim adını girin'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clinicController,
              decoration: _inputDecoration(
                context,
                hint: 'Klinik / Hastane Adı',
                icon: Icons.local_hospital_outlined,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Lütfen klinik adını girin'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: _inputDecoration(
                context,
                hint: 'Adres (isteğe bağlı)',
                icon: Icons.location_on_outlined,
              ),
            ),

            const SizedBox(height: 20),

            // Hatırlatıcılar
            _buildSectionLabel('Bildirim Hatırlatıcıları', mutedColor),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reminderOptions.map((opt) {
                final selected = _selectedReminders.contains(opt);
                return FilterChip(
                  label: Text('🔔 $opt'),
                  selected: selected,
                  selectedColor: AppColors.greenSuccess.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.greenSuccess,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.greenSuccess
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedReminders.add(opt);
                      } else {
                        _selectedReminders.remove(opt);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Cihaz Takvimi Senkronizasyonu
            Material(
              color: cardBg,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Cihaz Takvimine Ekle',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Randevu bilgilerini takvim hatırlatıcısıyla sakla',
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
                secondary: const Icon(Icons.event_available_rounded,
                    color: AppColors.primary),
                value: _syncWithCalendar,
                onChanged: (v) => setState(() => _syncWithCalendar = v),
              ),
            ),

            const SizedBox(height: 20),

            // Notlar
            _buildSectionLabel('Notlar', mutedColor),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: _inputDecoration(
                context,
                hint: 'Hekime sorulacak sorular veya işlem notları...',
                icon: Icons.notes_rounded,
              ),
            ),

            const SizedBox(height: 28),

            // Kaydet Butonu
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isEditing ? 'Değişiklikleri Kaydet' : 'Randevuyu Kaydet',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark ? AppColors.cardDark : Colors.white;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
