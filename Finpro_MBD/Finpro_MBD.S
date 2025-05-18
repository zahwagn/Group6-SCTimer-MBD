;------------------------
; Assembly Code
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

    ; Konfigurasi PC1 sebagai output untuk sinyal NOT dari PC2
    SBI   DDRC, 1         ; Set PC1 sebagai output
    CBI   PORTC, 1        ; Inisialisasi PC1 sebagai LOW (kebalikan dari PC2 yang pull-up)

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
    RCALL compare_eeprom_seconds  ; Tambahkan ini untuk cek selisih
    
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
; Fungsi untuk menyimpan waktu RTC ke alamat 0x0008 saja
; saat interrupt INT0 terpicu
;==============================================================
save_to_EEPROM:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    
    ; Simpan detik (R28) ke alamat tetap 0x0008
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x00       ; High byte of EEPROM address
    LDI   R17, 0x08       ; Low byte of EEPROM address (0x0008)
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R28        ; Data to write (seconds)
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Simpan menit (R30) ke alamat tetap 0x0009
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x00
    LDI   R17, 0x09       ; Alamat tetap 0x0009
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R30        ; Data to write (minutes)
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Simpan jam (R31) ke alamat tetap 0x000A
    SBIC  EECR, 1
    RJMP  .-4
    
    LDI   R18, 0x00
    LDI   R17, 0x0A       ; Alamat tetap 0x000A
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R31        ; Data to write (hours)
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Tampilkan indikator bahwa data telah disimpan
    RCALL blink_display
    
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


;==============================================================
; Fungsi untuk membandingkan seconds di alamat 0x0002 dengan 0x0008
; dan mengaktifkan PC2 HANYA jika 0x0002 lebih besar minimal 10 dari 0x0008
;==============================================================
compare_eeprom_seconds:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    
    ; Set PC2 sebagai output terlebih dahulu
    SBI   DDRC, 2         ; Set PC2 sebagai output
    
    ; Baca detik saat ini dari alamat 0x0002
    RCALL wait_eeprom_ready
    
    LDI   R18, 0x00
    LDI   R17, 0x02       ; Alamat 0x0002
    OUT   EEARH, R18
    OUT   EEARL, R17
    SBI   EECR, 0         ; Baca EEPROM
    IN    R16, EEDR       ; R16 = detik saat ini (0x0002)
    
    ; Baca detik dari alamat 0x0008
    RCALL wait_eeprom_ready
    
    LDI   R18, 0x00
    LDI   R17, 0x08       ; Alamat 0x0008
    OUT   EEARH, R18
    OUT   EEARL, R17
    SBI   EECR, 0         ; Baca EEPROM
    IN    R17, EEDR       ; R17 = detik referensi (0x0008)
    
    ; Konversi nilai BCD ke desimal untuk perbandingan yang akurat
    
    ; Konversi R16 (detik saat ini dari 0x0002) ke desimal
    MOV   R18, R16        ; Backup nilai BCD dari 0x0002
    ANDI  R18, 0xF0       ; Isolasi digit puluhan
    SWAP  R18             ; Geser ke posisi satuan
    LDI   R19, 10
    MUL   R18, R19        ; R18 * 10
    MOV   R18, R0         ; R18 = puluhan * 10
    MOV   R19, R16        ; Gunakan nilai asli
    ANDI  R19, 0x0F       ; Isolasi digit satuan
    ADD   R18, R19        ; R18 = nilai desimal dari 0x0002
    
    ; Konversi R17 (detik referensi dari 0x0008) ke desimal
    MOV   R19, R17        ; Backup nilai BCD dari 0x0008
    ANDI  R19, 0xF0       ; Isolasi digit puluhan
    SWAP  R19             ; Geser ke posisi satuan
    LDI   R16, 10
    MUL   R19, R16        ; R19 * 10
    MOV   R19, R0         ; R19 = puluhan * 10
    MOV   R16, R17        ; Gunakan nilai asli
    ANDI  R16, 0x0F       ; Isolasi digit satuan
    ADD   R19, R16        ; R19 = nilai desimal dari 0x0008
    
    ; Sekarang R18 = nilai desimal 0x0002, R19 = nilai desimal 0x0008
    
    ; KASUS KHUSUS: Penanganan jika salah satu nilai tidak valid
    CPI   R17, 0xFF       ; Cek jika 0x0008 tidak valid (0xFF)
    BREQ  turn_off        ; Jika tidak valid, matikan LED
    
    ; Hanya nyalakan lampu jika 0x0002 > 0x0008 + 10
    ; 1. Periksa apakah 0x0002 > 0x0008
    CP    R19, R18        ; Bandingkan R19 (0x0008) dengan R18 (0x0002)
    BRSH  turn_off        ; Jika 0x0008 >= 0x0002, matikan LED (tidak memenuhi syarat)
    
    ; 2. 0x0002 > 0x0008, sekarang cek apakah selisihnya >= 10
    MOV   R16, R18        ; R16 = nilai 0x0002
    SUB   R16, R19        ; R16 = 0x0002 - 0x0008 (selisih)
    
    ; Kasus khusus: jika hasil pengurangan negatif (overflow detik)
    BRCS  handle_overflow
    
    ; Perbandingan normal
    CPI   R16, 10         ; Bandingkan selisih dengan 10
    BRSH  turn_on         ; Jika selisih >= 10, nyalakan LED
    RJMP  turn_off        ; Jika selisih < 10, matikan LED
    
handle_overflow:
    ; Jika terjadi overflow (mis. 0x0002=5, 0x0008=55)
    ; Hitung selisih dengan mempertimbangkan lingkaran 60 detik
    LDI   R17, 60
    ADD   R16, R17        ; R16 = (0x0002 - 0x0008) + 60
    CPI   R16, 10         ; Bandingkan dengan 10
    BRSH  turn_on         ; Jika selisih >= 10, nyalakan LED
    RJMP  turn_off        ; Jika tidak, matikan LED
    
turn_on:
    ; Selisih >= 10 dan 0x0002 > 0x0008, nyalakan LED
    SBI   PORTC, 2        ; Set PC2 high (LED ON)
    CBI   PORTC, 1        ; Set PC1 low (NOT dari PC2)
    RJMP  exit_compare
    
turn_off:
    ; Matikan LED jika kondisi tidak terpenuhi
    CBI   PORTC, 2        ; Set PC2 low (LED OFF)
    SBI   PORTC, 1        ; Set PC1 high (NOT dari PC2)
    
exit_compare:
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