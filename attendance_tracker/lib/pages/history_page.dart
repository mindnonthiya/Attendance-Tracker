import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/supabase_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final supabaseService = AttendanceSupabaseService();
  final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  List<Map<String, dynamic>> data = [];
  bool loading = true;
  String? errorMessage;
  String selectedFilter = 'all';

  static const _historyTitleStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.2,
  );

  static const _sectionLabelStyle = TextStyle(
    color: Color(0xFF7B8A85),
    fontSize: 13,
  );

  static const _valueStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 22,
    height: 1.15,
  );

  static const _metaStyle = TextStyle(
    color: Color(0xFF6F7F79),
    fontSize: 13,
    height: 1.2,
  );

  static const _statusTextStyle = TextStyle(
    color: Color(0xFF4D8A7E),
    fontWeight: FontWeight.w700,
    fontSize: 12,
  );

  Future<void> loadData() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await supabaseService.history();
      if (!mounted) return;
      setState(() => data = response);
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String formatDate(dynamic dateString) {
    if (dateString == null) return '-';
    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) return dateString.toString();
    return dateFormat.format(dt.toLocal());
  }

  String formatTime(dynamic dateString) {
    if (dateString == null) return '--:--';
    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) return '--:--';
    return DateFormat('hh:mm a').format(dt.toLocal());
  }

  List<Map<String, dynamic>> get filteredData {
    if (selectedFilter == 'all') return data;
    return data
        .where((item) => item['shift']?.toString() == selectedFilter)
        .toList();
  }

  void openDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryDetailPage(item: item)),
    );
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Widget _buildFilterChips() {
    final filters = const [
      ('all', 'All'),
      ('morning', 'Morning'),
      ('afternoon', 'Afternoon'),
      ('evening', 'Evening'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(item.$2),
                  selected: selectedFilter == item.$1,
                  onSelected: (_) => setState(() => selectedFilter = item.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final lat = (item['latitude'] as num?)?.toDouble();
    final lon = (item['longitude'] as num?)?.toDouble();
    final distance = lat != null && lon != null
        ? LocationService.distanceFromOffice(latitude: lat, longitude: lon) /
              1000
        : null;

    final checkInSelfieUrl =
        item['selfie_check_in_display_url']?.toString() ??
        item['selfie_display_url']?.toString() ??
        item['selfie_url']?.toString();
    final checkOutSelfieUrl =
        item['selfie_check_out_display_url']?.toString() ??
        item['selfie_check_out_url']?.toString();
    final validCheckInImageUrl =
        checkInSelfieUrl != null && checkInSelfieUrl.startsWith('http');
    final validCheckOutImageUrl =
        checkOutSelfieUrl != null && checkOutSelfieUrl.startsWith('http');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM d').format(
                      DateTime.tryParse((item['date'] ?? '').toString()) ??
                          DateTime.now(),
                    ),
                    style: _historyTitleStyle,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F2EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF4D8A7E),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text('Completed', style: _statusTextStyle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Shift: ${(item['shift'] ?? 'general').toString().replaceFirstMapped(RegExp(r'^.'), (m) => m.group(0)!.toUpperCase())}',
              style: _metaStyle,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.login, color: Color(0xFF4D8A7E), size: 18),
                          SizedBox(width: 8),
                          Text('Check In', style: _sectionLabelStyle),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(formatTime(item['check_in']), style: _valueStyle),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.logout,
                            color: Color(0xFFC7745F),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text('Check Out', style: _sectionLabelStyle),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(formatTime(item['check_out']), style: _valueStyle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: Color(0xFF8B9994),
                ),
                SizedBox(width: 6),
                Text('Office - Main Building', style: _metaStyle),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distance from office',
                        style: _sectionLabelStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distance != null
                            ? '${distance.toStringAsFixed(1)} km'
                            : '-',
                        style: _valueStyle,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SelfiePreview(
                      label: 'IN',
                      imageUrl: checkInSelfieUrl,
                      isValidImageUrl: validCheckInImageUrl,
                    ),
                    const SizedBox(height: 8),
                    _SelfiePreview(
                      label: 'OUT',
                      imageUrl: checkOutSelfieUrl,
                      isValidImageUrl: validCheckOutImageUrl,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          const Text(
            'Filter By',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _buildFilterChips(),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 10),
                  const Text('โหลดประวัติไม่สำเร็จ'),
                  const SizedBox(height: 8),
                  Text(errorMessage!, textAlign: TextAlign.center),
                ],
              ),
            )
          else if (filteredData.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 90),
              child: Center(
                child: Text(
                  'No records yet',
                  style: TextStyle(color: Color(0xFFA0ABA7)),
                ),
              ),
            )
          else
            ...filteredData.map(_buildHistoryCard),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildBody();

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: _buildBody(),
    );
  }
}

