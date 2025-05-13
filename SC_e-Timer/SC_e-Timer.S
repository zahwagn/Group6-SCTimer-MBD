#define __SFR_OFFSET 0x00
#include "avr/io.h"

; SRAM variables
.section .bss
student_id:     .byte 1
start_time:     .byte 3  ; Hours, minutes, seconds
current_time:   .byte 3
access_granted: .byte 1
buzzer_active:  .byte 1
keypad_value:   .byte 1

; Program memory strings
.section .rodata
msg_granted:    .asciz "Akses diterima\r\n"
msg_denied:     .asciz "Akses ditolak\r\n"
msg_timeout:    .asciz "Waktu belajar sudah melebihi 3 jam\r\n"

.global setup_peripherals, system_init, keypad_auth, check_time_limit, display_time

;==============================================================
; Initialize all peripherals
;==============================================================
setup_peripherals:
    ; Set LED pins as output
    SBI   DDRB, 0   ; PB0 (LED Hijau)
    SBI   DDRB, 1   ; PB1 (LED Merah)
    SBI   DDRB, 4   ; PB4 (Buzzer)
    
    ; Enable pull-ups for keypad columns
    LDI   R24, 0x0F
    OUT   PORTD, R24
    
    RET

;==============================================================
; System Initialization
;==============================================================
system_init:
    ; Initialize serial (USART)
    LDI   R24, 103       ; Baud rate 9600 (16MHz)
    STS   UBRR0L, R24
    LDI   R24, (1<<TXEN0)|(1<<RXEN0)
    STS   UCSR0B, R24
    LDI   R24, (1<<UCSZ00)|(1<<UCSZ01)
    STS   UCSR0C, R24
    
    ; Initialize I2C for RTC
    LDI   R24, 0
    STS   TWSR, R24
    LDI   R24, 12
    STS   TWBR, R24
    LDI   R24, (1<<TWEN)
    STS   TWCR, R24
    
    ; Initialize SPI for MAX7219
    LDI   R24, (1<<DDB3)|(1<<DDB5)|(1<<DDB2)
    OUT   DDRB, R24
    LDI   R24, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R24
    
    ; Configure MAX7219
    LDI   R24, 0x0A       ; Intensity
    LDI   R25, 8
    RCALL spi_send
    LDI   R24, 0x09       ; Decode mode
    LDI   R25, 0b00000000 ; No decode
    RCALL spi_send
    LDI   R24, 0x0B       ; Scan limit
    LDI   R25, 0x07       ; All digits
    RCALL spi_send
    LDI   R24, 0x0C       ; Shutdown
    LDI   R25, 0x01       ; Normal operation
    RCALL spi_send
    
    RET

;==============================================================
; Keypad Authentication
;==============================================================
.global keypad_auth
keypad_auth:
    ; Ground all rows
    LDI   R24, 0x0F
    OUT   PORTD, R24
    
    ; Wait for key release
wait_release:
    IN    R25, PIND
    ANDI  R25, 0x0F
    CPI   R25, 0x0F
    BRNE  wait_release
    
    ; Wait for key press
wait_press:
    IN    R25, PIND
    ANDI  R25, 0x0F
    CPI   R25, 0x0F
    BREQ  wait_press
    
    ; Debounce delay
    RCALL delay_20ms
    
    ; Read keypad matrix
    LDI   R24, 0b01111111 ; Ground row 1
    OUT   PORTD, R24
    NOP
    IN    R25, PIND
    ANDI  R25, 0x0F
    CPI   R25, 0x0F
    BRNE  row1
    
    LDI   R24, 0b10111111 ; Ground row 2
    OUT   PORTD, R24
    NOP
    IN    R25, PIND
    ANDI  R25, 0x0F
    CPI   R25, 0x0F
    BRNE  row2
    
    LDI   R24, 0b11011111 ; Ground row 3
    OUT   PORTD, R24
    NOP
    IN    R25, PIND
    ANDI  R25, 0x0F
    CPI   R25, 0x0F
    BRNE  row3
    
    LDI   R24, 0b11101111 ; Ground row 4
    OUT   PORTD, R24
    NOP
    IN    R25, PIND
    ANDI  R25, 0x0F
    CPI   R25, 0x0F
    BRNE  row4
    
    RJMP  keypad_auth
    
row1:
    LDI   ZL, lo8(row1_keys)
    LDI   ZH, hi8(row1_keys)
    RJMP  decode_key
    
