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
.global keypad

.org 0x0000
    rjmp DS3231_RD              ; Reset vector


;==============================================================
DS3231_RD:
;---------
    ; Setup keypad I/O
    LDI   R16, 0xFF
    OUT   DDRB, R16       ; port B o/p
    LDI   R16, 0xF0       ; low nibble port D i/p (column lines)
    OUT   DDRD, R16       ; high nibble port D o/p (row lines)
    
    ; Inisialisasi counter keypad dan buffer
    CLR   R19             ; R19 = 0, key_count initially 0
    CLR   R24             ; R24 = buffer[0] (ganti R20)
    CLR   R25             ; R25 = buffer[1] (ganti R21)
    CLR   R26             ; R26 = buffer[2] (ganti R22)
    CLR   R27             ; R27 = buffer[3] (ganti R23)

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
    
    ; Selalu simpan waktu RTC ke EEPROM 0x0000 setiap kali dibaca
    RCALL save_rtc_to_eeprom
    
    RCALL delay_ms

    PUSH  R24             ; Simpan buffer keypad
    PUSH  R25
    PUSH  R26
    PUSH  R27
    
    ; Baca input dari keypad
    RCALL keypad_read
    
    POP   R27             ; Pulihkan buffer keypad
    POP   R26
    POP   R25
    POP   R24

    ; Periksa apakah 4 angka telah dimasukkan
    CPI   R19, 4
    BRNE  skip_saving      ; Jika belum 4 angka, lompat
    
    ; 4 angka telah dimasukkan, simpan ke EEPROM
    RCALL save_to_EEPROM
    
    ; Reset counter
    CLR   R19
    
skip_saving:
;==============================================================
;read date
;---------
    ; Simpan buffer keypad sebelum dibaca RTC
    PUSH  R24             ; Simpan buffer keypad
    PUSH  R25
    PUSH  R26
    PUSH  R27


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

    ; Pulihkan buffer keypad setelah dibaca RTC
    POP   R27             ; Pulihkan buffer keypad
    POP   R26
    POP   R25
    POP   R24
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
      BRMI  l80             ;jump when R28 < 100 (hapus label Ret:)
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
; Fungsi untuk menyimpan data keypad ke EEPROM
;==============================================================
save_to_EEPROM:
    PUSH  R16
    PUSH  R17
    PUSH  R18
        PUSH  R20             ; Tambahkan register tambahan
    PUSH  R21             ; yang mungkin digunakan

    
    ; Konversi 4 digit dari keypad ke alamat EEPROM (asumsi BCD format)
    ; Misalnya 0123 -> alamat 0x0123
    
    ; Baca digit 0 dan 1 untuk membentuk byte alamat tinggi
    MOV   R16, R24       ; Digit ratusan
    SWAP  R16            ; Pindahkan ke nibble tinggi
    OR    R16, R25       ; OR dengan digit puluhan -> alamat tinggi
    MOV   R18, R16       ; R18 = high byte alamat
    
    ; Baca digit 2 dan 3 untuk membentuk byte alamat rendah
    MOV   R16, R26       ; Digit satuan
    SWAP  R16            ; Pindahkan ke nibble tinggi
    OR    R16, R27       ; OR dengan digit ratusan -> alamat rendah
    MOV   R17, R16       ; R17 = low byte alamat
    
    ; Tunggu hingga EEPROM siap
    SBIC  EECR, 1
    RJMP  .-4            ; Wait until EEPROM ready
    
    ; Simpan jam (R31) ke alamat yang dihitung
    OUT   EEARH, R18
    OUT   EEARL, R17
    MOV   R16, R31
    OUT   EEDR, R16
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Verification - Read back and display the first digit
l2: SBIC  EECR, 1
    RJMP  l2                ; Wait until EEPROM is ready
    
    ; Read from EEPROM address 0x03 (first digit)
    OUT   EEARH, R18
    OUT   EEARL, R17
    SBI   EECR, 0           ; EERE = 1: read byte from EEPROM
    IN    R16, EEDR         ; Get byte from data register
    
    ; Display read value on digit 8 for confirmation
    MOV   R18, R16
    LDI   R17, 8
    RCALL send_bytes
    
    ; Blink display untuk indikasi
    RCALL blink_display
    
    POP   R21
    POP   R20
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
    
    ; Restore registers
    POP   R18
    POP   R17
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
; Fungsi baca keypad dan tambahkan ke buffer register
;==============================================================
keypad_read:
    PUSH  R16
    PUSH  R17
    PUSH  R20              ; Gunakan R20-R21 sebagai register sementara
    PUSH  R21              ; BUKAN R24-R25 yang digunakan sebagai buffer
    
    ;-----------------------------------------------------------
gnd_rows:
    LDI   R16, 0x0F       ;send 0 to high nibble port D
    OUT   PORTD, R16      ;to ground all rows
    ;-----------------------------------------------------------
    NOP
    IN    R16, PIND       ;read key pins
    ANDI  R16, 0x0F       ;mask unused bits
    CPI   R16, 0x0F       ;equal if no keypress
    BRNE  check_keypress  ;jika ada keypress, periksa lebih lanjut
    JMP   key_exit        ;no key pressed, keluar (gunakan JMP alih-alih BREQ)
    
