# Group6-SCTimer-MBD

## Kelompok 6
- **Muhammad Raihan Mustofa** (2306161946)
- **Dwigina Sitti Zahwa** (2306250724)
- **Tri Yoga Arsyad** (2306161920)
- **Muhammad Rifat Faqih** (2306250762)
- **Farhan Ramadhani Zakiyyandi** (230622412)

---

## i. Introduction to the Problem and the Solution
SC e-Timer dirancang karena keresahan Mahasiswa DTE. Di Gedung DTE terdapat *Student Corner* untuk mahasiswa yang ingin mengerjakan tugas ataupun belajar, tetapi ruangan ini hanya bisa menampung 10 mahasiswa padahal terdapat lebih dari **700 mahasiswa**. Akibatnya, sering kali banyak mahasiswa yang ingin menggunakan *Student Corner* tetapi ruangan sudah penuh.

Oleh karena itu, dibuat solusi **Student Corner e-Timer**.

### Cara Kerja
Sistem menggunakan `button` yang akan memicu *interrupt* (INT0) jika mahasiswa menekan tombol tersebut. Saat ditekan, data waktu akan disimpan ke `EEPROM` pada address kelipatan `0x0008`. Modul RTC kemudian akan membandingkan selisih waktu antara data terakhir dengan waktu saat ini:
- Jika selisih **lebih dari 10 detik**, maka program akan mengaktifkan sinyal pada `PC2`, yaitu **LED Merah dan Buzzer** akan menyala sebagai indikasi waktu penggunaan sudah habis (*limit*).
- Jika **LED Hijau** menyala, maka sistem memberikan akses kepada mahasiswa untuk menekan tombol.

Sistem menggunakan `RTC DS3231` untuk membaca waktu yang secara otomatis disimpan ke `EEPROM` dan ditampilkan di `MAX7219`.

### Komponen Utama
Rancangan ini menggunakan beberapa komponen dalam pembuatannya, antara lain:
- **1x Arduino ATmega328P**
- **3x Resistor (220 - 10k ohm)**
- **1x DS3231 RTC** (Timer dengan Serial Communication `I2C`)
- **2x Button Active 5V** (Validasi masuk SC)
- **1x MAX7219** (Display waktu)
- **1x Buzzer**

Data dari timer dan tombol akan disimpan di `EEPROM` internal Arduino.

---

## ii. Hardware Design and Implementation Details

### a. Design Implementation
Perancangan desain dibuat menggunakan **Proteus 8 Professional**. Perancangan ini didesain sebagai prototipe produk agar praktikan mengetahui efisiensi produk, komponen yang dibutuhkan, serta potensi masalah yang mungkin ditemukan. Komponen Arduino ataupun sensor didapatkan dengan meng-*import* dari *The Engineer Project*.

**Wiring Diagram & Logika:**
- **LED Merah & Hijau (Aktuator):** Dihubungkan ke PIN A0 dan A1 (PORT C). Katoda dihubungkan ke ground melalui resistor (*pull-up*) agar tidak *floating*, dan anoda dihubungkan ke PIN.
- **Buzzer:** Salah satu kaki terhubung ke ground dan kaki lainnya terhubung ke LED Merah (logika NOT) dan ke PIN A2 (PORT C).
- **DS3231 RTC:** Berfungsi sebagai penanda waktu dan komparator. Menggunakan komunikasi I2C. PIN SCL terhubung ke PIN A5 dan PIN SDA terhubung ke PIN A4 (PORT C).
- **MAX7219:** Menampilkan waktu menggunakan SPI Serial Communication. Kaki DIN dihubungkan ke PIN 11, LOAD ke PIN 10, dan CLK ke PIN 13 (PORT B).
- **Button (Input):** Menggunakan *interrupt* untuk memberikan akses. Salah satu kaki terhubung ke PIN 7 (INT0/PD2) melalui resistor untuk menghindari *floating* (aktifkan *pull-up* resistor) dan kaki satunya ke VCC.

### b. Hardware Component

#### 1. DS3231 RTC
Modul *Real-Time Clock* untuk integrasi dengan *temperature-compensated crystal oscillator* (TCXO) dan crystal. Memiliki akurasi ±2ppm dan mempertahankan akurasi waktu ketika daya utama terputus. Terhubung dengan Arduino Uno via I2C (SDA di PC4, SCL di PC5).

#### 2. MAX7219 8-Digit LED Display Drivers
Driver display LED 8-digit yang terintegrasi dengan display 7-segment *common-cathode*. Menyederhanakan interface ke display LED dan komunikasi menggunakan protokol SPI (*Serial Peripheral Interface*).

#### 3. Arduino ATmega328P
Mikrokontroler 8-bit berbasis AVR yang memiliki 32KB Flash memory, 2KB SRAM, dan 1KB EEPROM. Berfungsi sebagai otak utama untuk:
- Komunikasi dengan DS3231 (I2C).
- Mengendalikan display MAX7219 (SPI).
- Menyimpan data waktu ke EEPROM internal.
- Menangani *external interrupt* (INT0) pada PIN PD2.
- Mengelola sinyal I/O (LED, buzzer, button).

#### 4. Buzzer
Komponen audio yang menghasilkan suara ketika diberi tegangan. Buzzer menyala jika komparasi waktu di EEPROM vs RTC menunjukkan selisih lebih dari 10 detik sejak tombol ditekan. LED Merah (NOT) akan mengirim sinyal untuk membunyikan buzzer melalui transistor (sinyal HIGH).

#### 5. Button Switch
Memicu interrupt eksternal INT0 (PD2) saat ditekan. Dikonfigurasi dengan resistor *pull-up* internal (SBI PORTC, 2) untuk menghindari *floating*. Ketika ditekan, flag (R21) aktif menandakan sistem harus menyimpan data waktu saat ini ke EEPROM (alamat `0x0008-0x000A`). Menggunakan *debounce* untuk menghindari *multiple trigger*.