row2:
    LDI   ZL, lo8(row2_keys)
    LDI   ZH, hi8(row2_keys)
    RJMP  decode_key
    
row3:
    LDI   ZL, lo8(row3_keys)
    LDI   ZH, hi8(row3_keys)
    RJMP  decode_key
    
row4:
    LDI   ZL, lo8(row4_keys)
    LDI   ZH, hi8(row4_keys)
    RJMP  decode_key
    
decode_key:
    LSR   R25
    BRCC  key_found
    ADIW  ZL, 1
    RJMP  decode_key
    
key_found:
    LPM   R24, Z
    STS   student_id, R24
    
    ; Check EEPROM for previous access time
    RCALL check_eeprom
    
    ; If access granted (R24 = 1), turn on green LED
    CPI   R24, 1
    BREQ  grant_access
    
    ; Else, turn on red LED
    SBI   PORTB, 1    ; Red LED on
    CBI   PORTB, 0    ; Green LED off
    
    ; Print denied message
    LDI   ZL, lo8(msg_denied)
    LDI   ZH, hi8(msg_denied)
    RCALL print_string
    
    RJMP  keypad_auth
    
grant_access:
    SBI   PORTB, 0    ; Green LED on
    CBI   PORTB, 1    ; Red LED off
    
    ; Print granted message
    LDI   ZL, lo8(msg_granted)
    LDI   ZH, hi8(msg_granted)
    RCALL print_string
    
    ; Get current time and store in SRAM
    RCALL read_rtc_time
    LDS   R24, current_time
    STS   start_time, R24
    LDS   R24, current_time+1
    STS   start_time+1, R24
    LDS   R24, current_time+2
    STS   start_time+2, R24
    
    ; Set access granted flag
    LDI   R24, 1
    STS   access_granted, R24
    
    RET

row1_keys: .byte '1','2','3','A'
row2_keys: .byte '4','5','6','B'
row3_keys: .byte '7','8','9','C'
row4_keys: .byte '*','0','#','D'

;==============================================================
; Check Time Limit (3 hours)
;==============================================================
.global check_time_limit
check_time_limit:
    ; Check if access is granted
    LDS   R24, access_granted
    CPI   R24, 0
    BREQ  no_check
    
    ; Get current time
    RCALL read_rtc_time
    
    ; Calculate time difference
    LDS   R25, start_time      ; Start hour
    LDS   R26, current_time    ; Current hour
    SUB   R26, R25             ; Hour difference
    
    ; If more than 3 hours, trigger timeout
    CPI   R26, 3
    BRLO  no_timeout
    
timeout:
    ; Activate buzzer
    SBI   PORTB, 4
    LDI   R24, 1
    STS   buzzer_active, R24
    
    ; Turn off green LED, turn on red
    CBI   PORTB, 0
    SBI   PORTB, 1
    
    ; Print timeout message
    LDI   ZL, lo8(msg_timeout)
    LDI   ZH, hi8(msg_timeout)
    RCALL print_string
    
    ; Reset access flag
    LDI   R24, 0
    STS   access_granted, R24
    
no_timeout:
no_check:
    RET

;==============================================================
; Check EEPROM for Previous Access
; Returns: R24 = 1 if access allowed, 0 if denied
;==============================================================
check_eeprom:
    ; Calculate EEPROM address based on student ID
    LDS   R24, student_id
    LDI   R25, 4          ; Each record is 4 bytes
    MUL   R24, R25
    
    ; Read stored time from EEPROM
    MOV   R26, R0         ; Low byte of address
    LDI   R27, 0          ; High byte of address
    
    ; Read hours
    OUT   EEARH, R27
    OUT   EEARL, R26
    SBI   EECR, 0         ; Set EERE
    IN    R28, EEDR       ; Read stored hour
    
    ; Read minutes
    ADIW  R26, 1
    OUT   EEARH, R27
    OUT   EEARL, R26
    SBI   EECR, 0
    IN    R29, EEDR       ; Read stored minute
    
    ; Read seconds
    ADIW  R26, 1
    OUT   EEARH, R27
    OUT   EEARL, R26
    SBI   EECR, 0
    IN    R30, EEDR       ; Read stored second
    
    ; Get current time
    RCALL read_rtc_time
    
    ; Calculate time difference
    LDS   R31, current_time    ; Current hour
    SUB   R31, R28             ; Hour difference
    
    ; If more than 3 hours, allow access
    CPI   R31, 3
    BRSH  allow_access
    
    ; Else deny access
    CLR   R24
    RET
    
