# Group6-SCTimer-MBD

## Kelompok 6
- Muhammad Raihan Mustofa 2306161946
- Dwigina Sitti Zahwa     2306250724
- Tri Yoga Arsyad         2306161920
- Muhammad Rifat Faqih    2306250762
- FARHAN RAMADHANI ZAKIYYANDI

## i. Introduction to the problem and the solution
SC e-Timer dirangcang karena keresahan Mahasiswa DTE, di Gedung DTE terdapat Student Corner untuk mahasiswa yang ingin mengerjakan tugas ataupun belajar, tetapi ruangan ini hanya bisa menampung 10 mahasiswa padahal terdapat lebih dari `700 mahasiswa`, oleh karena itu sering kali banyak mahasiswa yang ingin menggunakan Student Corner tetapi sudah penuh. Oleh karena itu, dibuat solusi **`Student Corner e-Timer`**. Jadi, `button` yang akan _interrupt_ jika mahasiswa menekan _button_ tersebut (INT0) maka data waktu disimpan ke `EEPROM` pada address kelipatan `0x0008`, Modul RTC akan membandingkan selisih waktu antara data terakhir dengan saat ini, jika selisih `lebih dari 10 detik`, maka program akan mengaktifkan sinyal pada `PC2`, yaitu `LED Merah dan Buzzer` yang menyala sebagai indikasi waktu sudah limit, tetapi jika `LED Hijau` menyala maka akan memberikan akses kepada mahasiswa untuk menekan button. `RTC DS3231` untuk membaca waktu yang secara otomatis disimpan ke `EEPROM dan tampilkan di MAX7219`. Rancangan ini menggunakan beberpa komponen dalam pembuatannya, antara lain:
- **1 Arduino Atmega328p**
- **3 Resistor 220 - 10k ohm**
- **1 DS3231 RTC**
- **2 Button Active 5V**
- **1 MAX7219**
- **Buzzer**

