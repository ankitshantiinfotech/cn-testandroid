import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'checklist_screen.dart';
import 'monthly_view_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _totalHabits = 0;
  int _completedToday = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final habits = await db.getAllHabits();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final records = await db.getRecordsForDate(today);
    final streak = await db.getCurrentStreak();
    final best = await db.getBestStreak();

    setState(() {
      _totalHabits = habits.length;
      _completedToday = records.where((r) => r.isCompleted).length;
      _currentStreak = streak;
      _bestStreak = best;
      _isLoading = false;
    });
  }

  double get _completionPercentage =>
      _totalHabits == 0 ? 0 : _completedToday / _totalHabits;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning! ☀️';
    if (hour < 17) return 'Good Afternoon! 🌤️';
    return 'Good Evening! 🌙';
  }

  String get _motivationText {
    if (_completionPercentage == 1.0) return '🎉 Perfect day! All habits done!';
    if (_completionPercentage >= 0.7) return '💪 Crushing it! Almost there!';
    if (_completionPercentage >= 0.4) return '🚀 Good progress, keep going!';
    if (_completedToday == 0) return '🌅 Start strong – first habit awaits!';
    return '⚡ Every check counts. You got this!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildProgressCard(),
                          const SizedBox(height: 14),
                          _buildStatsRow(),
                          const SizedBox(height: 24),
                          _buildStartButton(),
                          const SizedBox(height: 14),
                          _buildQuickActions(),
                          const SizedBox(height: 20),
                          _buildTipCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── HEADER WITH GRADIENT ────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Let's crush today! 🔥",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(DateTime.now()).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormat('d').format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── PROGRESS CARD ───────────────────────────────────────────────────────

  Widget _buildProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Progress",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EEFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_completedToday / $_totalHabits',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _completionPercentage,
                minHeight: 14,
                backgroundColor: const Color(0xFFF0EEFF),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _completionPercentage == 1.0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF6C63FF),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _motivationText,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STATS ROW ───────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            emoji: '🔥',
            value: '$_currentStreak',
            label: 'Day Streak',
            color: const Color(0xFFFF6B9D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            emoji: '🏆',
            value: '$_bestStreak',
            label: 'Best Streak',
            color: const Color(0xFFFFB800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            emoji: '📊',
            value: '${(_completionPercentage * 100).toInt()}%',
            label: 'Today Rate',
            color: const Color(0xFF6C63FF),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String emoji,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── START BUTTON ────────────────────────────────────────────────────────

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChecklistScreen()),
          );
          _loadStats(); // Refresh stats when returning
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4,
          shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_filled_rounded, size: 26),
            SizedBox(width: 10),
            Text(
              'Start Monitoring',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ─── QUICK ACTIONS ───────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            emoji: '📅',
            title: 'Monthly View',
            subtitle: 'See full history',
            color: const Color(0xFF6C63FF),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MonthlyViewScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            emoji: '📊',
            title: 'Export Report',
            subtitle: 'Download Excel',
            color: const Color(0xFF4CAF50),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TIP CARD ────────────────────────────────────────────────────────────

  Widget _buildTipCard() {
    final tips = [
      '💡 Tip: Check off habits right after completing them!',
      '💡 Tip: Even 1 habit per day builds the streak.',
      '💡 Tip: Use Monthly View to spot patterns.',
      '💡 Tip: Pull down to refresh your stats.',
    ];
    final tip = tips[DateTime.now().day % tips.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0A3)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(fontSize: 13, color: Color(0xFF7A5C00)),
            ),
          ),
        ],
      ),
    );
  }
}
