#define PLC_READY 8  /* Pi */
#define PLC_NEXT 10 /* Pi */
#define PLC_CLK 7 /* Pi */ 
#define CLK_LED 9
#define PLC_RESULT 11

int ixo_pin[5] = {2,3,4,5,6};

int data[5] = {0,0,0,0,0};
 
int tick=LOW;

int result_val=0;

void setup() {

randomSeed(analogRead(0));

for (int i =0; i < 4;i++) { 
      pinMode(ixo_pin[i],OUTPUT);
}
pinMode(PLC_READY,INPUT); 
pinMode(PLC_NEXT,INPUT_PULLUP);
pinMode(PLC_RESULT,INPUT);

digitalWrite(PLC_READY,LOW);
digitalWrite(PLC_NEXT,LOW);
digitalWrite(PLC_RESULT,LOW);

pinMode(PLC_CLK,OUTPUT);
pinMode(CLK_LED,OUTPUT);

Serial.begin(9600);

delay(100);

}

void loop() {

  tick = !tick;
  digitalWrite(PLC_CLK,tick);
  digitalWrite(CLK_LED,tick);
  
  if (digitalRead(PLC_NEXT)== HIGH) { 
    Serial.println("PLC Ready for bits!");
    Serial.print("Sending:");
      // for (int c=0; c < 4;c++) { 
           for (int i=0; i < 5;i++) { 
                int rand_int=random(32);
                int shifted=rand_int >> i; 
             //   Serial.print(shifted);
             //   Serial.print(" ");
                data[i]=shifted & 1;
                Serial.print(data[i]);
                Serial.print(" ");
                digitalWrite(ixo_pin[i],data[i]);
           }
        //}
        Serial.println();
  } else {
    Serial.println("PLC Computing...");
    for (int i =0; i < 4;i++) { 
      digitalWrite(ixo_pin[i],0);
    }
}
  delay(100);

  if (digitalRead(PLC_READY) == HIGH) { 
    digitalWrite(12,HIGH);
    result_val=digitalRead(PLC_RESULT);
    Serial.print("Recovered value from PLC:");
    Serial.println(result_val);
    delay(100);
    digitalWrite(12,LOW);
  } else { 
    digitalWrite(12,LOW);
  } 
}