allow_access:
    ; Update EEPROM with current time
    MOV   R26, R0         ; Restore low byte of address
    LDI   R27, 0          ; High byte of address
    
    ; Write hours
    OUT   EEARH, R27
    OUT   EEARL, R26
    LDS   R24, current_time
    OUT   EEDR, R24
    SBI   EECR, 2         ; Set EEMWE
    SBI   EECR, 1         ; Set EEWE
    
    ; Write minutes
    ADIW  R26, 1
    OUT   EEARH, R27
    OUT   EEARL, R26
    LDS   R24, current_time+1
    OUT   EEDR, R24
    SBI   EECR, 2
    SBI   EECR, 1
    
    ; Write seconds
    ADIW  R26, 1
    OUT   EEARH, R27
    OUT   EEARL, R26
    LDS   R24, current_time+2
    OUT   EEDR, R24
    SBI   EECR, 2
    SBI   EECR, 1
    
    LDI   R24, 1
    RET

;==============================================================
; Read RTC Time
; Stores: current_time (hours, minutes, seconds)
;==============================================================
read_rtc_time:
    ; Start I2C
    RCALL i2c_start
    
    ; DS3231 write address
    LDI   R24, 0xD0
    RCALL i2c_write
    
    ; Set register pointer to 0 (seconds)
    LDI   R24, 0x00
    RCALL i2c_write
    
    ; Repeated start
    RCALL i2c_start
    
    ; DS3231 read address
    LDI   R24, 0xD1
    RCALL i2c_write
    
    ; Read seconds
    RCALL i2c_read_ack
    ANDI  R24, 0x7F       ; Mask top bit
    MOV   R0, R24         ; Temporary storage
    
    ; Read minutes
    RCALL i2c_read_ack
    MOV   R1, R24
    
    ; Read hours
    RCALL i2c_read_nack
    ANDI  R24, 0x3F       ; Mask 24-hour mode
    MOV   R2, R24
    
    ; Stop I2C
    RCALL i2c_stop
    
    ; Convert BCD to binary
    MOV   R24, R0
    RCALL bcd_to_bin
    STS   current_time+2, R24  ; Seconds
    
    MOV   R24, R1
    RCALL bcd_to_bin
    STS   current_time+1, R24  ; Minutes
    
    MOV   R24, R2
    RCALL bcd_to_bin
    STS   current_time, R24    ; Hours
    
    RET

;==============================================================
; I2C Subroutines
;==============================================================
i2c_start:
    LDI   R24, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    STS   TWCR, R24
wait_start:
    LDS   R24, TWCR
    SBRS  R24, TWINT
    RJMP  wait_start
    RET

i2c_write:
    STS   TWDR, R24
    LDI   R24, (1<<TWINT)|(1<<TWEN)
    STS   TWCR, R24
wait_write:
    LDS   R24, TWCR
    SBRS  R24, TWINT
    RJMP  wait_write
    RET

i2c_read_ack:
    LDI   R24, (1<<TWINT)|(1<<TWEN)|(1<<TWEA)
    STS   TWCR, R24
wait_read_ack:
    LDS   R24, TWCR
    SBRS  R24, TWINT
    RJMP  wait_read_ack
    LDS   R24, TWDR
    RET

i2c_read_nack:
    LDI   R24, (1<<TWINT)|(1<<TWEN)
    STS   TWCR, R24
wait_read_nack:
    LDS   R24, TWCR
    SBRS  R24, TWINT
    RJMP  wait_read_nack
    LDS   R24, TWDR
    RET

i2c_stop:
    LDI   R24, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
    STS   TWCR, R24
    RET

;==============================================================
; SPI Communication with MAX7219
;==============================================================
spi_send:
    CBI   PORTB, 2       ; SS low (PB2)
    OUT   SPDR, R24      ; Send command
wait_spi1:
    IN    R25, SPSR
    SBRS  R25, SPIF
    RJMP  wait_spi1
    OUT   SPDR, R25      ; Send data
wait_spi2:
    IN    R25, SPSR
    SBRS  R25, SPIF
    RJMP  wait_spi2
    SBI   PORTB, 2       ; SS high
    RET

