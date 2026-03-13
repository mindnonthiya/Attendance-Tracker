import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceSupabaseService {
  AttendanceSupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _defaultSelfieBucket = 'attendance-selfie';
  static const List<String> _fallbackSelfieBuckets = [
    _defaultSelfieBucket,
    'attendance-selfies',
  ];

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

    for (final bucket in _fallbackSelfieBuckets) {
      try {
        await _client.storage
            .from(bucket)
            .uploadBinary(
              path,
              selfieBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        return '$bucket/$path';
      } on StorageException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('bucket not found') || e.statusCode == '404') {
          continue;
        }

        throw Exception('อัปโหลดรูปไม่สำเร็จ: ${e.message}');
      } catch (e) {
        throw Exception('อัปโหลดรูปไม่สำเร็จ: $e');
      }
    }

    throw Exception(
      'อัปโหลดรูปไม่สำเร็จ: ไม่พบบัคเก็ตเก็บรูป (${_fallbackSelfieBuckets.join(', ')})\n'
      'กรุณาสร้าง Storage bucket ใน Supabase แล้วลองใหม่อีกครั้ง',
    );
  }

  ({String bucket, String path}) _extractStorageRef(String raw) {
    final normalized = raw.trim();

    for (final bucket in _fallbackSelfieBuckets) {
      if (normalized.startsWith('$bucket/')) {
        return (bucket: bucket, path: normalized.replaceFirst('$bucket/', ''));
      }
    }

    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      final segments = uri.pathSegments;
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        if (_fallbackSelfieBuckets.contains(segment) && i < segments.length - 1) {
          return (
            bucket: segment,
            path: Uri.decodeComponent(segments.sublist(i + 1).join('/')),
          );
        }
      }
    }

    return (bucket: _defaultSelfieBucket, path: normalized);
  }

  Future<String?> _buildDisplaySelfieUrl(String? raw) async {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final normalized = raw.trim();
    if (normalized.contains('/object/public/')) {
      return normalized;
    }

    final storageRef = _extractStorageRef(normalized);
    final bucketsToTry = <String>{
      storageRef.bucket,
      ..._fallbackSelfieBuckets,
    };

    for (final bucket in bucketsToTry) {
      try {
        return await _client.storage
            .from(bucket)
            .createSignedUrl(storageRef.path, 60 * 60);
      } on StorageException catch (e) {
        final message = e.message.toLowerCase();
        if (message.contains('bucket not found') || e.statusCode == '404') {
          continue;
        }
      } catch (_) {}

      try {
        return _client.storage.from(bucket).getPublicUrl(storageRef.path);
      } catch (_) {}
    }

    return null;
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
