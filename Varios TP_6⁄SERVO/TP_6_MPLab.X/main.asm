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
P-DI	     EQU 0X29    ; Variable para determinar si me muevo a la derecha o izquierda
P-UD	     EQU 0X30	 ; Variable para determinar si me muevo arriba o abajo
DIFF	     EQU 0X31    ; Variable para analizar la diferencia de los resultados del ADC 

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
; FALTA CNFIGURAR EL PIN DE SALIDA PARA EL PULSO DEL SERVOMOTOR
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
    MOVLW b'00101011'	  
    MOVWF ADCON0	 ; Habilito ADC, GO/DONDE, Arranco convirtiendo RB1 (AN10), FOSC/2
    
    ;TMR0
    BANKSEL TRISC        ; Banco 1 
    MOVLW B'10000111'    
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
    
    CLRF PORTC
    CLRF PORTD
    
    MOVLW .178
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
    
    CALL VERIFICAR_DI
    
    
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
    MOVLW .178
    MOVWF TMR0				;Precargo TMR0 con .178 para la proxima interrrupción
    BCF INTCON, T0IF
    
;    ; Multiplexado de displays
;    CALL MULTIPLEXAR
;    RETURN
;    
;;Multiplexar
;    MULTIPLEXAR
;    ; Apagar todos los displays primero
;    MOVLW 0x00
;    MOVWF PORTC
;    
;    ; Seleccionar display según contT
;    MOVF contT, W
;    CALL TABLA_MUX
;    MOVWF PORTC        
;    
;    ; Mostrar dígito correspondiente
;    CALL MOSTRAR_DIGITO
;    
;    ; Incrementar contador de multiplexado (0-3). Reinicia cuando >=4
;    INCF contT, F
;    MOVLW .4
;    SUBWF contT, W
;    BTFSS STATUS, C
;    RETURN
;    CLRF contT
;    RETURN
;    
;;Mostrar Digito
;    MOSTRAR_DIGITO
;    ; Alineamos contT con TABLA_MUX:
;    ; contT = 0 -> centenas
;    ; contT = 1 -> decenas
;    ; contT = 2 -> unidades
;    MOVF contT, W
;    XORLW 0
;    BTFSC STATUS, Z
;    GOTO MOSTRAR_UNIDADES
;    MOVF contT, W
;    XORLW 1
;    BTFSC STATUS, Z
;    GOTO MOSTRAR_DECENAS
;    GOTO MOSTRAR_CENTENAS
;
;MOSTRAR_CENTENAS
;    MOVF digito2, W
;    GOTO FIN_MOSTRAR
;
;MOSTRAR_DECENAS
;    MOVF digito1, W
;    GOTO FIN_MOSTRAR
;
;MOSTRAR_UNIDADES
;    MOVF digito0, W
;    
;FIN_MOSTRAR
;    CALL TABLA_D
;    MOVWF PORTD
;    RETURN
   
    
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
    MOVLW b'00101011'		    ;B2-B5 seleccionan que AN se convierte (ver datasheet)
    MOVWF ADCON0
    RETURN
    
    SELECCIONAR_AN8
    MOVLW b'00100011'
    MOVWF ADCON0
    RETURN
    
    SELECCIONAR_AN9
    MOVLW b'00100111'
    MOVWF ADCON0
    RETURN
    
    SELECCIONAR_AN11
    MOVLW b'00101111'
    MOVWF ADCON0
    RETURN
    
    VERIFICAR_DI
    MOVF ADC1,W
    SUBWF ADC0,DIFF			    ; DIFF = ADC0 - ADC1
    BTFSC STATUS,C
    GOTO POSITIVO_I			    ;C = 1, Resultado positivo, me muevo a la izquierda
    GOTO NEGATIVO_D			    ;C = 0, Resultado negativo, me muevo a la derecha
    
    POSITIVO_I
    MOVFW DIFF,W
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
    
