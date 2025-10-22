;*********************************************************************************
;****************** CONFIGURACIÓN PARA PIC16F887 *********************************
;*********************************************************************************

#include "p16f887.inc"

; CONFIG1
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

;*********************************************************************************
;************************** DEFINICIÓN DE VARIABLES ******************************
;*********************************************************************************

    ; Variables en memoria común (accesible desde cualquier banco)
    W_TEMP      EQU 0x70
    STATUS_TEMP EQU 0x71
    
    ; Variables en banco 0
    POSM            EQU 0x20
    POSICION_SERVO  EQU 0x21
    POS_S1          EQU 0x22
    POS_S2          EQU 0x23
    CONTADOR1       EQU 0x24
    CONTADOR2       EQU 0x25
    CONTADOR3       EQU 0x26

;*********************************************************************************
;************************** DEFINICIÓN DE BITS ***********************************
;*********************************************************************************

SERVO_A     EQU 0    ; Bit 0 del PORTB
SERVO_B     EQU 1    ; Bit 1 del PORTB

INC_S1      EQU 0    ; Bit 0 del PORTA
DEC_S1      EQU 1    ; Bit 1 del PORTA  
INC_S2      EQU 2    ; Bit 2 del PORTA
DEC_S2      EQU 3    ; Bit 3 del PORTA

;*********************************************************************************
;****************** ORIGEN DE EJECUCION POSTERIOR AL RESET ***********************
;*********************************************************************************

    ORG 0x000           ; ORIGEN INICIO RESET
    GOTO INICIO         ; ME VOY A INICIO
    
    ORG 0x004           ; ORIGEN ISR (PIC16F887 solo tiene una dirección de interrupción)
ISR:
    MOVWF   W_TEMP      ; GUARDO W
    SWAPF   STATUS,W    ; GUARDO STATUS (sin afectar flags)
    MOVWF   STATUS_TEMP
    
    ; Aquí iría el código de manejo de interrupciones si fuera necesario
    
    SWAPF   STATUS_TEMP,W   ; RESTAURO STATUS
    MOVWF   STATUS
    SWAPF   W_TEMP,F    ; RESTAURO W
    SWAPF   W_TEMP,W
    RETFIE

;*********************************************************************************
;**************************CONFIGURACIÓN DE PUERTOS ******************************
;*********************************************************************************

INICIO:
    BANKSEL TRISA       ; BANK 1
    CLRF    ANSEL       ; TODAS DIGITALES
    CLRF    ANSELH
    
    MOVLW   0xFF
    MOVWF   TRISA       ; PORTA COMO ENTRADAS
    
    CLRF    TRISB       ; PORTB COMO SALIDAS (SERVOS)
    CLRF    TRISC       ; PORTC COMO SALIDAS
    
    BANKSEL PORTA       ; BANK 0
    CLRF    PORTA
    CLRF    PORTB
    CLRF    PORTC

;*********************************************************************************
;************************** INICIALIZACIÓN ***************************************
;*********************************************************************************

    CLRF    POS_S1                  ; LIMPIO POSICION SERVO 1
    CLRF    POS_S2                  ; LIMPIO POSICION SERVO 2
    BCF     PORTB, SERVO_A          ; APAGO BIT DE SERVO 1
    BCF     PORTB, SERVO_B          ; APAGO BIT DE SERVO 2

;*********************************************************************************
;************************** PROGRAMA PRINCIPAL ***********************************
;*********************************************************************************

PRINCIPAL:
    BTFSS   PORTA, INC_S1
    CALL    INC_POS1
    BTFSS   PORTA, DEC_S1
    CALL    DEC_POS1   
    
    BTFSS   PORTA, INC_S2
    CALL    INC_POS2
    BTFSS   PORTA, DEC_S2
    CALL    DEC_POS2
    
    CALL    EJECUTA_SERVO1
    CALL    EJECUTA_SERVO2
    
    GOTO    PRINCIPAL

;*********************************************************************************
;************************** RUTINAS DE SERVO 1 ***********************************
;*********************************************************************************

EJECUTA_SERVO1:
    MOVF    POS_S1,W
    MOVWF   POSICION_SERVO
    BSF     PORTB, SERVO_A          ; PRENDO SERVO
    CALL    RET_1ms                 ; PULSO MINIMO 1ms    

