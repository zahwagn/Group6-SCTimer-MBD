//--------------------------------------
// Assembly via Arduino: RTC DS3231 Read
//--------------------------------------
extern "C"
{
  void SPI_MAX7219_init();
  void MAX7219_disp_text();
  void I2C_init();
  void DS3231_RD();
  void save_to_EEPROM();
  void keypad();
}
//-------------------------------------
void setup()
{
  SPI_MAX7219_init();
  MAX7219_disp_text();
  I2C_init();
  DS3231_RD();
}
//-------------------------------------
void loop() {}
