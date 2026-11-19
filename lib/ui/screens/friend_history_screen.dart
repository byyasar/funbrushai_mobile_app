import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/mascot_provider.dart';
import '../../data/models/social_user.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/calendar_day_tile.dart';
import '../widgets/day_detail_drawer.dart';
import '../widgets/weekly_stars_table.dart';
import '../widgets/app_banner.dart';
import '../widgets/mascot/mascot_home_card.dart';

class FriendHistoryScreen extends StatefulWidget {
  final SocialUser user;

  const FriendHistoryScreen({super.key, required this.user});

  @override
  State<FriendHistoryScreen> createState() => _FriendHistoryScreenState();
}

class _FriendHistoryScreenState extends State<FriendHistoryScreen> {
  DateTime _currentMonth = DateTime.now();
  Map<int, Map<String, dynamic>> _monthData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMonthData();
  }

  Future<void> _fetchMonthData() async {
    setState(() => _isLoading = true);

    final records = await SupabaseService().getBrushingRecords(
      brushId: widget.user.brushId,
      month: _currentMonth,
    );

    // Maskotu bu kişinin veritabanındaki fırçalama geçmişiyle senkronize et
    final allRecords = await SupabaseService().getAllRecordsForBrush(widget.user.brushId);
    final brushDetails = await SupabaseService().getToothbrushDetails(widget.user.brushId);
    if (mounted) {
      context.read<MascotProvider>().loadForBrush(
        widget.user.brushId,
        records: allRecords,
        initialName: brushDetails?.mascotName ?? widget.user.mascotName,
      );
    }

    final Map<int, Map<String, dynamic>> newData = {};

    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      newData[i] = {
        'morning': {'status': 'missed', 'time': '-'},
        'evening': {'status': 'missed', 'time': '-', 'duration': '0:00'},
        'notes': 'Kayıt bulunamadı.',
        'hasJournal': false,
      };
    }

    for (var record in records) {
      final localTime = record.createdAt.toLocal();
      final day = localTime.day;
      final hour = localTime.hour;
      final isMorning = hour < 12;
      
      final sessionKey = isMorning ? 'morning' : 'evening';
      final timeStr = DateFormat('HH:mm').format(localTime);
      final durationStr = '${(record.durationSeconds / 60).floor()}:${(record.durationSeconds % 60).toString().padLeft(2, '0')}';

      if (newData[day] != null) {
        newData[day]![sessionKey] = {
          'status': 'success',
          'time': timeStr,
          'duration': durationStr,
        };
        newData[day]!['notes'] = 'Fırçalama kaydı alındı.';
        newData[day]!['hasJournal'] = true; 
      }
    }

    if (mounted) {
      setState(() {
        _monthData = newData;
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    });
    _fetchMonthData();
  }

  void _openDayDrawer(int day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayDetailDrawer(
        day: day,
        data: _monthData[day] ?? {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppBanner(
              title: 'Aylık Görünüm',
              showBackButton: true,
            ),
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCalendar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(widget.user.avatarUrl),
            onBackgroundImageError: (_, __) {},
            child: widget.user.avatarUrl.isEmpty 
                ? const Icon(Icons.person) 
                : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final offset = firstWeekday - 1; 

    return SingleChildScrollView( // Added scroll view to fit content
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: MascotHomeCard(
              userName: widget.user.name,
              userAvatarUrl: widget.user.avatarUrl,
              brushId: widget.user.brushId,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildCalendarHeader(),
                const SizedBox(height: 16),
                _buildWeekDaysHeader(),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true, // Allow it to be inside Column
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: daysInMonth + offset,
                  itemBuilder: (context, index) {
                    if (index < offset) {
                      return const SizedBox();
                    }
                    final day = index - offset + 1;
                    final data = _monthData[day] ?? {
                      'morning': {'status': 'none'},
                      'evening': {'status': 'none'},
                      'hasJournal': false,
                    };
                    return CalendarDayTile(
                      day: day,
                      morningStatus: data['morning']['status'],
                      eveningStatus: data['evening']['status'],
                      hasJournalEntry: data['hasJournal'],
                      onTap: () => _openDayDrawer(day),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WeeklyStarsTable(
          month: _currentMonth,
          monthData: _monthData,
          userName: widget.user.name,
          avatarUrl: widget.user.avatarUrl,
        ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('MMMM yyyy', 'tr').format(_currentMonth),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
        ),
        Row(
          children: [
            InkWell(
              onTap: () => _changeMonth(-1),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.chevron_left, color: AppColors.primary),
              ),
            ),
            InkWell(
              onTap: () => _changeMonth(1),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.chevron_right, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekDaysHeader() {
    final days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((day) => Expanded(
        child: Center(
          child: Text(
            day,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
        ),
      )).toList(),
    );
  }
}