Menggunakan `DS3231` untuk Timer dengan Serial Communication `I2C` dan `MAX7219` untuk tampilkan waktu, Button sebagai validasi mahasiswa untuk masuk ke SC. Data dari timer dan keypad akan disimpan di `EEPROM` internal di Arduino.
## ii. Hardware design and implementation details
### a. Design Implementation
Perancangan desain dibuat menggunakan Proteus 8 Professional, perancangan ini didesain sebagai prototype dari produk proyek agar praktikkan mengetahui apakah produk bisa efisien, menggunakan apa saja, dan masalah yang ditemukan. Komponen Arduino ataupun sensor didapatkan dengan meng-import dari The Engineer Project.
LED Merah dan LED Hijau sebagai aktuator dihubungkan ke PIN A0 dan A1 (PORT C), katoda dihubungkan ke ground melalui resistor (pull - up) agar tidak floating dan anoda dihubungkan ke PIN. Aktuator lainnya untuk menandakan time limit menggunakan buzzer dengan salah satu kaki terhubung ke ground dan kaki lainnya terhubung ke LED Merah untuk NOT dan ke PIN A2 (PORT C). Sebagai penanda waktu dan untuk compare saat menekan button sampai waktu selesai menggunakan DS3231 RTC, sensor ini menampilkan waktu ke MAX7219 menggunakan SPI Serial Communication, PIN SCL pada sensor terhubung ke PIN A5 dan PIN SDA terhubung ke PIN A4 (PORT C). MAX7219 menghubungkan semua kaki ke MAX7219 Slave, pada slave tersebut kaki DIN dihubungkan ke PIN 11, LOAD ke PIN 10, dan CLK ke PIN 13 (PORT B). Sebagai input untuk memberikan akses kepada mahasiswa menggunakan interrupt dari button dan data dari button disimpan di EEPROM, pada salah satu kaki button terhubung ke PIN 7 melalui resistor untuk menghindari floating dengan aktifkan pull-up resistor dan kaki satunya ke VCC.
### b. Hardware Component
#### 1. DS3231 RTC 
Modul Real-Time Clock untuk integrasi dengan temperature-compensated crystal oscillator (TCXO) dan crystal, keakuratannya memiliki akurasi ±2ppm dan mempertahankan akurasi waktu ketika daya utama terputus. Modul RTC DS3231 terhubung dengan Arduino Uno dengan I2C pada pin SDA (Serial Data) untuk data I2C yang terhubung ke PC4 dan SCL (Serial Clock) untuk sinyal clock I2C yang terhubung ke PC5.
#### 2. MAX7219 8-Digit LED Display Drivers
Driver display LED 8-digit yang terintegrasi dengan display 7-segment common-cathode. Menyederhanakan interface ke display LED dan komunikasi menggunakan protokol SPI (Serial Peripheral Interface). 
#### 3. Arduino ATmega328P
Mikrokontroler 8-bit berbasis AVR pada platform Arduino yang memiliki 32KB Flash memory, 2KB SRAM, dan 1KB EEPROM. Arduino ini berfungsi untuk menjalankan komunikasi dengan DS3231 RTC melalui I2C, mengendalikan display LED melalui MAX7219 menggunakan SPI, menyimpan data waktu ke EEPROM internal, menangani interrupt eksternal (INT0) pada PIN PD2 untuk menyimpan waktu saat tombol ditekan, mengelola sinyal I/O dari komponen (LED, buzzer, button).
#### 4. Buzzer 
Komponen audio yang menghasilkan suara ketika diberi tegangan. Buzzer pada rangkaian tersambung ke ground dan pin Arduino serta LED - Merah. Buzzer yang terhubung ke transistor yang memberikan sinyal HIGH agar mengeluarkan suara, pada rangkaian buzzer akan menyala jika compare waktu yang terbaca di EEPROM dari RTC sudah menunjukkan waktu lebih dari 10 sekon sejak button ditekan, kemudian LED Merah (NOT) akan mengirim sinyal untuk membunyikan.
#### 5. Button Switch
Memicu penyimpanan data waktu saat ditekan yang terhubung ke interrupt eksternal INT0 (PD2) yang memicu interrupt, mengonfigurasi dengan  resistor pull-up internal (SBI PORTC, 2) untuk menghindari floating. Ketika button ditekan, INT0 terpicu dan mengaktifkan flag (R21) yang menandakan sistem harus menyimpan data waktu saat ini ke EEPROM pada alamat 0x0008-0x000A. Selain itu menggunakan debounce untuk menghindari multiple trigger akibat bouncing mekanis tombol.
#### 6. LED
LED pada PIN PC2 menyala ketika selisih waktu antara nilai di alamat EEPROM 0x0002 dan 0x0008 lebih besar atau sama dengan 10 detik, sedangkan LED PIN PC1 akan menyala ketika PC2 mati dan sebaliknya. LED ini  diatur dengan compare nilai detik yang disimpan di EEPROM. LED ini sebagai indikator visual untuk menunjukkan status atau hasil perbandingan data.
#### 7. Resistor
Komponen pembatas arus untuk LED dan pull-up untuk button. Resistor pembatas arus untuk LED untuk melindungi dari arus berlebih dan pull-up atau pull-down untuk konfigurasi input. Mengaktifkan pull-up untuk menghindari adanya floating sehingga pembacaan terhindar dari noise.
## iii. Software implementation details

## iv. Test results and performance evaluation

## v. Conclusion and future work
Perancangan Student Corner e-Timer telah berhasil diimplementasikan menggunakan button yang akan interrupt jika mahasiswa menekan button tersebut (INT0) maka data waktu disimpan ke EEPROM pada address kelipatan 0x0008, Modul RTC akan membandingkan selisih waktu antara data terakhir dengan saat ini, jika selisih lebih dari 10 detik, maka program akan mengaktifkan sinyal pada PC2, yaitu LED Merah dan Buzzer yang menyala sebagai indikasi waktu sudah limit, tetapi jika LED Hijau menyala maka akan memberikan akses kepada mahasiswa untuk menekan button. RTC DS3231 untuk membaca waktu yang secara otomatis disimpan ke EEPROM dan tampilkan di MAX7219.
Sebagai pengembangan pada masa depan, praktikan mengharapkan bisa menggunakan Keypad 4x4 ataupun RFID yang bisa membaca identitas mahasiswa dan menyimpannya di EEPROM secara efisien. Praktikkan juga mengharapkan kedepannya program bisa diperbaiki agar lebih baik. 
