# Attendance Tracker

Attendance Tracker คือแอปลงเวลาเข้างาน (Mobile + Web) ที่เน้นความถูกต้องของตำแหน่งและหลักฐานการลงเวลา พร้อมหน้า History สำหรับย้อนดูข้อมูลแต่ละวันอย่างอ่านง่าย

## Features
- ถ่ายรูปยืนยันใบหน้าก่อน Clock In
- ตรวจสอบตำแหน่งปัจจุบันให้อยู่ในรัศมีที่กำหนดจากออฟฟิศ
- รองรับกะทำงาน Morning / Afternoon / Evening
- บันทึกประวัติการลงเวลา (Check In/Check Out) พร้อมพิกัด
- หน้า History แสดงข้อมูล พร้อมกรองตามกะ

## Tech Stack
- Flutter
- Supabase (Auth / Database / Storage)
- Geolocator
- Image Picker
- Flutter Map (OpenStreetMap)

## Supabase Setup

### 1) Table: `attendance`
ฟิลด์ที่มี
- `id` (uuid หรือ bigint, primary key)
- `user_id` (uuid)
- `date` (date หรือ text)
- `shift` (text)
- `check_in` (timestamp)
- `check_out` (timestamp, nullable)
- `latitude` (double precision)
- `longitude` (double precision)
- `selfie_url` (text, nullable, เก็บรูป Check In เดิมเพื่อ backward compatibility)
- `selfie_check_in_url` (text, nullable)
- `selfie_check_out_url` (text, nullable)


### 2) Storage Bucket
- สร้าง bucket ชื่อ `attendance-selfie` สำหรับเก็บรูปยืนยันใบหน้า

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

## Configuration
- ตำแหน่งออฟฟิศและรัศมีตรวจสอบ อยู่ที่ `lib/services/location_service.dart`
- ตอนนี้ตั้งค่าเริ่มต้นไว้ที่ (`14.03820, 100.61732`) ปรับได้ตามสถานที่จริง
- login Test user (`test@email.com`) password (`123456`)