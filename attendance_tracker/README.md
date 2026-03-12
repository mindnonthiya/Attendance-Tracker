# Attendance Tracker

แอปลงเวลาเข้างาน (มือถือ/เว็บ) พร้อมเงื่อนไขตามโจทย์:
- ต้องถ่ายรูปยืนยันใบหน้าก่อนกด Clock In
- ตรวจตำแหน่งปัจจุบัน ต้องอยู่ในรัศมีไม่เกิน 200 เมตรจากจุดทำงาน
- รองรับการลงเวลาเป็นกะ Morning / Afternoon / Evening
- เก็บประวัติการลงเวลาเพื่อย้อนตรวจสอบได้

## Tech Stack
- Flutter (Mobile + Web)
- Supabase (Auth, Database, Storage)
- Geolocator (GPS)
- Image Picker (ถ่ายรูป)

## Supabase ที่ต้องมี

### 1) ตาราง `attendance`
แนะนำฟิลด์อย่างน้อย:
- `id` (uuid / bigint, primary key)
- `user_id` (uuid)
- `date` (date หรือ text)
- `shift` (text)
- `check_in` (timestamp)
- `check_out` (timestamp, nullable)
- `latitude` (double precision)
- `longitude` (double precision)
- `selfie_url` (text, nullable)

### 2) Storage Bucket
สร้าง bucket ชื่อ `attendance-selfie` สำหรับเก็บรูปยืนยันใบหน้า

## วิธีรันในเครื่อง
```bash
flutter pub get
flutter run
```

## Build และ Deploy (Web)

### Build
```bash
flutter build web
```
ผลลัพธ์จะอยู่ที่ `build/web`

### Deploy ตัวอย่าง
สามารถนำโฟลเดอร์ `build/web` ไป deploy ได้ทันที เช่น:
- Vercel
- Netlify
- Firebase Hosting
- Cloudflare Pages

## หมายเหตุ
- พิกัดจุดทำงานตั้งค่าใน `lib/services/location_service.dart`
- ตอนนี้ตั้งค่าเริ่มต้นไว้ที่บริเวณกรุงเทพฯ (`13.7563, 100.5018`) ปรับได้ตามสถานที่จริง