; PIC16F887 Configuration Bit Settings
#include "p16f887.inc"

; CONFIG1
 __CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
 __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF
 
    ORG 0X00
    GOTO INICIO
    ORG 0X04
    GOTO ISR
    ORG 0X05
    
; Variables para displays
contT        EQU 0x20    ; Contador para multiplexado
d0	     EQU 0x21    ; DISPLAY 0 --> LDR0
d1	     EQU 0x22    ; DISPLAY 1 --> LDR1
d2	     EQU 0x23    ; DISPLAY 2 --> LDR2
d3	     EQU 0X24    ; DISPLAY 3 --> LDR3
ADC0	     EQU 0X25    ; Valor digital de RB1 --> LDR0
ADC1	     EQU 0X26	 ; Valor digital de RB2 --> LDR1   
ADC2	     EQU 0X27	 ; Valor digital de RB3 --> LDR2
ADC3	     EQU 0X28	 ; Valor digital de RB4 --> LDR3
P_DI	     EQU 0X29    ; Variable para determinar si me muevo a la derecha o izquierda
P_UD	     EQU 0X30	 ; Variable para determinar si me muevo arriba o abajo
DIFF	     EQU 0X31    ; Variable para analizar la diferencia de los resultados del ADC 
temp	     EQU 0x32    ; Variable de los retardos
SP	     EQU 0X33	 ; Posicion

W_TEMP       EQU 0x70	 ; CONTEXTO
STATUS_TEMP  EQU 0x71	 ; CONTEXTO
  
; ======================
; NOTAS IMPORTANTES
; RB1(AN10) , RB2(AN8) , RB3 (AN9) , RB4(AN11)
; Hasta ahora está implementado: ADC
; Falta implementar: COMUNICACIÓN SERIE
; ======================

  
  
INICIO
; ======================
; Configuracion de Puertos 
; FALTA CONFIGURAR EL PIN DE SALIDA PARA EL PULSO DEL SERVOMOTOR
; ======================
    ;PORTB
    BANKSEL SRCON        ; Banco 3
    MOVLW b'01111111'	
    MOVWF TRISB		 ; RB0 entrada (pulsador), RB1,2,3,4 entradas (LDR), RB6,7 entradas (SW cambios de estado en PORTB)
    MOVLW b'00001111'
    MOVWF ANSELH	 ; RB1,2,3,4 analógicos
    CLRF  ANSEL          ; Resto de PORTB en digital
    
    ;PORTD, PORTC
    BANKSEL TRISD        ; Banco 1
    CLRF TRISD           ; PORTD como salida (displays)
    MOVLW b'11000000'    
    MOVWF TRISC		 ; RC0-RC3 como salida digital (multiplexado), RC4,5 como salida digital (Servos) - FALTA DEFINIR COMUNICACION SERIE.
    
    
; ======================
; Interrupciones, ADC, TMR0   
; ======================
    ;ADC
    CLRF ADCON1		 ; Sigo en banco 1, voltajes de referencia PIC, Justificación IZQUIERDA (ADRESH)
    
    BANKSEL ADCON0	 ; Banco 0
    MOVLW b'01101001'	  
    MOVWF ADCON0	 ; Habilito ADC, GO/DONE DESHABILITADO, Arranco convirtiendo RB1 (AN10), FOSC/2
    
    ;TMR0
    BANKSEL TRISC        ; Banco 1 
    MOVLW B'10000000'    
    MOVWF OPTION_REG	 ; Prescaler 1:256 para Timer0, fuente interna
 
    ;INTERRUPCIONES
    MOVLW b'10101000'
    MOVWF INTCON	 ; Habilito interrupciones por cambios en PORTB y de TMR0. Bajo las banderas.
    
    BANKSEL PORTA        ; Banco 0
    
    ;Inicialización de variables, puertos, TMR0 y espera ADC
    CLRF contT       
    CLRF d0	     
    CLRF d1	    
    CLRF d2	     
    CLRF d3	     
    CLRF ADC0	    
    CLRF ADC1	        
    CLRF ADC2	
    CLRF ADC3
    CLRF DIFF
    CLRF P_DI
    CLRF P_UD
    CLRF SP
    
    CLRF PORTC
    CLRF PORTD
    
    MOVLW .125
    MOVWF TMR0		 ; Precargo TMR0 con 178, PS 1:256, Interrumpe cada aprox. 20mS
    
    CALL RETARDO_1MS     ; Espera ADC
    
    GOTO LOOP_PRINCIPAL
     
    
