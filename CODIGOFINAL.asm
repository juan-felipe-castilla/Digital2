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
conT       EQU  0x20    ; Contador para multiplexado
CONTISR     EQU 0X30
RESP0       EQU 0x21   ; 
RESP1       EQU 0x22    ; 
d0	    EQU 0X34
d1          EQU 0X35
d2          EQU 0x23    ; DISPLAY 2 --> LDR2
d3          EQU 0X24    ; DISPLAY 3 --> LDR3
ADC0        EQU 0X25    ; Valor digital de RB1 --> LDR0
ADC1        EQU 0X26    ; Valor digital de RB2 --> LDR1    
P_DI        EQU 0X29    ; Variable para determinar si me muevo a la derecha o izquierda
DIFF        EQU 0X31    ; Variable para analizar la diferencia de los resultados del ADC  
temp        EQU 0x32    ; Variable de los retardos
SP          EQU 0X33    ; Posicion
valor_adc_raw EQU  0X27
temp_retardo  EQU  0x28	;NUEVOOOOO
PCS	    EQU 0X36

	  ;NUEVAS VARIABLES
VALOR_A_IZQ_LEVE  EQU .12   ; Índice para 'A'
VALOR_B_IZQ_FUERTE EQU .13   ; Índice para 'b'
VALOR_C_DER_LEVE  EQU .14   ; Índice para 'C'
VALOR_D_DER_FUERTE EQU .15   ; Índice para 'd'
	  ;
 
W_TEMP      EQU 0x70    ; CONTEXTO
STATUS_TEMP EQU 0x71    ; CONTEXTO
  
INICIO
;CONFIGURACION PUERTOS COMUNCIACION SERIE
   BANKSEL TRISD       ; Banco 1
   MOVLW b'10000000'   
   MOVWF TRISC         ; TRISC Configurado para comunicacion serie

   BANKSEL TXSTA
   BSF TXSTA, TXEN     ; Habilita TX
   BCF TXSTA, SYNC     ; Modo asíncrono
   BSF TXSTA, BRGH     ; Alta velocidad

   BANKSEL RCSTA
   BSF RCSTA, SPEN     ; Habilita TX (y RX si se quisiera)

   BANKSEL BAUDCTL
   BCF BAUDCTL, BRG16  ; Baudrate de 8 bits

   BANKSEL SPBRG 
   MOVLW .25           ; 9600 baud @ 4MHz (BRGH=1)
   MOVWF SPBRG
; ======================
; Configuracion de Puertos  
; ======================
    BANKSEL TRISA
    MOVLW b'00000011'    ; RA0 (AN0) y RA1 (AN1) como entradas
    MOVWF TRISA  
    
    BANKSEL ANSEL
    MOVLW b'00000011'    ; AN0 y AN1 como analógicos
    MOVWF ANSEL
    CLRF ANSELH          ; Resto de pines digitales
 
  ;PORTB
    BANKSEL SRCON       ; Banco 3
    MOVLW b'00000001'   
    MOVWF TRISB         ; RB0 entrada (pulsador), el resto salidas (PORTB MULTIPLEXADO) RB1,2,3,4 "MUX"
    
; ======================
; Interrupciones, ADC, TMR0    
; ======================
    ;ADC
    CLRF ADCON1         ; Sigo en banco 1, Justificación IZQUIERDA (ADRESH)
    
    BANKSEL ADCON0      ; Banco 0
    MOVLW b'01101001'   
    MOVWF ADCON0        ; Habilito ADC, GO/DONE DESHABILITADO, Arranco convirtiendo RB1 (AN10), FOSC/2
    
    ;TMR0
    BANKSEL TRISC       ; Banco 1  
    MOVLW B'00000000'   
    MOVWF OPTION_REG    ; Prescaler 1:256 para Timer0, fuente interna
    
    BANKSEL WPUB
    BSF WPUB,0
 
    ;INTERRUPCIONES
    MOVLW b'10110000'
    MOVWF INTCON        ; Habilito interrupciones EXTERNA RB0 y TMR0.
    
    BANKSEL PORTA       ; Banco 0
    
    ;Inicialización de variables, puertos, TMR0 y espera ADC
    CLRF conT      
    CLRF d0         
    CLRF d1        
    CLRF d2         
    CLRF d3         
    CLRF ADC0       
    CLRF ADC1         
    CLRF DIFF
    CLRF P_DI
    CLRF SP
    CLRF CONTISR
    CLRF PCS
    
    CLRF PORTC
    MOVLW b'00111111'
    MOVWF PORTD		;PORTD Siempre muestra un "0", el cual usaremos para indicar en los display en que posicion se encuentra (cambiamos solo el transistor)
    
    MOVLW .125
    MOVWF TMR0          ; Precargo TMR0 con 125, PS 1:256, Interrumpe cada aprox. 20mS
    
    CALL RETARDO_1MS    ; Espera ADC
    
    GOTO LOOP_PRINCIPAL
    
    
