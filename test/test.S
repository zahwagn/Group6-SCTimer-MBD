;------------------------
; Assembly Code - Read
;------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global SPI_MAX7219_init
.global MAX7219_disp_text
.global I2C_init
.global DS3231_RD
.global save_to_EEPROM
.global INT0_vect

.org 0x0000
    rjmp DS3231_RD              ; Reset vector
.org 0x0002
    rjmp INT0_vect      ;External Interrupt 0 handler


;==============================================================
DS3231_RD:
;---------
    ; Konfigurasi tombol eksternal pada PC2
    CBI   DDRC, 2         ; Pin PC2 i/p (save rtc to EEPROM)
    SBI   PORTC, 2        ; Enable pull-up resistor

    ; Konfigurasi INT0 (eksternal interrupt pada PD2)
    LDI   R16, (1<<ISC01) ; Trigger INT0 pada falling edge (LOW)
    STS   EICRA, R16      ; Set interrupt control register
    
    LDI   R16, (1<<INT0)  ; Enable INT0
    OUT   EIMSK, R16      ; Set external interrupt mask
    
    ; Inisialisasi flag in register instead of SRAM
    CLR   R21             ; R21 = 0, flag initially cleared
    
    ; Enable global interrupt
    SEI                   ; Set Global Interrupt Enable bit

;==============================================================
;read time
;---------
again:
    RCALL I2C_START       ;transmit START condition
    ;----------------------------------------------------------
    LDI   R27, 0b11010000 ;write address of DS3231
    RCALL I2C_write       ;send 1st byte   
    ;----------------------------------------------------------
    LDI   R27, 0x00       ;set reg pointer to Seconds
    RCALL I2C_write       ;send 2nd byte
    ;----------------------------------------------------------
    RCALL I2C_STOP        ;transmit STOP condition
    ;----------------------------------------------------------
    RCALL I2C_START       ;transmit START condition
    ;----------------------------------------------------------
    LDI   R27, 0b11010001 ;read address of DS1307
    RCALL I2C_write       ;send 1st byte   
    ;----------------------------------------------------------
    RCALL I2C_read        ;read seconds
    MOV   R28, R27        ;store copy in R28
    RCALL I2C_read        ;read minutes
    MOV   R30, R27        ;store copy in R30
    RCALL I2C_read_NACK   ;read hour, return NACK
    MOV   R31, R27        ;store copy in R31
    ;----------------------------------------------------------
    RCALL I2C_STOP        ;transmit STOP condition
    ;----------------------------------------------------------
    RCALL save_rtc_to_eeprom
    
    ; Cek flag penyimpanan yang di-set oleh interrupt
    CPI   R21, 1          ; Apakah flag = 1?
    BRNE  skip_saving     ; Jika tidak, lompat
    
    ; Flag = 1, simpan data ke EEPROM di alamat 0x0008 dan kelipatannya
    PUSH  R21             ; Simpan flag
    RCALL save_to_EEPROM  ; Simpan waktu ke alamat kelipatan 0x0008
    POP   R21             ; Kembalikan flag
    
    ; Reset flag setelah menyimpan
    CLR   R21
    
skip_saving:
;==============================================================
;read date
;---------
    RCALL I2C_START       ;transmit START condition
    ;----------------------------------------------------------
    LDI   R27, 0b11010000 ;write address of DS3231
    RCALL I2C_write       ;send 1st byte   
    ;----------------------------------------------------------
    LDI   R27, 0x04       ;set reg pointer to Date
    RCALL I2C_write       ;send 2nd byte
    ;----------------------------------------------------------
    RCALL I2C_STOP        ;transmit STOP condition
    ;----------------------------------------------------------
    RCALL I2C_START       ;transmit START condition
    ;----------------------------------------------------------
    LDI   R27, 0b11010001 ;read address of DS3231
    RCALL I2C_write       ;send 1st byte   
    ;----------------------------------------------------------
    RCALL I2C_read        ;read day
    MOV   R16, R27        ;store copy in R16
    RCALL I2C_read        ;read month
    MOV   R24, R27        ;store copy in R24
    RCALL I2C_read_NACK   ;read year, return NACK
    MOV   R20, R27        ;store copy in R20
    ;----------------------------------------------------------
    RCALL I2C_STOP        ;transmit STOP condition
    ;----------------------------------------------------------
    RCALL delay_ms
