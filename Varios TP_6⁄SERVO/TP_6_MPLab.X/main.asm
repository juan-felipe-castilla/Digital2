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
valor_adc    EQU 0x21    ; Valor del ADC (8 bits)
digito0      EQU 0x22    ; Unidades
digito1      EQU 0x23    ; Decenas  
digito2      EQU 0x24    ; Centenas
temp         EQU 0x25    ; Variable temporal
W_TEMP       EQU 0x70
STATUS_TEMP  EQU 0x71
  
; PRUEBA GITTTT

    
INICIO
    ; Configuración de puertos primero
    BANKSEL TRISA
    MOVLW b'00000001'    ; RA0 como entrada analógica, demás salidas
    MOVWF TRISA
    
    CLRF TRISD           ; PORTD como salida (segmentos)
    MOVLW b'11110000'    ; RC0-RC3 como salida (transistores), RC4-RC7 entrada
    MOVWF TRISC
    
    ; Configuración de ANSEL
    BANKSEL ANSEL
    MOVLW b'00000001'    ; AN0 como analógico
    MOVWF ANSEL
    CLRF ANSELH          ; Resto digital
    
    ; Configuración del ADC
    BANKSEL ADCON1
    ; ADFM = 0 (justificado a la IZQUIERDA), VCFG = 0 (VDD/VSS)
    MOVLW b'00000000'
    MOVWF ADCON1
    
    BANKSEL ADCON0
    ; ADC ON, Canal AN0, ADCS bits = 01 (Fosc/8)
    ; Formato: b'0 ADCS2 CHS2 CHS1 CHS0 GO/ADON' según include; 
    ; esta línea mantiene la intención (canal 0, ADON=1, ADCS=01)
    MOVLW b'01000001'    
    MOVWF ADCON0
    
    ; Configuración de Timer0
    BANKSEL OPTION_REG
    MOVLW B'10000100'    ; Prescaler 1:32 para Timer0, fuente interna
    MOVWF OPTION_REG
    
    ; Configuración de interrupciones 
    BCF INTCON, T0IF     ; Limpiar flag del Timer0
    BSF INTCON, T0IE     ; Habilitar interrupción del Timer0
    BSF INTCON, GIE      ; Habilitar interrupciones globales
    
    BANKSEL 0            ; Volver al banco 0
    
    ; Inicialización de variables
    CLRF contT
    CLRF valor_adc
    CLRF digito0
    CLRF digito1  
    CLRF digito2
    CLRF temp
    
    ; Limpiar puertos
    CLRF PORTA
    CLRF PORTC
    CLRF PORTD
    
    MOVLW .100
    MOVWF TMR0
    
    ; Espera inicial para estabilización del ADC
    CALL RETARDO_1MS
    
    GOTO LOOP_PRINCIPAL

; ======================
; Tabla del Display
; ======================
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

; ======================
; Tabla de multiplexado
; ======================
TABLA_MUX
    ADDWF PCL, F
    RETLW b'00000001'   ; Display 1 (RC0) - Centenas
    RETLW b'00000010'   ; Display 2 (RC1) - Decenas  
    RETLW b'00000100'   ; Display 3 (RC2) - Unidades
    RETLW b'00000000'   ; Display 4 (RC3) - Apagado
    
; ======================
; ISR - Solo Timer0 para multiplexado
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
    
; ======================
; Subrutina de Timer0
; ======================    
TIMER_ISR
    MOVLW .100
    MOVWF TMR0
    BCF INTCON, T0IF
    
    ; Multiplexado de displays
    CALL MULTIPLEXAR
    RETURN

; ======================
; LEER ADC (con retardo de adquisición)
; ======================
LEER_ADC
    BANKSEL ADCON0
    ; Esperar a que no haya conversión en curso (GO/DONE = 0)
WAIT_NO_CONV:
    BTFSC ADCON0, GO_DONE
    GOTO WAIT_NO_CONV
    
    ; Retardo de adquisición para que el capacitor del S/H se cargue
    CALL RETARDO_100US
    
    ; Iniciar nueva conversión
    BSF ADCON0, GO_DONE
    
    ; Esperar a que termine la conversión
ESPERAR_CONVERSION:
    BTFSC ADCON0, GO_DONE
    GOTO ESPERAR_CONVERSION
    
    ; Leer resultado (8 bits - justificado a izquierda)
    MOVF ADRESH, W
    MOVWF valor_adc
    
    BANKSEL 0
    RETURN

; ======================
; CONVERTIR VALOR ADC A DIGITOS - COMPLETAMENTE REESCRITA (tu lógica conservada)
; ======================
CONVERTIR_DIGITOS
    ; Cargar valor ADC en temp
    MOVF valor_adc, W
    MOVWF temp
    
    ; Verificar si es >= 200
    MOVF temp, W
    SUBLW .199          ; si temp > 199 => C = 0 (SUBLW hace W = K - W)
    BTFSC STATUS, C
    GOTO CHECK_100      ; Si temp <= 199, verificar 100
    
    ; Es >= 200
    MOVLW .2
    MOVWF digito2
    MOVLW .200
    SUBWF temp, F
    GOTO CALC_DECENAS