; ======================
; LOOP PRINCIPAL    
; ======================
LOOP_PRINCIPAL
    BSF PORTB,0
    BANKSEL ADCON0          ;Banco 0
    ;Canal RB1 (AN0)
    CALL SELECCIONAR_AN0
    CALL INICIAR_CONVERSION
    CALL ESPERAR_CONVERSION     
    MOVF ADRESH, W          
    MOVWF ADC0
    BSF PORTB,0
    ;Canal RB2 (AN1)
    CALL SELECCIONAR_AN1
    CALL INICIAR_CONVERSION
    CALL ESPERAR_CONVERSION     
    MOVF ADRESH, W
    MOVWF ADC1
    
    
   ;  -------------------------------------------------------
    ; PROCESAR ADC0 (LDR Izquierdo)
    ; -------------------------------------------------------
    MOVF ADC0, W            ; Cargar valor de ADC0 en W
    MOVWF valor_adc_raw     ; Moverlo a la variable que usa la subrutina
    CALL CALCULAR_CUADRANTE ; Llamar a la rutina
    MOVWF RESP0                ; Guardar el resultado (0-3) en d0
    
    ; -------------------------------------------------------
    ; PROCESAR ADC1 (LDR Derecho)
    ; -------------------------------------------------------
    MOVF ADC1, W            ; Cargar valor de ADC1 en W
    MOVWF valor_adc_raw     ; Sobrescribir la variable temporal con el nuevo valor
    CALL CALCULAR_CUADRANTE ; Reutilizar la misma rutina
    MOVWF RESP1 
    
 
    
    ; 1. Calcular Diferencia: LDR_DIFF = LDR1 - LDR2
    MOVF RESP1, W
    SUBWF RESP0, W    ; W = LDR1 - LDR2
    MOVWF DIFF

    
    ; 2. Chequear si es Cero (Zona Muerta)
    BTFSC STATUS, Z         ; 
    GOTO LOOP_PRINCIPAL     ; Si Z=0 (raro), no hago nada y voy a loop principal
    BTFSC STATUS, C         ; ¿Es C=1 (Positivo)? (LDR0 > LDR1)
    GOTO LDR0_MAYOR         
    GOTO LDR1_MAYOR
    
    LDR0_MAYOR ; (Sabemos que DIFF es 1, 2, o 3)
    MOVF DIFF, W
    XORLW .3                ; ¿Es la diferencia 3?
    BTFSC STATUS, Z         ; Si Z=1, es 3.
    GOTO IZQUIERDA_FUERTE
    MOVLW VALOR_A_IZQ_LEVE  ; Cargar 'A'
    GOTO SET_INDICADOR
    
    IZQUIERDA_FUERTE
    MOVLW VALOR_B_IZQ_FUERTE ; Cargar 'b'
    GOTO SET_INDICADOR
    
    LDR1_MAYOR ; (Sabemos que DIFF es -1, -2, o -3)
    COMF DIFF, W        ; W = C1 de DIFF (ej: C1 de -3 es 2)
    MOVWF temp_retardo      ; temp_retardo = 2
    INCF temp_retardo, W
    XORLW .3                ; ¿Es la diferencia 3?
    BTFSC STATUS, Z         ; Si Z=1, es 3.
    GOTO DERECHA_FUERTE     ; (Diferencia = 3)
    MOVLW VALOR_C_DER_LEVE  ; Cargar 'C'
    GOTO SET_INDICADOR
    
    DERECHA_FUERTE
    MOVLW VALOR_D_DER_FUERTE ; Cargar 'd'
    GOTO SET_INDICADOR
    
    SET_INDICADOR
    MOVWF P_DI		     ;P_DI tiene el valor de A,b,C,d,-, que es la posición qiue corresponde
    MOVF P_DI,W
    
    CALL PRENDERLED
    
    CALL VERIFICARP
    
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
    BTFSC INTCON, INTF
    CALL COM_SERIE
    
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
    MOVWF TMR0              ;Precargo TMR0 con .125 para la proxima interrrupción
    BCF INTCON, T0IF
    INCF SP
    INCF CONTISR
    RETURN
    
