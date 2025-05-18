# Group6-SCTimer-MBD

## Kelompok 6
- Muhammad Raihan Mustofa 2306161946
- Dwigina Sitti Zahwa     2306250724
- Tri Yoga Arsyad         2306161920
- Muhammad Rifat Faqih    2306250762
- Farhan Ramadhani Zakiyyandi 230622412

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
### c. Software Component
erancangan Perangkat lunak yang diterapkan dalam proyek Student Corner e-Time. Sistem ini dituliskan menggunakan bahasa Assembly melalui Arduino IDE, yang berfungsi untuk mengelola komponen seperti RTC, tombol, EEPROM, LED, buzzer, dan tampilan simulasi proyek menggunakan Proteus 8 Professional guna memastikan kinerja sistem yang sesuai
#### 1. Visual Studio Code (VS Code)
Dijadikan sebagai program pengolah teks alternatif untuk menyusun kode (jika tidak menggunakan Arduino IDE secara langsung). VS Code juga dapat ditambahkan dengan ekstensi untuk mendukung pengembangan proyek Arduino dan Assembly dengan penyorotan sintaks, IntelliSense, dan VS Code dipilih karena:
- Mendukung penulisan kode dalam Assembly dan C/C++ dengan fitur seperti  penyorotan sintaks, penyelesaian otomatis (IntelliSense), serta integrasi dengan ekstensi Arduino.
- Memfasilitasi pengaturan struktur proyek yang lebih baik dan efisien, terutama saat proyek menjadi lebih rumit.
- Menjadi alternatif yang fleksibel bagi pengguna yang lebih akrab dengan manajemen kode melalui editor teks sederhana yang tetap kaya fitur.
#### 2. Arduino Uno
Arduino Uno berperan sebagai pengendali utama yang mengatur dan menyelaraskan semua komponen dalam sistem. Fungsinya lebih dari sekadar mikrokontroler biasa, melainkan juga sebagai pelaksana utama dari semua logika yang ditulis dalam bahasa Assembly, termasuk berbagai fungsi penting. Dalam proyek ini arduino uno digunakan untuk:
- Mengatur komunikasi antara komponen: Arduino Uno berfungsi sebagai pengendali utama yang mengkoordinasikan interaksi dengan RTC DS3231, EEPROM, dan LED Matrix MAX7219 melalui protokol seperti I2C dan SPI.
- Menerima interupsi eksternal dan penyimpanan informasi: Ketika tombol ditekan, Uno mendeteksi sinyal melalui interrupt INT0 (PD2), kemudian secara otomatis menyimpan informasi waktu dari RTC ke EEPROM.
- Melaksanakan logika program Assembly: Arduino Uno menjalankan kode Assembly yang meliputi pengambilan waktu, pengolahan informasi, serta penampilan hasil, dan juga mengatur buzzer sebagai sinyal atau alarm.
#### 3.  Proteus 8 Professional
Digunakan untuk mengembangkan simulasi sirkuit elektronik pada proyek. selain itu proteus juga memberi kesempatan untuk pengguna melakukan pengujian desain sirkuit dan program mikrokontroler tanpa memerlukan alat fisik dan diantara fungsi utamanya adalah mencangkup:
- Membangun rangkaian simulasi untuk keseluruhan sistem, yang meliputi elemen-elemen seperti RTC, EEPROM, MAX7219, LED, buzzer, transistor, dan tombol.
- Melaksanakan simulasi interaktif untuk melihat bagaimana sistem berfungsi secara langsung, termasuk pemantauan waktu, penyimpanan data, dan hasil tampilan.
- Memastikan bahwa kode yang ditulis di Arduino IDE dapat berfungsi sesuai dengan logika yang diharapkan tanpa menghadapi masalah logika atau kesalahan fungsional saat diterapkan pada mikrokontroler.

