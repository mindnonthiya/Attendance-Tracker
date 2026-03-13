# Attendance Tracker

Attendance Tracker คือแอปลงเวลาเข้างาน (Mobile + Web) ที่เน้นความถูกต้องของตำแหน่งและหลักฐานการลงเวลา พร้อมหน้า History สำหรับย้อนดูข้อมูลแต่ละวันอย่างอ่านง่าย

## Features
- ถ่ายรูปยืนยันใบหน้าก่อน Clock In
- ตรวจสอบตำแหน่งปัจจุบันให้อยู่ในรัศมีที่กำหนดจากออฟฟิศ
- รองรับกะทำงาน Morning / Afternoon / Evening
- บันทึกประวัติการลงเวลา (Check In/Check Out) พร้อมพิกัด
- หน้า History แสดงข้อมูลแบบการ์ด พร้อมกรองตามกะ

## Tech Stack
- Flutter
- Supabase (Auth / Database / Storage)
- Geolocator
- Image Picker
- Flutter Map (OpenStreetMap)

## Supabase Setup

### 1) Table: `attendance`
ฟิลด์ที่ควรมีอย่างน้อย
- `id` (uuid หรือ bigint, primary key)
- `user_id` (uuid)
- `date` (date หรือ text)
- `shift` (text)
- `check_in` (timestamp)
- `check_out` (timestamp, nullable)
- `latitude` (double precision)
- `longitude` (double precision)
- `selfie_url` (text, nullable)

### 2) Storage Bucket
- สร้าง bucket ชื่อ `attendance-selfie` สำหรับเก็บรูปยืนยันใบหน้า


### 3) สิ่งที่ต้องมีใน Supabase "ตอนนี้" (Checklist)
- ✅ มี bucket อย่างน้อย 1 อันในนี้: `attendance-selfie` (แนะนำ) หรือ `attendance-selfies`
- ✅ ตาราง `attendance` เปิด RLS แล้ว
- ✅ policy ให้ผู้ใช้ที่ล็อกอินแล้ว `insert/select/update` ได้เฉพาะแถวของตัวเอง (`user_id = auth.uid()`)
- ✅ policy ของ `storage.objects` สำหรับ bucket รูป ให้ผู้ใช้ที่ล็อกอินแล้วอัปโหลด/อ่านรูปของโฟลเดอร์ตัวเอง (`<uid>/...`) ได้

### 4) SQL ตัวอย่าง Policy ที่แนะนำ
> รันใน Supabase SQL Editor แล้วปรับชื่อ policy ได้ตามต้องการ

```sql
-- attendance table (RLS)
alter table public.attendance enable row level security;

create policy "attendance_select_own"
on public.attendance
for select
to authenticated
using (auth.uid() = user_id);

create policy "attendance_insert_own"
on public.attendance
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "attendance_update_own"
on public.attendance
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

```sql
-- storage.objects (selfie bucket)
-- ใช้ได้ทั้ง attendance-selfie และ attendance-selfies
create policy "selfie_read_own"
on storage.objects
for select
to authenticated
using (
  bucket_id in ('attendance-selfie', 'attendance-selfies')
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "selfie_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id in ('attendance-selfie', 'attendance-selfies')
  and (storage.foldername(name))[1] = auth.uid()::text
);
```

## Run Locally
```bash
flutter pub get
flutter run
```

## Build Web
```bash
flutter build web
```
ผลลัพธ์จะอยู่ที่ `build/web`

## Deploy (Web)
สามารถนำโฟลเดอร์ `build/web` ไป deploy ได้ทันที เช่น
- Vercel
- Netlify
- Firebase Hosting
- Cloudflare Pages

## UI Notes (History Page)
- ปรับลำดับขนาดฟอนต์ใน History Card ให้สมดุลขึ้น (หัวข้อ/ค่าเวลา/ข้อมูลรอง)
- ทำ style กลางสำหรับข้อความสำคัญ เพื่อลดความใหญ่เกินและคงความสม่ำเสมอ

## Configuration
- ตำแหน่งออฟฟิศและรัศมีตรวจสอบ อยู่ที่ `lib/services/location_service.dart`

## Troubleshooting
- ถ้าเจอ error `Bucket not found (404)` ตอนอัปโหลดรูป:
  1. เข้า Supabase > Storage แล้วสร้าง bucket ชื่อ `attendance-selfie` (แนะนำ)
  2. หรือใช้ชื่อ `attendance-selfies` ได้เช่นกัน (แอปรองรับ fallback)
  3. ตรวจสอบสิทธิ์ bucket ให้ user ที่ล็อกอินสามารถ `insert/select` object ได้
- ถ้ารูปไม่ขึ้นในหน้า History ให้ตรวจว่า field `selfie_url` ในตาราง `attendance` เก็บค่า path จริง (เช่น `attendance-selfie/<user_id>/<file>.jpg`)