;==============================================================
    ;----------------------------------------------------------
    ;display seconds on MAX7219
    ;--------------------------
    MOV   R29, R28
    ANDI  R28, 0x0F
    LDI   R17, 01
    RCALL binary2decimal  ;convert & display LSD of seconds
    MOV   R28, R29
    ANDI  R28, 0xF0
    SWAP  R28
    LDI   R17, 02
    RCALL binary2decimal  ;convert & display MSD of seconds
    ;----------------------------------------------------------
    ;display minutes on MAX7219
    ;--------------------------
    MOV   R28, R30
    ANDI  R28, 0x0F
    LDI   R17, 04
    RCALL binary2decimal  ;convert & display LSD of minutes
    MOV   R28, R30
    ANDI  R28, 0xF0
    SWAP  R28
    LDI   R17, 05
    RCALL binary2decimal  ;convert & display MSD of minutes
    ;----------------------------------------------------------
    ;display hours on MAX7219
    ;------------------------
    MOV   R28, R31
    ANDI  R28, 0x0F
    LDI   R17, 07
    RCALL binary2decimal  ;convert & display LSD of hours
    MOV   R28, R31
    ANDI  R28, 0x30
    SWAP  R28
    LDI   R17, 8
    RCALL binary2decimal  ;convert & display MSD of hours
;--------------------------------------------------------------
    RCALL delay_ms
ext:RJMP  again

;==============================================================
; External Interrupt 0 Vector (INT0)
;==============================================================
.global INT0_vect
INT0_vect:
    PUSH  R16
    IN    R16, SREG        ; Simpan Status Register
    PUSH  R16
    
    ; Set flag untuk menyimpan data ke EEPROM
    LDI   R16, 1
    MOV   R21, R16         ; Set flag langsung ke R21
    
    ; Debounce delay sederhana
    PUSH  R17
    LDI   R17, 0xFF
debounce_loop:
    DEC   R17
    BRNE  debounce_loop
    POP   R17
    
    POP   R16
    OUT   SREG, R16        ; Kembalikan Status Register
    POP   R16
    RETI                   ; Return from interrupt

;==============================================================
;I2C subroutines
;==============================================================
I2C_init:
;--------
    LDI   R21, 0
    STS   TWSR, R21       ;prescaler = 0
    LDI   R21, 12         ;division factor = 12
    STS   TWBR, R21       ;SCK freq = 400kHz
    LDI   R21, (1<<TWEN)
    STS   TWCR, R21       ;enable TWI
    RET   
;==============================================================
I2C_START:
    LDI   R21, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    STS   TWCR, R21       ;transmit START condition
    ;----------------------------------------------------------
wt1:LDS   R21, TWCR
    SBRS  R21, TWINT      ;TWI interrupt = 1?
    RJMP  wt1             ;no, wait for end of transmission
    ;----------------------------------------------------------
    RET
;==============================================================
I2C_write:
    STS   TWDR, R27       ;copy SLA+W into data register
    LDI   R21, (1<<TWINT)|(1<<TWEN)
    STS   TWCR, R21       ;transmit SLA+W
    ;----------------------------------------------------------
wt2:LDS   R21, TWCR
    SBRS  R21, TWINT
    RJMP  wt2             ;wait for end of transmission
    ;----------------------------------------------------------
    RET
;==============================================================
I2C_STOP:
    LDI   R21, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
    STS   TWCR, R21       ;transmit STOP condition
    RET
;==============================================================
I2C_read:
    LDI   R21, (1<<TWINT)|(1<<TWEA)|(1<<TWEN)
    STS   TWCR, R21         ;enable TWI & ACK
    ;----------------------------------------------------------
wt3:LDS   R21, TWCR
    SBRS  R21, TWINT
    RJMP  wt3                ;wait for data byte to be read
    ;----------------------------------------------------------
    LDS   R27, TWDR         ;store received byte
    RET
;==============================================================
I2C_read_NACK:
    LDI   R21, (1<<TWINT)|(1<<TWEN)
    STS   TWCR, R21         ;enable TWI & ACK
    ;----------------------------------------------------------
wt4:LDS   R21, TWCR
    SBRS  R21, TWINT
    RJMP  wt4               ;wait for data byte to be read
    ;----------------------------------------------------------
    LDS   R27, TWDR         ;store received byte
    RET
