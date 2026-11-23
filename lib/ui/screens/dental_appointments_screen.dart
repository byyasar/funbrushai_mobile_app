import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/dental_appointment_service.dart';
import '../../data/models/dental_appointment.dart';
import '../../data/models/toothbrush.dart';
import '../../data/services/supabase_service.dart';
import 'dental_appointment_detail_screen.dart';
import 'dental_appointment_form_screen.dart';

class DentalAppointmentsScreen extends StatefulWidget {
  final List<Toothbrush>? initialBrushes;

  const DentalAppointmentsScreen({super.key, this.initialBrushes});

  @override
  State<DentalAppointmentsScreen> createState() =>
      _DentalAppointmentsScreenState();
}

class _DentalAppointmentsScreenState extends State<DentalAppointmentsScreen> {
  List<DentalAppointment> _appointments = [];
  List<Toothbrush> _brushes = [];
  bool _isLoading = true;
  String _selectedMember = 'Tümü';
  bool _showUpcoming = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialBrushes != null) {
      _brushes = widget.initialBrushes!.where((b) => b.isActive).toList();
    }
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final appointments = await DentalAppointmentService().getAppointments();
      List<Toothbrush> brushes = _brushes;
      if (brushes.isEmpty) {
        final fetched = await SupabaseService().getAllToothbrushes();
        brushes = fetched.where((b) => b.isActive).toList();
      }
      if (mounted) {
        setState(() {
          _appointments = appointments;
          _brushes = brushes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _memberFilterOptions {
    final names = <String>{};
    for (final b in _brushes) {
      if (b.userName.trim().isNotEmpty) names.add(b.userName.trim());
    }
    for (final a in _appointments) {
      if (a.memberName.trim().isNotEmpty) names.add(a.memberName.trim());
    }
    return ['Tümü', ...names];
  }

  List<DentalAppointment> get _filteredAppointments {
    return _appointments.where((a) {
      final matchTab = _showUpcoming ? a.isUpcoming : a.isPast;
      final matchMember =
          _selectedMember == 'Tümü' || a.memberName == _selectedMember;
      return matchTab && matchMember;
    }).toList();
  }

  Future<void> _openAddForm() async {
    final result = await Navigator.of(context).push<DentalAppointment>(
      MaterialPageRoute(
        builder: (_) => DentalAppointmentFormScreen(
          familyBrushes: _brushes,
          initialMemberName:
              _selectedMember != 'Tümü' ? _selectedMember : null,
        ),
      ),
    );
    if (result != null) {
      await _loadData();
    }
  }

  Future<void> _openDetail(DentalAppointment appointment) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DentalAppointmentDetailScreen(
          appointment: appointment,
          familyBrushes: _brushes,
        ),
      ),
    );
    if (changed == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryTextLight;
    final filtered = _filteredAppointments;
    final upcomingCount = _appointments.where((a) => a.isUpcoming).length;
    final pastCount = _appointments.where((a) => a.isPast).length;
    final DentalAppointment? heroAppointment =
        (_showUpcoming && filtered.isNotEmpty) ? filtered.first : null;
    final List<DentalAppointment> restAppointments =
        heroAppointment != null ? filtered.skip(1).toList() : filtered;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Diş Randevularım',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              DateFormat('MMMM yyyy', 'tr').format(DateTime.now()),
              style: TextStyle(fontSize: 11, color: mutedColor),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Yeni Randevu',
            onPressed: _openAddForm,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddForm,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Randevu Ekle',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
                children: [
                  // Aile Üyesi Filtresi
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _memberFilterOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final name = _memberFilterOptions[index];
                        final selected = _selectedMember == name;
                        return ChoiceChip(
                          label: Text(name),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedMember = name),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Kompakt Haftalık Takvim Şeridi
                  _buildWeeklyCalendarStrip(context),

                  const SizedBox(height: 14),

                  // Yaklaşan / Geçmiş Sekmeleri
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cardDark
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSegmentButton(
                            label: 'Yaklaşan ($upcomingCount)',
                            active: _showUpcoming,
                            onTap: () => setState(() => _showUpcoming = true),
                          ),
                        ),
                        Expanded(
                          child: _buildSegmentButton(
                            label: 'Geçmiş ($pastCount)',
                            active: !_showUpcoming,
                            onTap: () => setState(() => _showUpcoming = false),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sıradaki Randevu Degrade Hero Kartı
                  if (heroAppointment != null) ...[
                    _buildHeroAppointmentCard(heroAppointment),
                    const SizedBox(height: 18),
                  ],

                  // Diğer Randevular Listesi veya Boş Durum
                  if (restAppointments.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        _showUpcoming
                            ? 'Diğer Yaklaşan Randevular'
                            : 'Tamamlanan / Geçmiş Randevular',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: mutedColor,
                        ),
                      ),
                    ),
                    ...restAppointments.map(
                      (apt) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildAppointmentListCard(context, apt),
                      ),
                    ),
                  ] else if (heroAppointment == null) ...[
                    _buildEmptyState(context),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildWeeklyCalendarStrip(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? AppColors.cardDark : Colors.white);
    final mutedColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryTextLight;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(
      7,
      (i) => DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + i),
    );

    bool hasAppointmentOn(DateTime day) {
      return _appointments.any(
        (a) =>
            a.dateTime.year == day.year &&
            a.dateTime.month == day.month &&
            a.dateTime.day == day.day,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekDays.map((day) {
          final isToday = day.year == now.year &&
              day.month == now.month &&
              day.day == now.day;
          final hasApt = hasAppointmentOn(day);
          final dayShort = DateFormat('E', 'tr').format(day);

          return Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  dayShort.length > 3 ? dayShort.substring(0, 3) : dayShort,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isToday ? Colors.white70 : mutedColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasApt
                        ? (isToday ? Colors.amberAccent : AppColors.primary)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : AppColors.secondaryTextLight,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroAppointmentCard(DentalAppointment apt) {
    return InkWell(
      onTap: () => _openDetail(apt),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⏰ ${apt.countdownLabel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '👤 ${apt.memberName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${apt.typeEmoji} ${apt.appointmentType}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${apt.doctorName} • ${apt.clinicName}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '📅 ${DateFormat('d MMM yyyy • HH:mm', 'tr').format(apt.dateTime)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Detay ›',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentListCard(
      BuildContext context, DentalAppointment apt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? AppColors.cardDark : Colors.white);
    final mutedColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryTextLight;

    return InkWell(
      onTap: () => _openDetail(apt),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.primary.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  apt.typeEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          apt.appointmentType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          apt.memberName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${apt.doctorName} • ${apt.clinicName}',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📅 ${DateFormat('d MMM yyyy • HH:mm', 'tr').format(apt.dateTime)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: apt.isUpcoming
                          ? AppColors.primary
                          : AppColors.greenSuccess,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: mutedColor),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardTheme.color ??
        (isDark ? AppColors.cardDark : Colors.white);
    final mutedColor =
        isDark ? AppColors.secondaryTextDark : AppColors.secondaryTextLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          const Text('🦷', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            _showUpcoming
                ? 'Henüz Yaklaşan Randevu Yok'
                : 'Geçmiş Randevu Bulunamadı',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _showUpcoming
                ? 'Ailenizin 6 aylık rutin diş kontrollerini ve randevularını buradan kolayca takip edebilirsiniz.'
                : 'Tamamlanan diş randevularınız burada arşivlenir.',
            style: TextStyle(fontSize: 13, color: mutedColor, height: 1.4),
            textAlign: TextAlign.center,
          ),
          if (_showUpcoming) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _openAddForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk Randevuyu Ekle'),
            ),
          ],
        ],
      ),
    );
  }
}