;    ;Leer ADC
;LEER_ADC
;    BANKSEL ADCON0
;    ; Esperar a que no haya conversión en curso (GO/DONE = 0)
;WAIT_NO_CONV:
;    BTFSC ADCON0, GO_DONE
;    GOTO WAIT_NO_CONV
;    
;    ; Retardo de adquisición para que el capacitor del S/H se cargue
;    CALL RETARDO_100US
;    
;    ; Iniciar nueva conversión
;    BSF ADCON0, GO_DONE
;    
;    ; Esperar a que termine la conversión
;ESPERAR_CONVERSION:
;    BTFSC ADCON0, GO_DONE
;    GOTO ESPERAR_CONVERSION
;    
;    ; Leer resultado (8 bits - justificado a izquierda)
;    MOVF ADRESH, W
;    MOVWF valor_adc
;    
;    BANKSEL 0
;    RETURN
;   
;;CONVERTIR_DIGITOS
;CONVERTIR_DIGITOS
;    ; Cargar valor ADC en temp
;    MOVF valor_adc, W
;    MOVWF temp
;    
;    ; Verificar si es >= 200
;    MOVF temp, W
;    SUBLW .199          ; si temp > 199 => C = 0 (SUBLW hace W = K - W)
;    BTFSC STATUS, C
;    GOTO CHECK_100      ; Si temp <= 199, verificar 100
;    
;    ; Es >= 200
;    MOVLW .2
;    MOVWF digito2
;    MOVLW .200
;    SUBWF temp, F
;    GOTO CALC_DECENAS
;
;CHECK_100
;    ; Verificar si es >= 100
;    MOVF temp, W
;    SUBLW .99
;    BTFSC STATUS, C
;    GOTO CALC_DECENAS   ; Si temp <= 99, ir a decenas
;    
;    ; Es >= 100
;    MOVLW .1
;    MOVWF digito2
;    MOVLW .100
;    SUBWF temp, F
;
;CALC_DECENAS
;    ; CALCULAR DECENAS - método por bloques (tu aproximación)
;    ; Se prueban 9,8,...,1 decenas y se resta la cantidad correspondiente
;    MOVF temp, W
;    SUBLW .89
;    BTFSC STATUS, C
;    GOTO CHECK_80   
;    MOVLW .9
;    MOVWF digito1
;    MOVLW .90
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CHECK_80
;    MOVF temp, W
;    SUBLW .79
;    BTFSC STATUS, C
;    GOTO CHECK_70   
;    MOVLW .8
;    MOVWF digito1
;    MOVLW .80
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CHECK_70
;    MOVF temp, W
;    SUBLW .69
;    BTFSC STATUS, C
;    GOTO CHECK_60   
;    MOVLW .7
;    MOVWF digito1
;    MOVLW .70
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CHECK_60 
;    MOVF temp, W
;    SUBLW .59           
;    BTFSC STATUS, C
;    GOTO CHECK_50   
;    MOVLW .6
;    MOVWF digito1
;    MOVLW .60
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CHECK_50
;    MOVF temp, W
;    SUBLW .49           
;    BTFSC STATUS, C
;    GOTO CHECK_40   
;    MOVLW .5
;    MOVWF digito1
;    MOVLW .50
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CHECK_40 
;    MOVF temp, W
;    SUBLW .39           
;    BTFSC STATUS, C
;    GOTO CHECK_30   
;    MOVLW .4
;    MOVWF digito1
;    MOVLW .40
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CHECK_30 
;    MOVF temp, W
;    SUBLW .29           
;    BTFSC STATUS, C
;    GOTO CHECK_20   
;    MOVLW .3
;    MOVWF digito1
;    MOVLW .30
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CHECK_20 
;    MOVF temp, W
;    SUBLW .19           
;    BTFSC STATUS, C
;    GOTO CHECK_10   
;    MOVLW .2
;    MOVWF digito1
;    MOVLW .20
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CHECK_10 
;    MOVF temp, W
;    SUBLW .9           
;    BTFSC STATUS, C
;    GOTO  CALC_UNIDADES
;    MOVLW .1
;    MOVWF digito1
;    MOVLW .10
;    SUBWF temp, F
;    GOTO CALC_UNIDADES
;    
;CALC_UNIDADES
;    ; CALCULAR UNIDADES - lo que queda en temp
;    MOVF temp, W
;    MOVWF digito0
;    
;    RETURN
 
    
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

    END