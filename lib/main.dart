import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/ai_service.dart';
import 'services/database_service.dart';

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
    return MaterialApp(
      title: 'AI Meeting Summarizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
      appBar: AppBar(title: const Text('AI Meeting Summarizer')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Firebase is not configured for this platform yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                errorText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              const Text(
                'Run the app on Android, iOS, web, or add Linux Firebase options if you want desktop Linux support.',
                textAlign: TextAlign.center,
              ),
            ],
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
      appBar: AppBar(
        title: const Text("AI Meeting Summarizer", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.deepPurple.shade50,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(strokeWidth: 5),
                  const SizedBox(height: 20),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: DatabaseService.getMeetingHistory(
                userId: FirebaseAuth.instance.currentUser?.uid,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.audio_file_outlined, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          "No meetings processed yet.\nUpload an audio file to start!",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final meetings = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: meetings.length,
                  itemBuilder: (context, index) {
                    final meeting = meetings[index].data() as Map<String, dynamic>;
                    final decisions = _toStringList(meeting['decisions']);
                    final actionItems = _toStringList(meeting['actionItems']);
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: const Icon(Icons.summarize, color: Colors.deepPurple),
                        title: Text(
                          meeting['title'] ?? 'Untitled Meeting',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Items: ${actionItems.length} tasks pending"),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Executive Summary",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                const SizedBox(height: 6),
                                Text(meeting['summary'] ?? ''),
                                const Divider(height: 24),
                                
                                const Text("Key Decisions",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                const SizedBox(height: 6),
                                ...decisions.map((d) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(d.toString())),
                                        ],
                                      ),
                                    )),
                                const Divider(height: 24),

                                Text("Action Items",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                                const SizedBox(height: 6),
                                ...actionItems.map((item) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.assignment_outlined, size: 18, color: Colors.orange),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(item.toString())),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndProcessAudio,
        label: const Text("Upload Audio"),
        icon: const Icon(Icons.cloud_upload_outlined),
        backgroundColor: Colors.deepPurple.shade200,
      ),
    );
  }
}