;==============================================================
;MAX7219 subroutines
;===============================================================
SPI_MAX7219_init:
;----------------
.equ  SCK, 5
.equ  MOSI, 3
.equ  SS, 2
;--------------------------------------------------------------
      LDI   R17, (1<<MOSI)|(1<<SCK)|(1<<SS)
      OUT   DDRB, R17       ;set MOSI, SCK, SS as o/p
      ;--------------------------------------------------------
      LDI   R17, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
      OUT   SPCR, R17       ;enable SPI as master, fsck=fosc/16
      ;--------------------------------------------------------
      LDI   R17, 0x0A       ;set segment intensity (0 to 15)
      LDI   R18, 8          ;intensity level = 8
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x09       ;set decoding mode command
      LDI   R18, 0b11011011 ;decoding byte
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x0B       ;set scan limit command
      LDI   R18, 0x07       ;8 digits connected to MAX7219
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x0C       ;set turn ON/OFF command
      LDI   R18, 0x01       ;turn ON MAX7219
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      RET
;==============================================================
send_bytes:
      CBI   PORTB, SS       ;enable slave device MAX7219
      OUT   SPDR, R17       ;transmit command
      ;--------------------------------------------------------
ll2:  IN    R19, SPSR
      SBRS  R19, SPIF       ;wait for byte transmission
      RJMP  ll2             ;to complete
      ;--------------------------------------------------------
      OUT   SPDR, R18       ;transmit data
      ;--------------------------------------------------------
ll3:  IN    R19, SPSR
      SBRS  R19, SPIF       ;wait for byte transmission
      RJMP  ll3             ;to complete
      ;--------------------------------------------------------
      SBI   PORTB, SS       ;disable slave device MAX7219
      RET
;==============================================================
MAX7219_disp_text:
;-----------------
      LDI   R17, 0x03       ;select digit 2
      LDI   R18, 0x01       ;data = dash
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x06       ;select digit 5
      LDI   R18, 0x01       ;data = dash
      RCALL send_bytes      ;send command & data to MAX7219
      RET
;==============================================================
binary2decimal:
;--------------
      CLR   R26             ;set counter1, initial value 0
      CLR   R27             ;set counter2, initial value 0
      ;--------------------------------------------------------
l70:  CPI   R28, 100        ;compare R28 with 100
      BRMI  l80             ;jump when R28 < 100
      INC   R26             ;increment counter1 by 1
      SUBI  R28, 100        ;R28 = R28 - 100
      RJMP  l70
      ;--------------------------------------------------------
l80:  CPI   R28, 10         ;compare R28 with 10
      BRMI  dsp             ;jump when R28 < 10
      INC   R27             ;increment counter2 by 1
      SUBI  R28, 10         ;R28 = R28 - 10
      RJMP  l80
      ;--------------------------------------------------------
dsp:  MOV   R18, R28
      RCALL send_bytes      ;send command & data to MAX7219    
      ;--------------------------------------------------------
      RET
;==============================================================
; Fungsi untuk selalu menyimpan waktu RTC ke EEPROM alamat 0x0000
;==============================================================
save_rtc_to_eeprom:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    
    ; Save hours (R31) to EEPROM address 0x0000
    ; Tunggu hingga EEPROM siap
rtc_wait1: 
    SBIC  EECR, 1           ; Skip if EEWE bit is clear (EEPROM ready)
    RJMP  rtc_wait1         ; Wait until EEPROM ready
    
    ; Setup alamat dan data
    LDI   R18, 0x00         ; High byte of EEPROM address
    LDI   R17, 0x00         ; Low byte of EEPROM address (0x0000)
    OUT   EEARH, R18        ; Set EEPROM address high byte
    OUT   EEARL, R17        ; Set EEPROM address low byte
    MOV   R16, R31          ; Data to write (hours)
    OUT   EEDR, R16         ; Set EEPROM data register
    SBI   EECR, 2           ; Set EEMWE bit (Master Write Enable)
    SBI   EECR, 1           ; Set EEWE bit (Write Enable)
    
    ; Save minutes (R30) to EEPROM address 0x0001