; ======================
; LOOP PRINCIPAL   
; ======================
    LOOP_PRINCIPAL
    BANKSEL ADCON0			;Banco 0, tambien donde tengo las variables de cada LDR, no hace falta moverse
    ;Canal RB1 (AN10)
    CALL SELECCIONAR_AN10
    CALL INICIAR_CONVERSION
    CALL ESPERAR_CONVERSION    
    MOVF ADRESH, W			;Justificación izquierda, solo tomamos los 8 bits mas significativos de los 10.
    MOVWF ADC0
    
    ;Canal RB2 (AN8)
    CALL SELECCIONAR_AN8
    CALL INICIAR_CONVERSION
    CALL ESPERAR_CONVERSION    
    MOVF ADRESH, W
    MOVWF ADC1

    ;Canal RB3 (AN9)
    CALL SELECCIONAR_AN9
    CALL INICIAR_CONVERSION
    CALL ESPERAR_CONVERSION   
    MOVF ADRESH, W
    MOVWF ADC2

    ;Canal RB4 (AN11)
    CALL SELECCIONAR_AN11
    CALL INICIAR_CONVERSION
    CALL ESPERAR_CONVERSION
    MOVF ADRESH, W
    MOVWF ADC3
    
    ;CALL VERIFICAR_DI			;De esta rutina, se vuelve con la posición en P_DI que corresponde en el servo del eje x.
    CALL P4
    ;CALL DELAY5S
    ;CALL P0
    ;CALL DELAY5S
    ;CALL P2 
    ;CALL DELAY5S
    ;CALL P3
    
;    ;Convertir valor ADC a dígitos
;    CALL CONVERTIR_DIGITOS
;    
;    ;Pequeño retardo entre lecturas (opcional)
;    CALL RETARDO_100US
    
    GOTO LOOP_PRINCIPAL
     
    
; ======================
; ISR  
; ======================
    ISR
    MOVWF W_TEMP
    SWAPF STATUS, W
    MOVWF STATUS_TEMP
    
    BTFSC INTCON, T0IF
    CALL TIMER_ISR
    
    SWAPF STATUS_TEMP, W
    MOVWF STATUS
    SWAPF W_TEMP, F
    SWAPF W_TEMP, W
    RETFIE

    
; ==========================
; SUBRUTINAS DE ISR
; ==========================    
;Subrutina TMR0
    TIMER_ISR
    MOVLW .125
    MOVWF TMR0				;Precargo TMR0 con .178 para la proxima interrrupción
    BCF INTCON, T0IF
    INCF SP
    RETURN

   
    