class HistoryDetailPage extends StatefulWidget {
  const HistoryDetailPage({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  late final Future<String?> _addressFuture;

  @override
  void initState() {
    super.initState();
    _addressFuture = _resolveAddress();
  }

  Future<String?> _resolveAddress() async {
    final latitude = (widget.item['latitude'] as num?)?.toDouble();
    final longitude = (widget.item['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) return null;

    try {
      return await LocationService.getAddressFromLatLng(latitude, longitude);
    } catch (_) {
      return null;
    }
  }

  String formatDate(dynamic dateString) {
    if (dateString == null) return '-';

    final dt = DateTime.tryParse(dateString.toString());
    if (dt == null) return dateString.toString();

    return DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final latitude = (widget.item['latitude'] as num?)?.toDouble();
    final longitude = (widget.item['longitude'] as num?)?.toDouble();
    final checkInSelfieUrl =
        widget.item['selfie_check_in_display_url']?.toString() ??
        widget.item['selfie_display_url']?.toString() ??
        widget.item['selfie_url']?.toString();
    final checkOutSelfieUrl =
        widget.item['selfie_check_out_display_url']?.toString() ??
        widget.item['selfie_check_out_url']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดประวัติ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailSelfieSection(
            title: 'รูปตอน Check In',
            imageUrl: checkInSelfieUrl,
          ),
          const SizedBox(height: 12),
          _DetailSelfieSection(
            title: 'รูปตอน Check Out',
            imageUrl: checkOutSelfieUrl,
          ),
          const SizedBox(height: 16),
          Text('วันที่: ${widget.item['date'] ?? '-'}'),
          Text('กะ: ${widget.item['shift'] ?? 'general'}'),
          Text('เวลาเข้างาน: ${formatDate(widget.item['check_in'])}'),
          Text('เวลาออกงาน: ${formatDate(widget.item['check_out'])}'),
          const SizedBox(height: 8),
          FutureBuilder<String?>(
            future: _addressFuture,
            builder: (context, snapshot) {
              if (latitude == null || longitude == null) {
                return const Text('สถานที่: -');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('สถานที่: กำลังโหลดที่อยู่...');
              }

              final address = snapshot.data;
              if (address == null || address.trim().isEmpty) {
                return const Text('สถานที่: ไม่สามารถระบุที่อยู่ได้');
              }

              return Text('สถานที่: $address');
            },
          ),
          const SizedBox(height: 12),
          if (latitude != null && longitude != null) ...[
            Text(
              'จุดฟ้า = ตำแหน่งที่ลงเวลา • หมุด = สำนักงาน',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _HistoryMap(latitude: latitude, longitude: longitude),
          ] else
            const Text('ไม่มีพิกัดในรายการนี้ จึงไม่สามารถแสดงแผนที่ได้'),
        ],
      ),
    );
  }
}

class _SelfiePreview extends StatelessWidget {
  const _SelfiePreview({
    required this.label,
    required this.imageUrl,
    required this.isValidImageUrl,
  });

  final String label;
  final String? imageUrl;
  final bool isValidImageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8B9994)),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 78,
            height: 78,
            child: isValidImageUrl
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFFE6EEF8),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Color(0xFFA1B2C5),
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFFE6EEF8),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFFA1B2C5),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DetailSelfieSection extends StatelessWidget {
  const _DetailSelfieSection({required this.title, required this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final validImage = imageUrl != null && imageUrl!.startsWith('http');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (validImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 180,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Text('โหลดรูปไม่สำเร็จ'),
              ),
            ),
          )
        else
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text('ไม่มีรูปถ่าย'),
          ),
      ],
    );
  }
}

class _HistoryMap extends StatelessWidget {
  const _HistoryMap({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final office = LatLng(
      LocationService.officeLatitude,
      LocationService.officeLongitude,
    );
    final attendancePoint = LatLng(latitude, longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: attendancePoint,
            initialZoom: 17,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds.fromPoints([office, attendancePoint]),
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.attendance_tracker',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: office,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF1F3C88),
                    size: 34,
                  ),
                ),
                Marker(
                  point: attendancePoint,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2596FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x662596FF),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