rtc_wait2: 
    SBIC  EECR, 1
    RJMP  rtc_wait2
    
    LDI   R18, 0x00
    LDI   R17, 0x01         ; Address 0x0001
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R30          ; Minutes
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Save seconds (R28) to EEPROM address 0x0002
rtc_wait3: 
    SBIC  EECR, 1
    RJMP  rtc_wait3
    
    LDI   R18, 0x00
    LDI   R17, 0x02         ; Address 0x0002
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R28          ; Seconds
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    POP   R18
    POP   R17
    POP   R16
    RET

;==============================================================
; Fungsi untuk menyimpan waktu RTC ke alamat 0x0008 dan kelipatannya
; saat interrupt INT0 terpicu
;==============================================================
save_to_EEPROM:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    PUSH  R20
    
    ; Baca alamat terakhir dari EEPROM 0x03FF (alamat tertinggi)
    ; yang menyimpan indeks kelipatan 0x0008 berikutnya
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x03       ; High byte alamat = 0x03
    LDI   R17, 0xFF       ; Low byte alamat = 0xFF
    OUT   EEARH, R18
    OUT   EEARL, R17
    SBI   EECR, 0         ; EERE = 1: baca dari EEPROM
    IN    R19, EEDR       ; Baca indeks dari EEPROM
    
    ; Jika nilai tidak valid (0xFF), mulai dari 0
    CPI   R19, 0xFF
    BRNE  valid_index
    LDI   R19, 0          ; Indeks awal = 0
    
valid_index:
    ; Hitung alamat = 0x0008 + (indeks * 3)
    MOV   R20, R19        ; R20 = indeks
    LSL   R20             ; R20 = indeks * 2
    ADD   R20, R19        ; R20 = indeks * 3
    LDI   R16, 0x08       ; Offset awal
    ADD   R20, R16        ; R20 = 0x08 + (indeks * 3)
    
    ; Save seconds (R28) ke alamat yang dihitung
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x00       ; High byte of EEPROM address
    MOV   R17, R20        ; Low byte of EEPROM address
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R28        ; Data to write (seconds)
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Save minutes (R30) ke alamat yang dihitung + 1
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x00
    MOV   R17, R20
    INC   R17             ; Alamat + 1
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R30        ; Data to write (minutes)
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Save hours (R31) ke alamat yang dihitung + 2
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x00
    MOV   R17, R20
    SUBI  R17, -2         ; Alamat + 2
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R31        ; Data to write (hours)
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Update indeks untuk penyimpanan berikutnya
    INC   R19             ; indeks++
    
    ; Jika mencapai batas (misalnya 80 kali penyimpanan), reset ke 0
    CPI   R19, 80         ; Batas maksimum (80*3 = 240 byte)
    BRLO  save_index
    LDI   R19, 0          ; Reset indeks
    
save_index:
    ; Simpan indeks yang diperbarui kembali ke 0x03FF
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x03
    LDI   R17, 0xFF
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R19
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Blink display to indicate data has been saved
    RCALL blink_display
    
    POP   R20
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET
    
;==============================================================
; Helper subroutine to wait until EEPROM is ready for writing
;==============================================================
wait_eeprom_ready:
    SBIC  EECR, 1         ; Skip if EEWE bit is cleared (EEPROM not busy)
    RJMP  wait_eeprom_ready ; EEPROM is busy, wait
    RET


