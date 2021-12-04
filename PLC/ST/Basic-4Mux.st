FUNCTION_BLOCK F_CollectInput
  VAR_EXTERNAL
    IN1 : BOOL;
    IN2 : BOOL;
    IN3 : BOOL;
    IN4 : BOOL;
    IN5 : BOOL;
    Debug : BOOL;
  END_VAR
  VAR_IN_OUT
      Data : ARRAY[1..20] OF BOOL;
  END_VAR
  VAR_OUTPUT
      Finished : BOOL := 0;
  END_VAR
  VAR
      j : USINT := 1;
  END_VAR
  WHILE j <= 20 DO
    Debug := 1;
    Data[j] := IN1;
    Data[j+1] := IN2;
    Data[j+2] := IN3;
    Data[j+3] := IN4;
    Data[j+4] := IN5;
    j := j + 5;
  END_WHILE;
  Finished := (j > 20);
END_FUNCTION_BLOCK

PROGRAM Boiler
  VAR_EXTERNAL
    OutReady : BOOL; 
    Out : BOOL;
    Debug : BOOL;
  END_VAR
  VAR
    Data  : ARRAY[1..20] OF BOOL;
    Ready : BOOL;
    Output : BOOL;
    CollectInput : F_CollectInput;
    OutTimer : TOF;
  END_VAR

  CollectInput();
  Debug := 0;
  Ready := CollectInput.Finished;
  IF Ready AND NOT OutReady THEN
    Output := (Data[2] AND (NOT Data[1]) OR Data[5]);
    OutReady := 1;
    OutTimer(IN := Output, PT := T#2000ms);
    Out := OutTimer.Q;
  END_IF;
END_PROGRAM


CONFIGURATION Config0
  VAR_GLOBAL
    IN1 AT %IX0.3 : BOOL;
    IN2 AT %IX0.4 : BOOL;
    IN3 AT %IX0.5 : BOOL;
    IN4 AT %IX0.6 : BOOL;
    IN5 AT %IX0.7 : BOOL;
    OutReady AT %QX0.2 : BOOL; 
    Out AT %QX0.0 : BOOL;
    Debug AT %QX1.2 : BOOL;
  END_VAR
  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#10000ms,PRIORITY := 0);
    PROGRAM instance0 WITH task0 : Boiler;
  END_RESOURCE
END_CONFIGURATION
