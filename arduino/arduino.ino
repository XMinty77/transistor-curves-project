const int PIN_VCE = A0;
const int PIN_VBE = A1;
const int PIN_VBB = A2;
const int PIN_VCC = A3;

// TODO: Implement binary communication protocol or at least figure out buffers

int VCE[64];
int* IC;
int* IB;
int* VBB;
int* VCC;

void setup() {
  delay(5000);
  Serial.begin(9600);

  while (!Serial);;

  IC = VCE + 4;
  IB = IC + 4;
  VBB = IB + 4;
  VCC = VBB + 4;
}

void loop() {
  *VCC = analogRead(PIN_VCC);
  *VCE = analogRead(PIN_VCE);
  *IC = (*VCC) - (*VCE);
  *VBB = analogRead(PIN_VBB);
  *IB = (*VBB) - analogRead(PIN_VBE);

  Serial.print(*VCE);
  Serial.print(",");
  Serial.print(*IC);
  Serial.print(",");
  Serial.print(*IB);
  Serial.print(",");
  Serial.print(*VBB);
  Serial.print(",");
  Serial.println(*VCC);

  delay(100);
}