#### 6. LED
- **LED Merah (PC2):** Menyala ketika selisih waktu (alamat `0x0002` vs `0x0008`) $\geq$ 10 detik.
- **LED Hijau (PC1):** Menyala ketika PC2 mati (sebagai indikator akses diberikan).

#### 7. Resistor
Berfungsi sebagai pembatas arus untuk LED (melindungi dari arus berlebih) dan sebagai konfigurasi *pull-up*/*pull-down* untuk tombol agar pembacaan terhindar dari *noise*.

---

## iii. Software Implementation Details

### c. Software Component
Sistem ini ditulis menggunakan **Bahasa Assembly** melalui Arduino IDE.

#### 1. Visual Studio Code (VS Code)
Digunakan sebagai editor teks alternatif karena mendukung ekstensi Arduino dan Assembly (*syntax highlighting*, *IntelliSense*). Memfasilitasi struktur proyek yang lebih efisien dibandingkan editor standar.

#### 2. Arduino Uno
Berperan sebagai pelaksana utama logika Assembly:
- **Komunikasi:** Mengkoordinasikan I2C (RTC) dan SPI (MAX7219).
- **Interrupt & Penyimpanan:** Mendeteksi sinyal INT0 dari tombol dan menyimpan data waktu ke EEPROM.
- **Logika Program:** Menjalankan pengambilan waktu, pengolahan, serta logika alarm (Buzzer/LED).

#### 3. Proteus 8 Professional
Digunakan untuk simulasi sirkuit elektronik dan pengujian logika kode tanpa perangkat fisik. Memastikan kode Assembly berjalan sesuai logika yang diharapkan sebelum diimplementasikan ke mikrokontroler fisik.

---

## iv. Test Results and Performance Evaluation

### Functional Testing
- **RTC Clock Functionality:** Setelah upload program, LED Hijau menyala dan LED Merah mati (kondisi awal benar). Namun, ketika tombol ditekan dan ditahan selama 10 detik, LED Merah tidak kunjung menyala. Kami sudah mencoba mengganti komponen (tombol, transistor) namun hasil tetap sama.
- **Display System:** Berjalan dengan baik pada simulasi Proteus, namun tidak berhasil menampilkan data pada perangkat fisik. Kemungkinan disebabkan oleh komponen atau kesalahan teknis wiring.
- **EEPROM Storage:** Indikator LED Hijau menyala saat kompilasi menandakan program berjalan, namun fungsi penyimpanan/pengambilan data bermasalah pada kondisi tertentu di perangkat fisik.
- **Interrupt System:** Setelah kompilasi, LED Hijau menyala. Namun saat tombol ditekan, tidak ada respon perubahan (LED Merah tetap mati).

### Performance
- **Response Time:** Tidak dapat dihitung secara presisi pada perangkat fisik karena LED indikator tidak merespon. Penundaan (*delay*) untuk *debounce* telah ditambahkan, namun fungsi interupsi belum berjalan optimal di *hardware* asli.
- **Memory Usage:** Program sangat efisien, hanya menggunakan **1208 byte (sekitar 3%)** dari total memori program.
- **Perbandingan Rencana vs Hasil:**
    - *Rencana Awal:* Menggunakan Keypad dan LCD.
    - *Realisasi:* Menggunakan Tombol (karena isu teknis keypad) dan MAX7219 (agar format sesuai dengan RTC).
- **Spesifikasi Keberhasilan:**
    - **Berhasil (Simulasi Proteus):** Membandingkan waktu RTC & EEPROM, membaca RTC, menampilkan ke MAX7219, menyalakan Buzzer saat limit waktu.
    - **Gagal (Perangkat Fisik):** Display mati, Interrupt tombol tidak memicu LED Merah.

### Troubleshooting Hardware
Kami telah melakukan modifikasi perangkat keras (mengganti tombol, mengganti transistor, cek kabel) untuk memastikan tidak ada komponen rusak, namun kendala pada perangkat fisik tetap terjadi.

---

## v. Documentation

### Dokumentasi Proteus
Berikut adalah hasil simulasi yang berhasil dilakukan pada software Proteus:

**a. Akses Diberikan**
![image](https://hackmd.io/_uploads/HJsHyQwblg.png)

**b. Waktu Limit (Akses Ditolak/Alarm)**
![image](https://hackmd.io/_uploads/SyvDyQPbxg.png)

### Dokumentasi Fisik (Video)
Video uji coba dan simulasi rangkaian fisik dapat dilihat pada tautan di bawah. Pada video terlihat LED Hijau sudah menyala, dan kami melakukan uji coba penekanan tombol.

- **Link Akses Video:** [YouTube Shorts - Uji Coba Rangkaian](https://youtube.com/shorts/f8pjXZdGZFo)

---

## vi. Conclusion and Future Work
Perancangan **Student Corner e-Timer** berhasil diimplementasikan secara logika dan simulasi. Sistem menggunakan tombol interrupt (INT0) untuk menyimpan waktu ke EEPROM (alamat kelipatan `0x0008`). Modul RTC membandingkan selisih waktu; jika >10 detik, sinyal dikirim ke PC2 (LED Merah & Buzzer) sebagai indikasi waktu habis. Jika masih dalam batas, LED Hijau menyala memberikan akses.

**Future Work:**
Sebagai pengembangan di masa depan, diharapkan dapat menggunakan **Keypad 4x4** atau **RFID** untuk membaca identitas mahasiswa dan menyimpannya ke EEPROM secara efisien. Perbaikan pada sisi integrasi *hardware* fisik juga diperlukan agar sesuai dengan hasil simulasi.
