# Group6-SCTimer-MBD

## Kelompok 6
- Muhammad Raihan Mustofa 2306161946
- Dwigina Sitti Zahwa     2306250724
- Tri Yoga Arsyad         2306161920
- Muhammad Rifat Faqih    2306250762
- FARHAN RAMADHANI ZAKIYYANDI

## i. Introduction to the problem and the solution
SC e-Timer dirangcang karena keresahan Mahasiswa DTE, di Gedung DTE terdapat Student Corner untuk mahasiswa yang ingin mengerjakan tugas ataupun belajar, tetapi ruangan ini hanya bisa menampung 10 mahasiswa padahal terdapat lebih dari `500 mahasiswa`, oleh karena itu sering kali banyak mahasiswa yang ingin menggunakan Student Corner tetapi sudah penuh. Oleh karena itu, dibuat solusi **`Student Corner e-Timer`**. Jadi, dalam satu hari mahasiswa akan diberi `limit waktu` menggunakan `16-key Keypad` jika input tersebur bisa akses, maka `LED Hijau` menyala, tetapi jika sudah limit `LED Merah` menyala dan sebagai penanda menggunakan `buzzer` yang menyala jika sudah time limit. Rancangan ini menggunakan beberpa komponen dalam pembuatannya, antara lain:
- **1 Arduino Atmega328p**
- **8 Resistor 220 - 10k ohm**
- **1 DS3231 RTC**
- **4 x 4 Keypad Interface**
- **1 MAX7219**

Menggunakan `DS3231` untuk Timer dengan Serial Communication `I2C` dan `MAX7219` untuk tampilkan waktu, 4x4 Keypad sebagai validasi mahasiswa untuk masuk ke SC. Data dari timer dan keypad akan disimpan di `EEPROM` internal di Arduino dan Menampilkan indikator berhasil atau tidak menggunakan `Serial Monitor`.
## ii. Hardware design and implementation details

## iii. Software implementation details

## iv. Test results and performance evaluation

## v. Conclusion and future work