COM_SERIE
   BCF  INTCON, INTF
   CALL CARGAR_POSICION
   CALL TABLE_OUT_SERIAL   ; -> ASCII en W
   CALL UART_TX
   RETURN

CARGAR_POSICION
    MOVF P_DI, W
    SUBLW .13		;VERIFICO P0 (DEBERIA SER P0, NO LO ES EN REALIDAD)
    BTFSC STATUS,Z
    GOTO PONERP0
    MOVF P_DI,W
    SUBLW .12		;VERIFICO P1
    BTFSC STATUS,Z
    GOTO PONERP1
    MOVF P_DI,W
    SUBLW .14		;VERIFICO P2
    BTFSC STATUS,Z
    GOTO PONERP2
    GOTO PONERP3
    
PONERP0
    MOVLW .0
    RETURN
PONERP1
    MOVLW .1
    RETURN
PONERP2
    MOVLW .2
    RETURN
PONERP3
    MOVLW .3
    RETURN
    
UART_TX
   BANKSEL TXSTA
WAIT_TX
   BTFSS TXSTA, TRMT
   GOTO WAIT_TX
   BANKSEL TXREG
   MOVWF TXREG
   RETURN
    
; =============================
; SUBRUTINAS DE LOOP PRINCIPAL
; =============================   
INICIAR_CONVERSION
    BSF ADCON0,1            ;Activo GO/DONE, arranca la conversión
    RETURN
    
ESPERAR_CONVERSION      
    BTFSC ADCON0,1
    GOTO ESPERAR_CONVERSION     ;GO/DONE = 1, no terminó la conversión
    RETURN                      ;GO/DONE = 0, terminó la conversión
    
SELECCIONAR_AN0
    MOVLW b'01000001'           ;B2-B5 seleccionan que AN se convierte
    MOVWF ADCON0
    RETURN
    
SELECCIONAR_AN1
    MOVLW b'01000101'
    MOVWF ADCON0
    RETURN
    
CALCULAR_CUADRANTE
    BTFSC valor_adc_raw, 7
    GOTO CHK_B7_ES_1
CHK_B7_ES_0
    BTFSC valor_adc_raw, 6
    GOTO SET_W_1
    RETLW .0            ; Caso 0 (0-63)
SET_W_1
    RETLW .1            ; Caso 1 (64-127)
CHK_B7_ES_1
    BTFSC valor_adc_raw, 6
    GOTO SET_W_3
    RETLW .2            ; Caso 2 (128-191)
SET_W_3
    RETLW .3            ; Caso 3 (192-255)
    
VERIFICARP
    MOVF P_DI, W
    SUBLW .13
    BTFSC STATUS,Z
    GOTO P0
    MOVF P_DI,W
    SUBLW .12
    BTFSC STATUS,Z
    GOTO P1
    MOVF P_DI,W
    SUBLW .14
    BTFSC STATUS,Z
    GOTO P2
    GOTO P3
    
; --- RUTINAS DE SERVO CORREGIDAS PARA USAR RC5 ---
P0
    MOVF SP,W
    SUBLW .9
    BTFSC STATUS,C
    GOTO SETP0
    BTFSS STATUS,C
    BCF PORTC,5             ; Usa RC5
    CALL ESPERA20
    RETURN
    
SETP0
    BSF PORTC,5             ; Usa RC5
    GOTO P0
    
P1
    MOVF SP,W
    SUBLW .7
    BTFSC STATUS,C
    GOTO SETP1
    BTFSS STATUS,C
    BCF PORTC,5             ; CORREGIDO: Usa RC5
    CALL ESPERA20
    RETURN
    
SETP1
    BSF PORTC,5             ; CORREGIDO: Usa RC5
    GOTO P1
    
