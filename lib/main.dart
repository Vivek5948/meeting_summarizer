import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/ai_service.dart';
import 'services/database_service.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? startupError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    startupError = e.toString();
  }

  runApp(MyApp(startupError: startupError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B5FEF);

    return MaterialApp(
      title: 'Meeting Summarizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF8C8DFF),
          secondary: const Color(0xFF39D0C5),
          surface: const Color(0xFF111827),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF050816),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardColor: const Color(0xFF0E1628),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
          headlineMedium: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8C8DFF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF10192D),
          labelStyle: const TextStyle(color: Color(0xFFD8DEFF)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          side: const BorderSide(color: Color(0xFF27324A)),
        ),
        useMaterial3: true,
      ),
      home: startupError == null
          ? const HomeScreen()
          : UnsupportedPlatformScreen(errorText: startupError!),
    );
  }
}

class UnsupportedPlatformScreen extends StatelessWidget {
  const UnsupportedPlatformScreen({super.key, required this.errorText});

  final String errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Meeting Summarizer')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050816), Color(0xFF0A1224), Color(0xFF111827)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _GlassPanel(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF172033),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFF2B3550)),
                        ),
                        child: const Icon(Icons.public_off_rounded, size: 44, color: Color(0xFF8C8DFF)),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Firebase is not configured for this platform yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'The app shell is ready, but this platform needs Firebase options before it can authenticate and sync meetings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFCBD5E1), height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        errorText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF8C9AB8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  String _loadingMessage = "";
  String? _lastUploadedFileName;

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  Future<void> _pickAndProcessAudio() async {
    // Triggers native browser window file explorer picker
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true, // Crucial for Web! Loads file contents straight into RAM
    );

    if (result != null && result.files.single.bytes != null) {
      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;

      setState(() {
        _isLoading = true;
        _loadingMessage = "Uploading audio and starting backend processing...";
        _lastUploadedFileName = fileName;
      });

      try {
        setState(() {
          _loadingMessage = "Processing meeting with backend AI pipeline...";
        });

        final aiAnalysis = await AIService.processMeetingAudio(fileBytes, fileName);
        final transcript = aiAnalysis['transcript']?.toString() ?? '';
        final summary = aiAnalysis['summary']?.toString() ?? 'No summary generated.';
        final decisions = _toStringList(aiAnalysis['decisions']);
        final actionItems = _toStringList(aiAnalysis['actionItems']);

        setState(() {
          _loadingMessage = "Saving records securely to Cloud Firestore...";
        });

        // Step 2: Record data directly into Cloud Firestore
        await DatabaseService.saveMeeting(
          title: "Meeting - ${DateTime.now().toString().substring(0, 16)}",
          transcript: transcript,
          summary: summary,
          decisions: decisions,
          actionItems: actionItems,
          userId: FirebaseAuth.instance.currentUser?.uid,
          status: 'completed',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meeting successfully processed and saved!")),
        );
      } catch (e) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Processing Error"),
            content: Text(e.toString()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
            ],
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050816), Color(0xFF0A1224), Color(0xFF121A30)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
              stream: DatabaseService.getMeetingHistory(
                userId: FirebaseAuth.instance.currentUser?.uid,
              ),
              builder: (context, snapshot) {
                final meetings = snapshot.data?.docs ?? const [];
                final completedCount = meetings.length;
                final actionCount = meetings.fold<int>(
                  0,
                  (sum, doc) {
                    final meeting = doc.data() as Map<String, dynamic>;
                    return sum + _toStringList(meeting['actionItems']).length;
                  },
                );
                final latestSummary = meetings.isNotEmpty
                    ? (meetings.first.data() as Map<String, dynamic>)['summary']?.toString() ?? 'No summary available.'
                    : 'Upload a meeting audio file to generate transcripts, summaries, and action items.';

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_isLoading) {
                  return _LoadingPanel(
                    message: _loadingMessage,
                    fileName: _lastUploadedFileName,
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      sliver: SliverToBoxAdapter(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 1100;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DashboardHero(
                                  completedCount: completedCount,
                                  actionCount: actionCount,
                                  latestSummary: latestSummary,
                                ),
                                const SizedBox(height: 18),
                                isWide
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 5,
                                            child: _UploadPanel(
                                              onUploadPressed: _pickAndProcessAudio,
                                            ),
                                          ),
                                          const SizedBox(width: 18),
                                          Expanded(
                                            flex: 4,
                                            child: _InsightsPanel(
                                              meetingCount: completedCount,
                                              actionItemCount: actionCount,
                                              latestSummary: latestSummary,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _UploadPanel(
                                            onUploadPressed: _pickAndProcessAudio,
                                          ),
                                          const SizedBox(height: 18),
                                          _InsightsPanel(
                                            meetingCount: completedCount,
                                            actionItemCount: actionCount,
                                            latestSummary: latestSummary,
                                          ),
                                        ],
                                      ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      sliver: SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: 'Meeting archive',
                          subtitle: 'Recent transcripts, summaries, decisions, and action items',
                        ),
                      ),
                    ),
                    if (meetings.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: _EmptyStateCard(onUploadPressed: _pickAndProcessAudio),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        sliver: SliverList.separated(
                          itemCount: meetings.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final meeting = meetings[index].data() as Map<String, dynamic>;
                            final decisions = _toStringList(meeting['decisions']);
                            final actionItems = _toStringList(meeting['actionItems']);
                            return _MeetingCard(
                              title: meeting['title'] ?? 'Untitled Meeting',
                              summary: meeting['summary']?.toString() ?? '',
                              decisions: decisions,
                              actionItems: actionItems,
                              transcript: meeting['transcript']?.toString() ?? '',
                              status: meeting['status']?.toString() ?? 'completed',
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10192D).withOpacity(0.70),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF2D3854).withOpacity(0.75)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.completedCount,
    required this.actionCount,
    required this.latestSummary,
  });

  final int completedCount;
  final int actionCount;
  final String latestSummary;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13233E),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF344766)),
                        ),
                        child: const Text(
                          'MEETING INTELLIGENCE CONTROL CENTER',
                          style: TextStyle(
                            color: Color(0xFF9AA8D2),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Turn raw recordings into executive-ready decisions.',
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload meeting audio, run the backend AI pipeline, and store structured outcomes in Firestore with a polished dashboard built for fast review.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _HeroChip(icon: Icons.lock_outline, label: 'Secure backend pipeline'),
                          _HeroChip(icon: Icons.auto_awesome_outlined, label: 'AI summaries and tasks'),
                          _HeroChip(icon: Icons.web_rounded, label: 'Web-first responsive layout'),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isWide) const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MetricGrid(
                        children: [
                          _MetricCard(label: 'Meetings processed', value: '$completedCount', icon: Icons.folder_shared_outlined),
                          _MetricCard(label: 'Action items', value: '$actionCount', icon: Icons.checklist_rtl_outlined),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _MiniSummaryCard(
                        title: 'Latest summary',
                        body: latestSummary,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF8C8DFF)),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 480;
        if (isWide) {
          return Row(
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 12),
              Expanded(child: children[1]),
            ],
          );
        }

        return Column(
          children: [
            children[0],
            const SizedBox(height: 12),
            children[1],
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF22304A)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8C8DFF), Color(0xFF39D0C5)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Color(0xFF9FB0CE), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSummaryCard extends StatelessWidget {
  const _MiniSummaryCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF22304A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF9FB0CE), fontSize: 12, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(color: Colors.white, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _UploadPanel extends StatelessWidget {
  const _UploadPanel({required this.onUploadPressed});

  final VoidCallback onUploadPressed;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Upload studio',
              subtitle: 'Drop a recording and let the pipeline handle transcription, summarization, and action extraction.',
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF162038).withOpacity(0.95), const Color(0xFF0F172A).withOpacity(0.95)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2A3551)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF8C8DFF), Color(0xFF39D0C5)]),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Process a meeting in seconds',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Supports audio uploads on web and sends the file to the backend summarizer.',
                              style: TextStyle(color: Color(0xFFB8C6E3), height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _FeatureTag(icon: Icons.graphic_eq_rounded, label: 'Audio ingestion'),
                      _FeatureTag(icon: Icons.model_training_outlined, label: 'Backend AI pipeline'),
                      _FeatureTag(icon: Icons.storage_rounded, label: 'Firestore sync'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onUploadPressed,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Upload audio and generate report'),
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
}

class _FeatureTag extends StatelessWidget {
  const _FeatureTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10192D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263552)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8C8DFF)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFFD8DEFF), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({
    required this.meetingCount,
    required this.actionItemCount,
    required this.latestSummary,
  });

  final int meetingCount;
  final int actionItemCount;
  final String latestSummary;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Live insights',
              subtitle: 'A compact readout of what the system has processed so far.',
            ),
            const SizedBox(height: 18),
            _SideStat(label: 'Meetings processed', value: '$meetingCount', icon: Icons.insights_outlined),
            const SizedBox(height: 12),
            _SideStat(label: 'Action items detected', value: '$actionItemCount', icon: Icons.task_alt_outlined),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1324),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF22304A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Latest summary snapshot', style: TextStyle(color: Color(0xFF9FB0CE), fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(latestSummary, style: const TextStyle(color: Colors.white, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideStat extends StatelessWidget {
  const _SideStat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22304A)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF39D0C5), Color(0xFF8C8DFF)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Color(0xFF9FB0CE), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF9FB0CE), height: 1.45),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.onUploadPressed});

  final VoidCallback onUploadPressed;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8C8DFF), Color(0xFF39D0C5)]),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 18),
            const Text(
              'No meetings processed yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload an audio recording to generate a transcript, summary, decisions, and action items.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFCBD5E1), height: 1.5),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onUploadPressed,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload your first meeting'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.message, required this.fileName});

  final String message;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Processing meeting',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    fileName == null ? message : '$message\n$fileName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.title,
    required this.summary,
    required this.decisions,
    required this.actionItems,
    required this.transcript,
    required this.status,
  });

  final String title;
  final String summary;
  final List<String> decisions;
  final List<String> actionItems;
  final String transcript;
  final String status;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 18),
          iconColor: const Color(0xFF8C8DFF),
          collapsedIconColor: const Color(0xFF8C8DFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(status: status),
                _InfoPill(label: '${actionItems.length} action items'),
                _InfoPill(label: '${decisions.length} decisions'),
              ],
            ),
          ),
          children: [
            _DetailBlock(title: 'Executive summary', body: summary, accent: const Color(0xFF8C8DFF)),
            const SizedBox(height: 14),
            _BulletSection(
              title: 'Key decisions',
              accent: const Color(0xFF39D0C5),
              items: decisions,
              emptyLabel: 'No decisions detected.',
            ),
            const SizedBox(height: 14),
            _BulletSection(
              title: 'Action items',
              accent: const Color(0xFFF59E0B),
              items: actionItems,
              emptyLabel: 'No action items detected.',
            ),
            const SizedBox(height: 14),
            _DetailBlock(
              title: 'Transcript preview',
              body: transcript.isEmpty ? 'No transcript available.' : transcript,
              accent: const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isComplete = status.toLowerCase() == 'completed';
    final background = isComplete ? const Color(0xFF103A2B) : const Color(0xFF3A2510);
    final foreground = isComplete ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withOpacity(0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10192D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF263552)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFD8DEFF), fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.title, required this.body, required this.accent});

  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22304A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.55)),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.accent,
    required this.items,
    required this.emptyLabel,
  });

  final String title;
  final Color accent;
  final List<String> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22304A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyLabel, style: const TextStyle(color: Color(0xFF94A3B8)))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.brightness_1, size: 8, color: accent),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item, style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.45))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}