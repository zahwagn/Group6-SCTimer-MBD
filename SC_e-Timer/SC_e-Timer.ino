extern "C" {
  void system_init();
  void keypad_auth();
  void check_time_limit();
  void display_time();
  void setup_peripherals();
}

void setup() {
  setup_peripherals();
  system_init();
  Serial.begin(9600);  // Inisialisasi serial Arduino
}

void loop() {
  keypad_auth();
  check_time_limit();
  display_time();
  delay(100);
}