MOVIMIENTO_SERVO1:
    CALL    RET_SERVO               ; RETARDO DE 5.5 MICRO SEGUNDOS
    DECFSZ  POSICION_SERVO,F
    GOTO    MOVIMIENTO_SERVO1
    
    BCF     PORTB, SERVO_A
    
    ; Complemento para completar los 20ms
    MOVLW   .180
    SUBWF   POS_S1,W
    MOVWF   POSICION_SERVO
    
COMPLEMENTO_SERVO1:
    CALL    RET_SERVO
    DECFSZ  POSICION_SERVO,F
    GOTO    COMPLEMENTO_SERVO1
    
    CALL    RET_16ms
    RETURN

;*********************************************************************************
;************************** RUTINAS DE SERVO 2 ***********************************
;*********************************************************************************

EJECUTA_SERVO2:
    MOVF    POS_S2,W
    MOVWF   POSICION_SERVO
    BSF     PORTB, SERVO_B          ; PRENDO SERVO
    CALL    RET_1ms                 ; PULSO MINIMO 1ms    

MOVIMIENTO_SERVO2:
    CALL    RET_SERVO               ; RETARDO DE 5.5 MICRO SEGUNDOS
    DECFSZ  POSICION_SERVO,F
    GOTO    MOVIMIENTO_SERVO2
    
    BCF     PORTB, SERVO_B
    
    ; Complemento para completar los 20ms
    MOVLW   .180
    SUBWF   POS_S2,W
    MOVWF   POSICION_SERVO
    
COMPLEMENTO_SERVO2:
    CALL    RET_SERVO
    DECFSZ  POSICION_SERVO,F
    GOTO    COMPLEMENTO_SERVO2
    
    CALL    RET_16ms
    RETURN

;*********************************************************************************
;************************** CONTROL DE POSICIONES ********************************
;*********************************************************************************

INC_POS1:
    INCF    POS_S1,F
    MOVF    POS_S1,W
    XORLW   .181
    BTFSS   STATUS,Z
    RETURN
    MOVLW   .180
    MOVWF   POS_S1
    RETURN

DEC_POS1:
    DECF    POS_S1,F
    MOVF    POS_S1,W
    XORLW   .255
    BTFSS   STATUS,Z
    RETURN
    CLRF    POS_S1
    RETURN

INC_POS2:
    INCF    POS_S2,F
    MOVF    POS_S2,W
    XORLW   .181
    BTFSS   STATUS,Z
    RETURN
    MOVLW   .180
    MOVWF   POS_S2
    RETURN

DEC_POS2:
    DECF    POS_S2,F
    MOVF    POS_S2,W
    XORLW   .255
    BTFSS   STATUS,Z
    RETURN
    CLRF    POS_S2
    RETURN

;*********************************************************************************
;************************** RUTINAS DE RETARDO ***********************************
;*********************************************************************************

RET_1ms:
    ; Retardo de 1ms para cristal de 4MHz
    MOVLW   .250
    MOVWF   CONTADOR1
LOOP_1ms:
    NOP
    NOP
    NOP
    NOP
    DECFSZ  CONTADOR1,F
    GOTO    LOOP_1ms
    RETURN

RET_16ms:
    ; Retardo de 16ms
    MOVLW   .16
    MOVWF   CONTADOR2
LOOP_16ms:
    CALL    RET_1ms
    DECFSZ  CONTADOR2,F
    GOTO    LOOP_16ms
    RETURN

RET_SERVO:
    ; Retardo de ~5.5?s para cristal de 4MHz
    MOVLW   .6
    MOVWF   CONTADOR3
LOOP_SERVO:
    DECFSZ  CONTADOR3,F
    GOTO    LOOP_SERVO
    RETURN

RET_1s:
    ; Retardo de 1 segundo
    MOVLW   .250
    MOVWF   CONTADOR1
LOOP_1s_EXT:
    MOVLW   .250
    MOVWF   CONTADOR2
LOOP_1s_INT:
    MOVLW   .250
    MOVWF   CONTADOR3
LOOP_1s_INT2:
    DECFSZ  CONTADOR3,F
    GOTO    LOOP_1s_INT2
    DECFSZ  CONTADOR2,F
    GOTO    LOOP_1s_INT
    DECFSZ  CONTADOR1,F
    GOTO    LOOP_1s_EXT
    RETURN

;*********************************************************************************
;************************** FIN DEL PROGRAMA *************************************
;*********************************************************************************

    END