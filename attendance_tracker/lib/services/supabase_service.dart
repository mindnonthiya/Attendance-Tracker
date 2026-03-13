import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceSupabaseService {
  AttendanceSupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<String?> uploadSelfie({required Uint8List selfieBytes}) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Please login first.');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.id}.jpg';
    final path = '${user.id}/$fileName';

    try {
      await _client.storage
          .from('attendance-selfie')
          .uploadBinary(
            path,
            selfieBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return path;
    } catch (e) {
      throw Exception('อัปโหลดรูปไม่สำเร็จ: $e');
    }
  }

  String _extractStoragePath(String raw) {
    final normalized = raw.trim();
    if (normalized.startsWith('attendance-selfie/')) {
      return normalized.replaceFirst('attendance-selfie/', '');
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) {
      return normalized;
    }

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('attendance-selfie');
    if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
      final objectSegments = segments.sublist(bucketIndex + 1);
      return Uri.decodeComponent(objectSegments.join('/'));
    }

    return normalized;
  }

  Future<String?> _buildDisplaySelfieUrl(String? raw) async {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final normalized = raw.trim();
    if (normalized.contains('/object/public/attendance-selfie/')) {
      return normalized;
    }

    final path = _extractStoragePath(normalized);
    try {
      return await _client.storage
          .from('attendance-selfie')
          .createSignedUrl(path, 60 * 60);
    } catch (_) {
      try {
        return _client.storage.from('attendance-selfie').getPublicUrl(path);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> clockIn({
    required String shift,
    required double latitude,
    required double longitude,
    String? selfieUrl,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Please login first.');
    }

    await _client.from('attendance').insert({
      'user_id': user.id,
      'shift': shift,
      'check_in': DateTime.now().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'selfie_url': selfieUrl,
      'date': DateTime.now().toIso8601String().split('T').first,
    });
  }

  Future<Map<String, dynamic>?> _findOpenAttendance({String? shift}) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Please login first.');
    }

    final withShift = shift != null && shift.isNotEmpty;

    return withShift
        ? _client
              .from('attendance')
              .select('id, shift, check_in, check_out')
              .eq('user_id', user.id)
              .eq('shift', shift)
              .isFilter('check_out', null)
              .order('check_in', ascending: false)
              .limit(1)
              .maybeSingle()
        : _client
              .from('attendance')
              .select('id, shift, check_in, check_out')
              .eq('user_id', user.id)
              .isFilter('check_out', null)
              .order('check_in', ascending: false)
              .limit(1)
              .maybeSingle();
  }

  Future<void> clockOut({String? shift}) async {
    final openAttendance = await _findOpenAttendance(shift: shift);

    if (openAttendance == null) {
      throw Exception(
        'ไม่พบรายการ Clock In ที่ยังไม่ Clock Out (ตรวจสอบ RLS policy และให้ check_out เป็น NULL ตอน clock in)',
      );
    }

    await _client
        .from('attendance')
        .update({'check_out': DateTime.now().toIso8601String()})
        .eq('id', openAttendance['id']);
  }

  Future<List<Map<String, dynamic>>> history() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Please login first.');
    }

    final response = await _client
        .from('attendance')
        .select()
        .eq('user_id', user.id)
        .order('check_in', ascending: false);

    final records = List<Map<String, dynamic>>.from(response);
    for (final record in records) {
      record['selfie_display_url'] = await _buildDisplaySelfieUrl(
        record['selfie_url']?.toString(),
      );
    }

    return records;
  }
}
