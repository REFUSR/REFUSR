#define PLC_DONE 8 
/*#define PLC_NEXT 10 */
#define PLC_SYNC 7 /* Was CLK */
#define SYNC_LED 9
#define PLC_DONE_LED 12
#define PLC_RESULT 10 /* Was 11 */
#define PLC_OUTBIT 11 /*Was 13 */

int ixo_pin[5] = {2,3,4,5,6};

int data[5] = {0,0,0,0,0};
 
int tick=LOW;

int result_val=0;
int bitcount=0;

void setup() {

randomSeed(analogRead(0));

for (int i =0; i < 4;i++) { 
      pinMode(ixo_pin[i],OUTPUT);
}

pinMode(PLC_DONE,INPUT); 
//pinMode(PLC_NEXT,INPUT);
pinMode(PLC_RESULT,INPUT);

pinMode(PLC_SYNC,INPUT);
pinMode(SYNC_LED,OUTPUT);
pinMode(PLC_OUTBIT, OUTPUT);

Serial.begin(9600);

delay(100);

}

void loop() {
    Serial.print("Sending:");
           for (int i=0; i < 5;i++) { 
                int rand_int=random(32);
                int shifted=rand_int >> i; 
                data[i]=shifted & 1;
                Serial.print(data[i]);
                Serial.print(" ");
                digitalWrite(ixo_pin[i],data[i]);
           }
        Serial.println();
        //pinMode(PLC_SYNC,INPUT);
        delay(100);

   pinMode(PLC_DONE,INPUT);
   pinMode(PLC_OUTBIT,OUTPUT);
    
  if (digitalRead(PLC_DONE) == HIGH) { 
    digitalWrite(PLC_DONE_LED,HIGH);
    result_val=digitalRead(PLC_RESULT);
    Serial.print("Recovered value from PLC:");
    Serial.println(result_val);
    digitalWrite(PLC_OUTBIT,result_val);

    delay(500);
    pinMode(PLC_DONE,OUTPUT);
    digitalWrite(PLC_DONE_LED,LOW);
    digitalWrite(PLC_OUTBIT,LOW);
  } else { 
    digitalWrite(PLC_DONE_LED,LOW);
  } 
}
