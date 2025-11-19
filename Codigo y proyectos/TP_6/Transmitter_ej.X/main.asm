; PIC16F887 Configuration Bit Settings
#include "p16f887.inc"

; CONFIG1
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

	CONTADOR1 EQU 0x20
        CONTADOR2 EQU 0x21
        CONTADOR3 EQU 0x22
    ORG	0
    GOTO	INICIO

    RETARDO_20MS
    MOVLW   .33         ; Carga 33 en W (primer contador)
    MOVWF   CONTADOR1   ; Mueve a CONTADOR1
    
    MOVLW   .118        ; Carga 118 en W (segundo contador)  
    MOVWF   CONTADOR2   ; Mueve a CONTADOR2
    
    MOVLW   .2          ; Carga 2 en W (tercer contador)
    MOVWF   CONTADOR3   ; Mueve a CONTADOR3
    
LOOP_EXTERNO
    MOVLW   .33         ; Recarga CONTADOR1 al inicio de cada ciclo externo
    MOVWF   CONTADOR1
    
LOOP_MEDIO
    MOVLW   .118        ; Recarga CONTADOR2 al inicio de cada ciclo medio
    MOVWF   CONTADOR2
    
LOOP_INTERNO
    DECFSZ  CONTADOR1,F ; Decrementa CONTADOR1, salta si es cero
    GOTO    LOOP_INTERNO
    
    DECFSZ  CONTADOR2,F ; Decrementa CONTADOR2, salta si es cero
    GOTO    LOOP_MEDIO
    
    DECFSZ  CONTADOR3,F ; Decrementa CONTADOR3, salta si es cero
    GOTO    LOOP_EXTERNO
    
    RETURN              ; Retorna de la subrutina
    
INICIO
    BSF	STATUS,RP0
    MOVLW	.31; BAUDIOS 9600
    MOVWF	SPBRG
    BCF	TXSTA,4; ASINCRONO
    BCF	TXSTA,2; LOW SPEED
    BCF	TXSTA,6; 8 BITS
    BSF	TXSTA,5; HABILITA TX
    BSF	PIE1,RCIE; HABILITA INT RX
    CLRF	TRISD; SALIDA
    BCF	STATUS,RP0
    BSF	RCSTA,7; RX Y TX
    BSF	RCSTA,4; HABILITA RX
    BCF	RCSTA,6; 8 BITS
    BCF	PIR1,RCIF; LIMPIAMOS FLAG RX
START
    BTFSS	PIR1,RCIF
    GOTO	START
    MOVF	RCREG,W; RCREG -> W
    XORLW	'W'; W XOR WREG -> 0 - STATUS,Z Z=1 
    BTFSS	STATUS,Z;             OPERACION 0
    GOTO	START
    MOVLW	'A'
    MOVWF	TXREG
    BCF	PIR1,RCIF; APAGO INT RX
    CALL    RETARDO_20MS
    GOTO	START
		
    END
	
	