; Fungsi untuk membandingkan seconds di 0x0002 dengan 0x0008 dan kelipatannya
; dan mengirimkan sinyal jika perbedaan > 10
;==============================================================
compare_eeprom_seconds:;==============================================================
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    PUSH  R20
    
    ; Baca detik saat ini dari alamat 0x0002
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x00       ; High byte alamat = 0x00
    LDI   R17, 0x02       ; Low byte alamat = 0x02
    OUT   EEARH, R18
    OUT   EEARL, R17
    SBI   EECR, 0         ; EERE = 1: baca dari EEPROM
    IN    R16, EEDR       ; Baca detik saat ini
    
    ; Baca indeks terakhir yang disimpan dari alamat 0x03FF
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x03       ; High byte alamat = 0x03
    LDI   R17, 0xFF       ; Low byte alamat = 0xFF
    OUT   EEARH, R18
    OUT   EEARL, R17
    SBI   EECR, 0         ; EERE = 1: baca dari EEPROM
    IN    R19, EEDR       ; Baca indeks terakhir
    
    ; Jika indeks tidak valid atau 0, tidak ada data untuk dibandingkan
    CPI   R19, 0xFF       ; Cek jika tidak valid
    BREQ  compare_exit    ; Keluar jika tidak ada data
    CPI   R19, 0          ; Cek jika indeks = 0
    BREQ  compare_exit    ; Keluar jika tidak ada data sebelumnya
    
    ; Hitung alamat data terakhir = 0x0008 + ((indeks-1) * 3)
    DEC   R19             ; R19 = indeks-1 (data terakhir)
    MOV   R20, R19        ; R20 = indeks-1
    LSL   R20             ; R20 = (indeks-1) * 2
    ADD   R20, R19        ; R20 = (indeks-1) * 3
    LDI   R17, 0x08       ; Offset awal
    ADD   R20, R17        ; R20 = 0x08 + ((indeks-1) * 3)
    
    ; Baca detik terakhir dari alamat yang dihitung
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x00       ; High byte alamat = 0x00
    MOV   R17, R20        ; Low byte alamat = yang dihitung
    OUT   EEARH, R18
    OUT   EEARL, R17
    SBI   EECR, 0         ; EERE = 1: baca dari EEPROM
    IN    R17, EEDR       ; Baca detik terakhir
    
    ; Hitung perbedaan absolut
    CP    R16, R17        ; Compare detik saat ini dengan detik terakhir
    BRLO  detik_lebih_kecil ; Jika detik saat ini < detik terakhir
    
    ; Detik saat ini >= detik terakhir
    SUB   R16, R17        ; R16 = detik saat ini - detik terakhir
    MOV   R19, R16        ; R19 = selisih detik
    RJMP  check_diff
    
detik_lebih_kecil:
    SUB   R17, R16        ; R17 = detik terakhir - detik saat ini
    MOV   R19, R17        ; R19 = selisih detik
    
check_diff:
    ; Cek apakah perbedaan > 10
    CPI   R19, 10         ; Bandingkan dengan 10
    BRLO  compare_exit    ; Jika <= 10, keluar
    
    ; Perbedaan > 10, aktifkan sinyal pada PC2
    SBI   DDRC, 2         ; Set PC2 sebagai output
    SBI   PORTC, 2        ; Set PC2 high (1)
    
    ; Loop sampai PD7 = high (1)
check_pd7:
    SBIC  PIND, 7         ; Skip if PD7 is clear (low)
    RJMP  reset_pc2       ; PD7 = high, reset PC2
    RJMP  check_pd7       ; PD7 masih low, lanjut polling
    
reset_pc2:
    CBI   PORTC, 2        ; Reset PC2 ke low (0)
    CBI   DDRC, 2         ; Set PC2 kembali ke input
    SBI   PORTC, 2        ; Enable pull-up resistor
    
compare_exit:
    POP   R20
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET

;==============================================================
; Blink display to indicate data saved
;==============================================================
blink_display:
    ; Save used registers
    PUSH  R17
    PUSH  R18
    
    ; Turn OFF display
    LDI   R17, 0x0C       ; Set shutdown register
    LDI   R18, 0x00       ; Turn OFF (shutdown mode)
    RCALL send_bytes
    
    ; Short delay
    RCALL delay_ms
    
    ; Turn ON display
    LDI   R17, 0x0C       ; Set shutdown register
    LDI   R18, 0x01       ; Turn ON (normal operation)
    RCALL send_bytes
    
    ; Short delay
    RCALL delay_ms
    
    ; Turn OFF again
    LDI   R17, 0x0C
    LDI   R18, 0x00
    RCALL send_bytes
    
    ; Short delay
    RCALL delay_ms
    
    ; Turn ON again
    LDI   R17, 0x0C
    LDI   R18, 0x01
    RCALL send_bytes
    
    POP   R18
    POP   R17
    RET

;==============================================================
;delay subroutines
;==============================================================
delay_ms:
    LDI   R22, 0xFF
a1: DEC   R22
    NOP
    BRNE  a1
    RET
;==============================================================
delay_3s:
      LDI   R21, 255
l6:   LDI   R22, 255
l7:   LDI   R23, 255
l8:   DEC   R23
      BRNE  l8
      DEC   R22
      BRNE  l7
      DEC   R21
      BRNE  l6
      RET