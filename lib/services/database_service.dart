import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  static final CollectionReference _meetingsCollection =
      FirebaseFirestore.instance.collection('meetings');

  static Future<void> saveMeeting({
    required String title,
    required String transcript,
    required String summary,
    required List<dynamic> decisions,
    required List<dynamic> actionItems,
    String? userId,
    String? audioUrl,
    String status = 'completed',
  }) async {
    try {
      await _meetingsCollection.add({
        'title': title,
        'createdAt': FieldValue.serverTimestamp(),
        'transcript': transcript,
        'summary': summary,
        'decisions': decisions,
        'actionItems': actionItems,
        'userId': userId,
        'audioUrl': audioUrl,
        'status': status,
      });
    } catch (e) {
      throw Exception('Failed to save to Firestore: $e');
    }
  }

  static Stream<QuerySnapshot> getMeetingHistory({String? userId}) {
    Query query = _meetingsCollection.orderBy('createdAt', descending: true);

    if (userId != null && userId.isNotEmpty) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots();
  }

  static Future<void> updateMeeting(String meetingId, Map<String, dynamic> data) async {
    try {
      await _meetingsCollection.doc(meetingId).update(data);
    } catch (e) {
      throw Exception('Failed to update meeting: $e');
    }
  }

  static Future<void> deleteMeeting(String meetingId) async {
    try {
      await _meetingsCollection.doc(meetingId).delete();
    } catch (e) {
      throw Exception('Failed to delete meeting: $e');
    }
  }
}