; =============================
; SUBRUTINAS DE LOOP PRINCIPAL
; =============================  
    INICIAR_CONVERSION
    BSF ADCON0,1		    ;Activo GO/DONE, arranca la conversión
    RETURN
    
    ESPERAR_CONVERSION		    
    BTFSC ADCON0,1
    GOTO ESPERAR_CONVERSION	    ;GO/DONE = 1, no terminó la conversión, vuelvo al loop
    RETURN			    ;GO/DONE = 0, terminó la conversión, vuelvo al LOOP_PRINCIPAL
    
    SELECCIONAR_AN10
    MOVLW b'01101001'		    ;B2-B5 seleccionan que AN se convierte (ver datasheet)
    MOVWF ADCON0
    RETURN
    
    SELECCIONAR_AN8
    MOVLW b'01100001'
    MOVWF ADCON0
    RETURN
    
    SELECCIONAR_AN9
    MOVLW b'01100101'
    MOVWF ADCON0
    RETURN
    
    SELECCIONAR_AN11
    MOVLW b'01101101'
    MOVWF ADCON0
    RETURN
    
    VERIFICAR_DI
    MOVF ADC1,W
    SUBWF ADC0,DIFF			    ; DIFF = ADC0 - ADC1
    BTFSC STATUS,C
    GOTO POSITIVO_I			    ;C = 1, Resultado positivo, me muevo a la izquierda
    GOTO NEGATIVO_D			    ;C = 0, Resultado negativo, me muevo a la derecha
    
    POSITIVO_I
    MOVF DIFF,W
    SUBLW .50
    BTFSC STATUS,C			    
    GOTO POS_0				    ;C = 1, DIFF <= 50, Rango de la posición 0
    MOVF DIFF,W				    ;C = 0, DIFF > 50, Verifico rango posición 1
    SUBLW .101
    BTFSC STATUS,C
    GOTO POS_1				    ;C = 1, DIFF <= 101, Rango de posición 1
    GOTO POS_2				    ;C = 0, DIFF > 101, Rango de posición 2
    
    NEGATIVO_D				    ;ESTE PODRIA ESTAR MAL (HACE FALTA TESTEAR CON EL CIRCUITO)
    COMF DIFF, F
    INCF DIFF, F			    ;Tomo valor absoluto
    
    MOVF DIFF, W
    SUBLW .50
    BTFSC STATUS, C
    GOTO POS_3				    ;C = 1, DIFF <= 50, Rango de la posición 3
    MOVF DIFF, W			    ;C = 0, DIFF > 50, Verifico rango posición 4
    SUBLW .101
    BTFSC STATUS, C
    GOTO POS_4				    ;C = 1, DIFF <= 101, Rango de posición 4
    GOTO POS_2				    ;C = 0, DIFF > 101, Rango de posición 2
    
    POS_0
    MOVLW .0
    MOVWF P_DI
    RETURN
    
    POS_1
    MOVLW .1
    MOVWF P_DI
    RETURN
    
    POS_2
    MOVLW .2
    MOVWF P_DI
    RETURN
    
    POS_3
    MOVLW .3
    MOVWF P_DI
    RETURN
    
    POS_4
    MOVLW .4
    MOVWF P_DI
    RETURN
    
    VERIFICARP
    MOVF ADC1,W
    SUBLW .150
    BTFSC STATUS,C
    GOTO P4
    GOTO P2
    
    P0
    MOVF SP,W
    SUBLW .10
    BTFSC STATUS,C
    GOTO SETP0
    BTFSS STATUS,C
    BCF PORTC,4
    CALL ESPERA20
    RETURN
    
    SETP0
    BSF PORTC,4
    GOTO P0
    
    P1
    MOVF SP,W
    SUBLW .8
    BTFSC STATUS,C
    GOTO SETP1
    BTFSS STATUS,C
    BCF PORTC,4
    CALL ESPERA20
    RETURN
    
    SETP1
    BSF PORTC,4
    GOTO P1
    
    P2
    MOVF SP,W
    SUBLW .6
    BTFSC STATUS,C
    GOTO SETP2
    BTFSS STATUS,C
    BCF PORTC,4
    CALL ESPERA20
    RETURN
    
    SETP2
    BSF PORTC,4
    GOTO P2
    
    P3
    MOVF SP,W
    SUBLW .4
    BTFSC STATUS,C
    GOTO SETP3
    BTFSS STATUS,C
    BCF PORTC,4
    CALL ESPERA20
    RETURN
    
    SETP3
    BSF PORTC,4
    GOTO P3
    
    P4
    MOVF SP,W
    SUBLW .12
    BTFSC STATUS,C
    GOTO SETP4
    BTFSS STATUS,C
    BCF PORTC,4
    CALL ESPERA20
    RETURN
    
    SETP4
    BSF PORTC,4
    GOTO P4
    
    ESPERA20
    SUBLW .80
    BTFSS STATUS,Z
    GOTO ESPERA20
    CLRF SP
    RETURN
    
; ======================
; TABLAS
; ======================    
;Tabla del Display
TABLA_D
    ADDWF PCL, F
    RETLW b'00111111'   ; 0
    RETLW b'00000110'   ; 1
    RETLW b'01011011'   ; 2
    RETLW b'01001111'   ; 3
    RETLW b'01100110'   ; 4
    RETLW b'01101101'   ; 5
    RETLW b'01111101'   ; 6
    RETLW b'00000111'   ; 7
    RETLW b'01111111'   ; 8
    RETLW b'01101111'   ; 9
    RETLW b'00000000'   ; Apagado

;Tabla de multiplexado
TABLA_MUX
    ADDWF PCL, F
    RETLW b'00000001'   ; Display 1 (RC0) - Centenas
    RETLW b'00000010'   ; Display 2 (RC1) - Decenas  
    RETLW b'00000100'   ; Display 3 (RC2) - Unidades
    RETLW b'00000000'   ; Display 4 (RC3) - Apagado  

    
; ======================
; Retardos
; ======================
RETARDO_100US
    MOVLW .33
    MOVWF temp
RET_100_LOOP
    DECFSZ temp, F
    GOTO RET_100_LOOP
    RETURN

RETARDO_1MS
    MOVLW .250
    MOVWF temp
RET_1MS_LOOP
    DECFSZ temp, F
    GOTO RET_1MS_LOOP
    RETURN
    
DELAY5S
    MOVLW   .250
    MOVWF   temp
RET_5S_LOOP
    DECFSZ  temp, F
    GOTO    RET_5S_LOOP
    MOVLW   .250
    MOVWF   temp
    DECFSZ  temp, F
    GOTO    $-4        
    MOVLW   .250
    MOVWF   temp
    DECFSZ  temp, F
    GOTO    $-4
    MOVLW   .250
    MOVWF   temp
    DECFSZ  temp, F
    GOTO    $-4
    MOVLW   .250
    MOVWF   temp
    DECFSZ  temp, F
    RETURN
    


    END