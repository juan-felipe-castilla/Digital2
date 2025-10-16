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
W_TEMP       EQU 0x70
STATUS_TEMP  EQU 0x71
    
INICIO
    BANKSEL TRISB
    ; Configuración para displays (manteniendo tu configuración original)
    CLRF TRISD           ; PORTD como salida (segmentos)
    MOVLW b'11110000'    ; RC0-RC3 como salida (transistores), RC4-RC7 entrada
    MOVWF TRISC
    
    ; Configuración del ADC - AN0 como entrada analógica
    MOVLW b'00000001'    ; RA0 como entrada analógica
    MOVWF TRISA
    
    ; Configuración de ANSEL
    BANKSEL ANSEL
    MOVLW b'00000001'    ; AN0 como analógico
    MOVWF ANSEL
    CLRF ANSELH          ; Resto digital
    
    ; Configuración del ADC
    BANKSEL ADCON1
    MOVLW b'00000000'    ; Justificado a izquierda, VDD y VSS como referencia
    MOVWF ADCON1
    
    BANKSEL ADCON0
    ; ADC ON, Canal AN0, Fosc/8
    MOVLW b'01000001'    ; Bit7-6: Justificado izquierda, Bit5-3: Canal AN0
                         ; Bit1-0: Fosc/8, ADC ON
    MOVWF ADCON0
    
    ; Configuración de Timer0 (manteniendo tu configuración)
    BANKSEL OPTION_REG
    MOVLW B'00000100'    ; Prescaler 1:32 para Timer0
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
    
    ; Limpiar puertos
    CLRF PORTC
    CLRF PORTD
    
    MOVLW .99
    MOVWF TMR0
    
    ; Espera inicial para estabilización del ADC
    CALL RETARDO_20US
    
    GOTO LOOP_PRINCIPAL

; ======================
; Tabla del Display
; ======================
TABLA_D
    ADDWF PCL, F
    ;     dp abcdefg
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
    RETLW b'00001000'   ; Display 4 (RC3) - Apagado (no usado)
    
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
    MOVLW .99
    MOVWF TMR0
    BCF INTCON, T0IF
    
    ; Multiplexado de displays
    CALL MULTIPLEXAR
    RETURN

; ======================
; LEER ADC
; ======================
LEER_ADC
    BANKSEL ADCON0
    ; Iniciar conversión
    BSF ADCON0, GO_DONE
    
ESPERAR_CONVERSION:
    BTFSC ADCON0, GO_DONE
    GOTO ESPERAR_CONVERSION
    
    ; Leer resultado (8 bits - justificado a izquierda)
    MOVF ADRESH, W
    MOVWF valor_adc
    
    BANKSEL 0
    RETURN

; ======================
; CONVERTIR VALOR ADC A DIGITOS
; ======================
CONVERTIR_DIGITOS
    ; El valor ADC está en 8 bits (0-255)
    MOVF valor_adc, W
    MOVWF digito0      ; Usaremos digito0 temporalmente
    
    ; Calcular centenas (0-2)
    CLRF digito2
CALCULAR_CENTENAS:
    MOVLW .100
    SUBWF digito0, W
    BTFSS STATUS, C
    GOTO CALCULAR_DECENAS
    MOVWF digito0      ; Guardar resto
    INCF digito2, F
    GOTO CALCULAR_CENTENAS
    
CALCULAR_DECENAS:
    ; Calcular decenas (0-9)
    CLRF digito1
CALCULAR_DEC_LOOP:
    MOVLW .10
    SUBWF digito0, W
    BTFSS STATUS, C
    GOTO FIN_CONVERSION
    MOVWF digito0      ; Guardar resto
    INCF digito1, F
    GOTO CALCULAR_DEC_LOOP
    
FIN_CONVERSION:
    ; digito0 ahora tiene las unidades (0-9)
    ; digito1 tiene las decenas (0-9)
    ; digito2 tiene las centenas (0-2)
    RETURN

; ======================
; Multiplexado de displays
; ======================
MULTIPLEXAR
    ; Apagar todos los displays temporalmente
    MOVLW 0x00
    MOVWF PORTC
    
    ; Seleccionar display según contT
    MOVF contT, W
    CALL TABLA_MUX
    MOVWF PORTC        
    
    ; Mostrar dígito correspondiente
    CALL MOSTRAR_DIGITO
    
    ; Incrementar contador de multiplexado (0-3)
    INCF contT, F
    MOVLW 0x04
    SUBWF contT, W
    BTFSC STATUS, C
    CLRF contT
    
    RETURN

; ======================
; Mostrar dígito según display seleccionado
; ======================
MOSTRAR_DIGITO
    MOVF contT, W
    XORLW 0x00
    BTFSC STATUS, Z
    GOTO MOSTRAR_CENTENAS
    MOVF contT, W
    XORLW 0x01
    BTFSC STATUS, Z
    GOTO MOSTRAR_DECENAS
    MOVF contT, W
    XORLW 0x02
    BTFSC STATUS, Z
    GOTO MOSTRAR_UNIDADES
    ; Display 4 - Apagado
    MOVLW .10
    GOTO FIN_MOSTRAR

MOSTRAR_CENTENAS:
    MOVF digito2, W
    GOTO FIN_MOSTRAR

MOSTRAR_DECENAS:
    MOVF digito1, W
    GOTO FIN_MOSTRAR

MOSTRAR_UNIDADES:
    MOVF digito0, W

FIN_MOSTRAR:
    CALL TABLA_D
    MOVWF PORTD
    RETURN

; ======================
; Retardo para estabilización ADC
; ======================
RETARDO_20US
    ; Retardo aproximado de 20?s para 4MHz
    MOVLW .20
    MOVWF W_TEMP
RETARDO_LOOP:
    DECFSZ W_TEMP, F
    GOTO RETARDO_LOOP
    RETURN

; ======================
; LOOP PRINCIPAL
; ======================
LOOP_PRINCIPAL
    ; Leer ADC continuamente
    CALL LEER_ADC
    
    ; Convertir valor a dígitos
    CALL CONVERTIR_DIGITOS
    
    ; Pequeño retardo entre lecturas
    CALL RETARDO_20US
    CALL RETARDO_20US
    
    GOTO LOOP_PRINCIPAL
    
    END