## iv. Test results and performance evaluation
####  Functional Testing
- RTC Clock Functionality: Setelah kami meng upload code program dan melihat keduad led untuk led yang berwarna hijau dalam keadan nyala dan led merah dalam keadaan mati. ketika kami menekan botto selama 10 detik sama hasilnya led merah tidak kunjung menyala, kami juga sudah mencoba dengan mencabut beberapa komponen seperti botton, transistor hasilnya masi sama.
- Display System: Untuk uji coba ketika kami melakukan pada proteus bisa berjalan dengan baik akan tetapi ketika pada fisik tidak berhasil. kami mertimbangkan apakah karean komponene dan bebrapa keslaahn teknis lainya yang menyebabkan hal ini terjadi.
- EEPROM Storage: Ya lednya ketika baru di compilasi langsung menyala untuk led (hijau) menandakan program bisa berjalan sesuai dengan ketentuan pada code yang sauh kami buat akan tetapi ketika di bagaian tertentu sepeti kami jelaskan di atas program bermasalah.
- Interrupt System: Setealh program di compilasi untuk led (hijau) nyala dan ketika kami pencet lednya tidak menghasilkan apa-apa sama seperti seblumnya led (hijau) nyala led (merah) mati.
#### performance
- Response Time: Waktu dari ketika tombol ditekan (interupsi aktif) sampai data disimpan di EEPROM tidak dapat kita hitung dengan tepat karena lampu LED merah yang menunjukkan proses tersebut tidak menyala. Kami telah menambahkan sedikit penundaan untuk mencegah kesalahan pembacaan (bounce), tetapi tampaknya itu tidak memadai atau tidak efektif karena fungsi interupsi belum berjalan dengan baik di perangkat asli.
- Memory Usage: Program kami hanya memanfaatkan 1208 byte (sekitar 3%) dari seluruh memori program yang ada. Ini menunjukkan bahwa kode programnya masih sangat efisien dan tidak membebani mikrokontroler.
- Perbandingan Hasil dengan Rencana Awal: Awalnya, kami berencana menggunakan keypad untuk memasukkan data, tetapi karena beberapa masalah, kami memutuskan untuk menggantinya dengan tombol tekan yang disambungkan ke sistem interrupt. Dengan demikian, cara kerja yang kami uji menjadi berbeda dari apa yang kami rencanakan sebelumnya.
- Spesifikasi yang Berhasil / Tidak:
- Berhasil (di Proteus):
  - Bisa membandingkan nilai waktu dari RTC dan EEPROM.
  - Bisa membaca waktu dari modul RTC.
  - Bisa menampilkan waktu ke display (MAX7219).
  - Bisa menyalakan buzzer jika nilai waktu berbeda cukup jauh.
- Gagal atau Tidak Sesuai:
  - Keypad tidak jadi digunakan.
  - Display tidak berfungsi saat diuji pada perangkat asli.
  - Interrupt tidak bekerja seperti yang diharapkan (tombol ditekan tidak menyalakan LED merah).
- Modifikasi Perangkat Keras/Perangkat Lunak:
- Tombol: Diubah menjadi tombol karena lebih mudah untuk diuji.
- Layar LCD: Beralih ke tampilan MAX7219 karena lebih sesuai dengan format angka waktu dari RTC.
- Kami juga melakukan percobaan dengan mengganti transistor dan kabel untuk memastikan bukan karena komponen yang rusak, namun hasilnya masih tetap tidak berubah.

### Documentasi
Merupakan Vide0 Uji coba dan simulasi rangkaian fisik yang kami lakukan dapat di lihat untuk LED (hijau) sudah menyala dan kami melakukan uji coba langsung dengan cara menekan guna untuk melihat hasil output yang diberikan oleh LED merah apakah menyala atau tidak berikut di bawah merupakan Link Video Uji coba yang kami lakukan:
- Link Akses Video: https://youtube.com/shorts/f8pjXZdGZFo 

## v. Conclusion and future work
Perancangan Student Corner e-Timer telah berhasil diimplementasikan menggunakan button yang akan interrupt jika mahasiswa menekan button tersebut (INT0) maka data waktu disimpan ke EEPROM pada address kelipatan 0x0008, Modul RTC akan membandingkan selisih waktu antara data terakhir dengan saat ini, jika selisih lebih dari 10 detik, maka program akan mengaktifkan sinyal pada PC2, yaitu LED Merah dan Buzzer yang menyala sebagai indikasi waktu sudah limit, tetapi jika LED Hijau menyala maka akan memberikan akses kepada mahasiswa untuk menekan button. RTC DS3231 untuk membaca waktu yang secara otomatis disimpan ke EEPROM dan tampilkan di MAX7219.

Sebagai pengembangan pada masa depan, praktikan mengharapkan bisa menggunakan Keypad 4x4 ataupun RFID yang bisa membaca identitas mahasiswa dan menyimpannya di EEPROM secara efisien. Praktikkan juga mengharapkan kedepannya program bisa diperbaiki agar lebih baik. 