P2
    MOVF SP,W
    SUBLW .5
    BTFSC STATUS,C
    GOTO SETP2
    BTFSS STATUS,C
    BCF PORTC,5             ; CORREGIDO: Usa RC5
    CALL ESPERA20
    RETURN
    
SETP2
    BSF PORTC,5             ; CORREGIDO: Usa RC5
    GOTO P2
    
P3
    MOVF SP,W
    SUBLW .3
    BTFSC STATUS,C
    GOTO SETP3
    BTFSS STATUS,C
    BCF PORTC,5             ; CORREGIDO: Usa RC5
    CALL ESPERA20
    RETURN
    
SETP3
    BSF PORTC,5             ; CORREGIDO: Usa RC5
    GOTO P3
      
ESPERA20
    MOVF SP, W          ; <-- ¡LA LÍNEA QUE FALTABA! (Lee el contador SP)
    SUBLW .80           ; Compara W (que es SP) con 80
    BTFSS STATUS,Z      ; Si W (SP) no es 80...
    GOTO ESPERA20       ; ...sigue esperando
    CLRF SP             ; Si W (SP) es 80, reinicia el contador
    RETURN              ; y retorna a la rutina Px
    
PRENDERLED
    MOVF P_DI, W
    SUBLW .13		;VERIFICO P0 (DEBERIA SER P0, NO LO ES EN REALIDAD)
    BTFSC STATUS,Z
    GOTO DECIDOMUX0
    MOVF P_DI,W
    SUBLW .12		;VERIFICO P1
    BTFSC STATUS,Z
    GOTO DECIDOMUX1
    MOVF P_DI,W
    SUBLW .14		;VERIFICO P2
    BTFSC STATUS,Z
    GOTO DECIDOMUX2
    GOTO DECIDOMUX3
  
    
    ;FALTA DECIDIR Y VER COMO MANDAR EL MULTIPLEXADO (POR AHORA PORTB)
DECIDOMUX0
    MOVLW .0
    CALL TABLA_MUX
    MOVWF PORTB
    RETURN
DECIDOMUX1
    MOVLW .1
    CALL TABLA_MUX
    MOVWF PORTB
    RETURN
DECIDOMUX2
    MOVLW .2
    CALL TABLA_MUX
    MOVWF PORTB
    RETURN
DECIDOMUX3
    MOVLW .3
    CALL TABLA_MUX
    MOVWF PORTB
    RETURN
    
; ======================
; TABLAS
; ======================   
;Tabla del Display
TABLA_D
    ADDWF PCL, F
    RETLW b'00111111'    ; 0
    RETLW b'00000110'    ; 1
    RETLW b'01011011'    ; 2
    RETLW b'01001111'    ; 3
    RETLW b'01100110'    ; 4
    RETLW b'01101101'    ; 5
    RETLW b'01111101'    ; 6
    RETLW b'00000111'    ; 7
    RETLW b'01111111'    ; 8
    RETLW b'01101111'    ; 9
    RETLW b'00000000'    ; 10 - Apagado
    RETLW b'01000000'    ; 11 - Guion (-)			switch case: si o si l variabke tiene uno de estos valores. hacer SUBLW con cada caso
    RETLW b'01110111'    ; 12 - 'A' (Izquierda Leve)
    RETLW b'01111100'    ; 13 - 'b' (Izquierda Fuerte)
    RETLW b'00111001'    ; 14 - 'C' (Derecha Leve)
    RETLW b'01011110'    ; 15 - 'd' (Derecha Fuerte)

;Tabla de multiplexado
TABLA_MUX
    ADDWF PCL, F
    RETLW b'00000001'    ; Display 1 (RC0) -> LDR 1
    RETLW b'00000010'    ; Display 2 (RC1) -> LDR 2
    RETLW b'00000100'    ; Display 3 (RC2) -> INDICADOR
    RETLW b'00001000'    ; Display 4 (RC3) -> Apagado
    
TABLE_OUT_SERIAL
   ADDWF PCL, F
   RETLW '0'
   RETLW '1'
   RETLW '2'
   RETLW '3'
   RETLW '4'
   RETLW '5'
   RETLW '6'
   RETLW '7'
   RETLW '8'
   RETLW '9'
    
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
    GOTO    $-4     ; CORREGIDO: Bucle simple
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