check_keypress:
    ;-----------------------------------------------------------
    RCALL delay_ms        ;delay to cancel switch bounce
    ;-----------------------------------------------------------
    IN    R16, PIND       ;2nd check for keypress
    ANDI  R16, 0x0F       ;which ensures that 1st keypress
    CPI   R16, 0x0F       ;was not erroneous due to spike noise
    BRNE  continue_keypad ;jika masih ada keypress, lanjutkan
    JMP   key_exit        ;gunakan JMP untuk jarak jauh
    
continue_keypad:
    ;-----------------------------------------------------------
    LDI   R16, 0b01111111 ;ground row 1
    OUT   PORTD, R16
    NOP
    IN    R16, PIND       ;read all columns
    ANDI  R16, 0x0F       ;mask unsed bits
    CPI   R16, 0x0F       ;equal if no key
    BRNE  row1_col        ;row 1, find column
    ;-----------------------------------------------------------
    LDI   R16, 0b10111111 ;ground row 2
    OUT   PORTD, R16
    NOP
    IN    R16, PIND       ;read all columns
    ANDI  R16, 0x0F       ;mask unsed bits
    CPI   R16, 0x0F       ;equal if no key
    BRNE  row2_col        ;row 2, find column
    ;-----------------------------------------------------------
    LDI   R16, 0b11011111 ;ground row 3
    OUT   PORTD, R16
    NOP
    IN    R16, PIND       ;read all columns
    ANDI  R16, 0x0F       ;mask unsed bits
    CPI   R16, 0x0F       ;equal if no key
    BRNE  row3_col        ;row 3, find column
    ;-----------------------------------------------------------
    LDI   R16, 0b11101111 ;ground row 4
    OUT   PORTD, R16
    NOP
    IN    R16, PIND       ;read all columns
    ANDI  R16, 0x0F       ;mask unsed bits
    CPI   R16, 0x0F       ;equal if no key
    BRNE  row4_col        ;row 4, find column
    RJMP  key_exit
;---------------------------------------------------------------
row1_col:
    LDI   R30, lo8(row1_digits)
    LDI   R31, hi8(row1_digits) ;assign pointer Z to row 1 table
    RJMP  find_digit
;---------------------------------------------------------------
row2_col:
    LDI   R30, lo8(row2_digits)
    LDI   R31, hi8(row2_digits) ;assign pointer Z to row 2 table
    RJMP  find_digit
;---------------------------------------------------------------
row3_col:
    LDI   R30, lo8(row3_digits)
    LDI   R31, hi8(row3_digits) ;assign pointer Z to row 3 table
    RJMP  find_digit
;---------------------------------------------------------------
row4_col:
    LDI   R30, lo8(row4_digits)
    LDI   R31, hi8(row4_digits) ;assign pointer Z to row 4 table
    RJMP  find_digit
;---------------------------------------------------------------
find_digit:
    LSR   R16           ;logical shift right column value
    BRCC  digit_located ;if C flag is cleared, jump to label
    LPM   R20, Z+       ;otherwise, increment Z pointer
    RJMP  find_digit    ;jump & repeat
;---------------------------------------------------------------
digit_located:
    LPM   R16, Z        ;load digit value in table via Z
    
    ; Cek apakah tombol 0-9 (bukan fungsi)
    CPI   R16, 10
    BRSH  key_exit      ; Jika >= 10, bukan digit, keluar
    
    ; Simpan digit ke buffer register
    CPI   R19, 4        ; Cek jika buffer penuh
    BRSH  key_exit      ; Jika >= 4, buffer penuh, keluar
    
    ; Simpan ke buffer register yang sesuai berdasarkan key_count
    CPI   R19, 0
    BRNE  check_digit1
    MOV   R24, R16      ; buffer[0] = digit (ganti R20)
    RJMP  save_done
check_digit1:
    CPI   R19, 1
    BRNE  check_digit2
    MOV   R25, R16      ; buffer[1] = digit (ganti R21)
    RJMP  save_done
check_digit2:
    CPI   R19, 2
    BRNE  check_digit3
    MOV   R26, R16      ; buffer[2] = digit (ganti R22)
    RJMP  save_done
check_digit3:
    MOV   R27, R16      ; buffer[3] = digit (ganti R23)
    
save_done:
    ; Tampilkan digit pada MAX7219
    MOV   R28, R16
    LDI   R17, 4        ; Posisi digit di MAX7219 (digit 4)
    SUB   R17, R19      ; Tentukan posisi tampilan (4,3,2,1)
    RCALL binary2decimal ; Tampilkan digit
    
    ; Increment counter
    INC   R19
    
    ; Tunggu tombol dilepas
wait_key_release:
    NOP
    IN    R16, PIND       ;read key pins
    ANDI  R16, 0x0F       ;mask unused bits
    CPI   R16, 0x0F       ;equal if no keypress
    BRNE  wait_key_release ;if key still pressed, wait
    
key_exit:
    POP   R21             ; Restore R20-R21, bukan R24-R25
    POP   R20
    POP   R17
    POP   R16
    RET


; Tabel digit untuk keypad
row1_digits: .byte  1,2,3,10
row2_digits: .byte  4,5,6,11
row3_digits: .byte  7,8,9,12
row4_digits: .byte  15,0,14,13

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