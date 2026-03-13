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

## Run Locally
```bash
cd attendance_tracker
flutter pub get
flutter run
```

## Build Web
```bash
cd attendance_tracker
flutter build web
```
ผลลัพธ์จะอยู่ที่ `attendance_tracker/build/web`

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
- ตำแหน่งออฟฟิศและรัศมีตรวจสอบ อยู่ที่ `attendance_tracker/lib/services/location_service.dart`

## Troubleshooting
- ถ้าเจอ error `Bucket not found (404)` ตอนอัปโหลดรูป:
  1. เข้า Supabase > Storage แล้วสร้าง bucket ชื่อ `attendance-selfie` (แนะนำ)
  2. หรือใช้ชื่อ `attendance-selfies` ได้เช่นกัน (แอปรองรับ fallback)
  3. ตรวจสอบสิทธิ์ bucket ให้ user ที่ล็อกอินสามารถ `insert/select` object ได้
- ถ้ารูปไม่ขึ้นในหน้า History ให้ตรวจว่า field `selfie_url` ในตาราง `attendance` เก็บค่า path จริง (เช่น `attendance-selfie/<user_id>/<file>.jpg`)