CHECK_100
    ; Verificar si es >= 100
    MOVF temp, W
    SUBLW .99
    BTFSC STATUS, C
    GOTO CALC_DECENAS   ; Si temp <= 99, ir a decenas
    
    ; Es >= 100
    MOVLW .1
    MOVWF digito2
    MOVLW .100
    SUBWF temp, F

CALC_DECENAS
    ; CALCULAR DECENAS - método por bloques (tu aproximación)
    ; Se prueban 9,8,...,1 decenas y se resta la cantidad correspondiente
    MOVF temp, W
    SUBLW .89
    BTFSC STATUS, C
    GOTO CHECK_80   
    MOVLW .9
    MOVWF digito1
    MOVLW .90
    SUBWF temp, F
    GOTO CALC_UNIDADES
    
CHECK_80
    MOVF temp, W
    SUBLW .79
    BTFSC STATUS, C
    GOTO CHECK_70   
    MOVLW .8
    MOVWF digito1
    MOVLW .80
    SUBWF temp, F
    GOTO CALC_UNIDADES
    
CHECK_70
    MOVF temp, W
    SUBLW .69
    BTFSC STATUS, C
    GOTO CHECK_60   
    MOVLW .7
    MOVWF digito1
    MOVLW .70
    SUBWF temp, F
    GOTO CALC_UNIDADES
    
CHECK_60 
    MOVF temp, W
    SUBLW .59           
    BTFSC STATUS, C
    GOTO CHECK_50   
    MOVLW .6
    MOVWF digito1
    MOVLW .60
    SUBWF temp, F
    GOTO CALC_UNIDADES
    
CHECK_50
    MOVF temp, W
    SUBLW .49           
    BTFSC STATUS, C
    GOTO CHECK_40   
    MOVLW .5
    MOVWF digito1
    MOVLW .50
    SUBWF temp, F
    GOTO CALC_UNIDADES
    
CHECK_40 
    MOVF temp, W
    SUBLW .39           
    BTFSC STATUS, C
    GOTO CHECK_30   
    MOVLW .4
    MOVWF digito1
    MOVLW .40
    SUBWF temp, F
    GOTO CALC_UNIDADES
    
CHECK_30 
    MOVF temp, W
    SUBLW .29           
    BTFSC STATUS, C
    GOTO CHECK_20   
    MOVLW .3
    MOVWF digito1
    MOVLW .30
    SUBWF temp, F
    GOTO CALC_UNIDADES
    
CHECK_20 
    MOVF temp, W
    SUBLW .19           
    BTFSC STATUS, C
    GOTO CHECK_10   
    MOVLW .2
    MOVWF digito1
    MOVLW .20
    SUBWF temp, F
    GOTO CALC_UNIDADES
    
CHECK_10 
    MOVF temp, W
    SUBLW .9           
    BTFSC STATUS, C
    GOTO  CALC_UNIDADES
    MOVLW .1
    MOVWF digito1
    MOVLW .10
    SUBWF temp, F
    GOTO CALC_UNIDADES
    

CALC_UNIDADES
    ; CALCULAR UNIDADES - lo que queda en temp
    MOVF temp, W
    MOVWF digito0
    
    RETURN

; ======================
; Multiplexado de displays
; ======================
MULTIPLEXAR
    ; Apagar todos los displays primero
    MOVLW 0x00
    MOVWF PORTC
    
    ; Seleccionar display según contT
    MOVF contT, W
    CALL TABLA_MUX
    MOVWF PORTC        
    
    ; Mostrar dígito correspondiente
    CALL MOSTRAR_DIGITO
    
    ; Incrementar contador de multiplexado (0-3). Reinicia cuando >=4
    INCF contT, F
    MOVLW .4
    SUBWF contT, W
    BTFSS STATUS, C
    RETURN
    CLRF contT
    RETURN

; ======================
; Mostrar dígito según display seleccionado
; ======================
MOSTRAR_DIGITO
    ; Alineamos contT con TABLA_MUX:
    ; contT = 0 -> centenas
    ; contT = 1 -> decenas
    ; contT = 2 -> unidades
    MOVF contT, W
    XORLW 0
    BTFSC STATUS, Z
    GOTO MOSTRAR_UNIDADES
    MOVF contT, W
    XORLW 1
    BTFSC STATUS, Z
    GOTO MOSTRAR_DECENAS
    GOTO MOSTRAR_CENTENAS

MOSTRAR_CENTENAS
    MOVF digito2, W
    GOTO FIN_MOSTRAR

MOSTRAR_DECENAS
    MOVF digito1, W
    GOTO FIN_MOSTRAR

MOSTRAR_UNIDADES
    MOVF digito0, W
    
FIN_MOSTRAR
    CALL TABLA_D
    MOVWF PORTD
    RETURN

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

; ======================
; LOOP PRINCIPAL
; ======================
LOOP_PRINCIPAL
    ; Leer ADC
    CALL LEER_ADC
    
    ; Convertir valor ADC a dígitos
    CALL CONVERTIR_DIGITOS
    
    ; Pequeño retardo entre lecturas (opcional)
    CALL RETARDO_100US
    
    GOTO LOOP_PRINCIPAL
    
    END