;==============================================================
; Display Time on MAX7219
;==============================================================
display_time:
    ; Display hours (digit 7-8)
    LDS   R24, current_time
    RCALL bin_to_bcd
    MOV   R25, R24
    ANDI  R25, 0x0F
    LDI   R26, 0x08      ; Digit 8
    RCALL display_digit
    
    MOV   R25, R24
    SWAP  R25
    ANDI  R25, 0x0F
    LDI   R26, 0x07      ; Digit 7
    RCALL display_digit
    
    ; Display colon
    LDI   R25, 0x0A      ; Colon pattern
    LDI   R26, 0x06
    RCALL display_digit
    
    ; Display minutes (digit 4-5)
    LDS   R24, current_time+1
    RCALL bin_to_bcd
    MOV   R25, R24
    ANDI  R25, 0x0F
    LDI   R26, 0x05      ; Digit 5
    RCALL display_digit
    
    MOV   R25, R24
    SWAP  R25
    ANDI  R25, 0x0F
    LDI   R26, 0x04      ; Digit 4
    RCALL display_digit
    
    ; Display colon
    LDI   R25, 0x0A      ; Colon pattern
    LDI   R26, 0x03
    RCALL display_digit
    
    ; Display seconds (digit 1-2)
    LDS   R24, current_time+2
    RCALL bin_to_bcd
    MOV   R25, R24
    ANDI  R25, 0x0F
    LDI   R26, 0x02      ; Digit 2
    RCALL display_digit
    
    MOV   R25, R24
    SWAP  R25
    ANDI  R25, 0x0F
    LDI   R26, 0x01      ; Digit 1
    RCALL display_digit
    
    RET

display_digit:
    ; R25 = digit value, R26 = digit position
    SWAP  R26            ; MAX7219 expects digit in upper nibble
    OR    R25, R26
    MOV   R26, R25
    SWAP  R26
    ANDI  R26, 0x0F
    SWAP  R25
    ANDI  R25, 0x0F
    RCALL spi_send
    RET

;==============================================================
; Conversion Routines
;==============================================================
bcd_to_bin:
    ; Convert BCD in R24 to binary
    MOV   R25, R24
    ANDI  R25, 0x0F      ; Lower nibble
    SWAP  R24
    ANDI  R24, 0x0F      ; Upper nibble
    LDI   R26, 10
    MUL   R24, R26       ; Tens digit * 10
    ADD   R0, R25        ; Add units digit
    MOV   R24, R0
    RET

bin_to_bcd:
    ; Convert binary in R24 to BCD
    CLR   R25            ; Result
    LDI   R26, 16        ; 16 bits
bin2bcd_loop:
    LSL   R24            ; Shift input
    ROL   R25            ; Shift result
    
    ; Check lower nibble
    MOV   R27, R25
    ANDI  R27, 0x0F
    CPI   R27, 5
    BRLO  no_adj1
    SUBI  R25, -3        ; Add 3 to lower nibble
no_adj1:
    
    ; Check upper nibble
    MOV   R27, R25
    ANDI  R27, 0xF0
    CPI   R27, 0x50
    BRLO  no_adj2
    SUBI  R25, -0x30     ; Add 3 to upper nibble
no_adj2:
    
    DEC   R26
    BRNE  bin2bcd_loop
    MOV   R24, R25
    RET

;==============================================================
; Serial Print Subroutines
;==============================================================
print_string:
    ; Z points to string
print_loop:
    LPM   R24, Z+
    CPI   R24, 0
    BREQ  print_done
    RCALL serial_tx
    RJMP  print_loop
print_done:
    RET

serial_tx:
    PUSH  R25
tx_wait:
    LDS   R25, UCSR0A
    SBRS  R25, UDRE0
    RJMP  tx_wait
    STS   UDR0, R24
    POP   R25
    RET

;==============================================================
; Delay Subroutines
;==============================================================
delay_20ms:
    LDI   R24, 200
delay_outer:
    LDI   R25, 250
delay_inner:
    NOP
    NOP
    DEC   R25
    BRNE  delay_inner
    DEC   R24
    BRNE  delay_outer
    RET

delay_1s:
    LDI   R24, 100
delay_1s_loop:
    RCALL delay_10ms
    DEC   R24
    BRNE  delay_1s_loop
    RET

delay_10ms:
    LDI   R24, 100
delay_10ms_loop:
    NOP
    NOP
    DEC   R24
    BRNE  delay_10ms_loop
    RET