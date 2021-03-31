
    ;Archivo:	    semaforo_main.s
    ;Dispositivo:   PIC16F887
    ;Autor:	    Brandon Garrido
    ;Compilador:    pic-as(v2.31), MPLABX V5.45
    ;
    ;Programa:	    Proyecto #1 Progra de micros - Semáforo de 3 vías
    ;Hardware:	    Multiplexado de Displays en puerto C, transistores 
    ;		    en puerto D, Leds en puertos A y E, botones de control
    ;		    en puerto B
    ;Creado: 26 mar 2021
    ;Última modificación: 27 mar, 2021
    
    
processor 16F887
#include <xc.inc>
    
;--------------------------Palabra de configuración-----------------------------

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ;Configurar oscilador interno
  CONFIG  WDTE = OFF            ; Deshabilitar el Watch Dog Timer
  CONFIG  PWRTE = ON            ; Habilitar 72ms de Power-Up 
  CONFIG  MCLRE = OFF           ; Master Clear en pin RE3 deshabilitado
  CONFIG  CP = OFF              ; Protección de código deshabilitada
  CONFIG  CPD = OFF             ; Protección de datos de memoria deshabilitado
  CONFIG  BOREN = OFF           ; Brown Out Reset deshabilitado
  CONFIG  IESO = OFF            ; Internal External Switchover deshabilitado
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor deshabilitado
  CONFIG  LVP = ON              ; Programación de bajo voltaje habilitado

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset configurado a 4V
  CONFIG  WRT = OFF           ; Autoescritura de la memoria flash deshabilitado

  
;--------------------------------Constantes-------------------------------------
MODE EQU 5
UP EQU 6
DOWN EQU 7;
  
;----------------------------------Macros---------------------------------------
    
reiniciar_timer0 macro ; macro para reutilizar reinicio de tmr0
    movlw 254 ; valor de n para (256-n)
    movwf TMR0 ; delay inicial TMR0
    bcf T0IF
endm
  
reiniciar_timer1 macro	; reiniciar de Timer1
    Banksel PORTA   ; banco 0
    ;n = 32,286
    movlw   0x7E   ; cargar al registro W el valor inicial del tmr1 high
    movwf   TMR1H   ; cargar timer 1 high
    movlw   0x1E    ;cargar al registro W el valor inicial del tmr1 low
    movwf   TMR1L    ; cargar timer 1 low
    bcf	    TMR1IF    ; limpiar bandera de interrupción	 timer1
endm 
  
  
;---------------------------------Variables-------------------------------------
    
Global var, banderas, nibble, display_var, unidades, decenas, centenas, var_temp
PSECT udata_bank0 ;variables almacenadas en el banco 0
    var: DS 1 ;1 byte -> para bucle
    banderas: DS 1 ;1 byte -> para contador de display timer0
    nibble: DS 2; variables para contador hexademimal
    display_var: DS 2	
    unidades: DS 1; variables de contador BCD
    decenas: DS 1
    centenas: DS 1
    unidades_disp: DS 1 ; variables a mostrar en displays BCD
    decenas_disp: DS 1
    centenas_disp: DS 1
    var_temp: DS 1 ;variable temporal para valor de portb
    
PSECT udata_shr ;variables en memoria compartida
    W_TEMP: DS 1 ;1 byte
    STATUS_TEMP: DS 1; 1 byte

   
    
;-------------------------------Vector reset------------------------------------
    
PSECT resetVector, class=CODE, delta=2, abs
ORG 0x0000
    goto setup
 
;-------------------------Vector de interrupción--------------------------------
    
PSECT interruptVector, class=CODE, delta=2, abs
ORG 0x0004
    
    push:
	movwf W_TEMP
	swapf STATUS,W ;swapf por que no afecta las banderas (no movf)
	movwf STATUS_TEMP
    
    isr:
	btfsc RBIF ;verificar si la bandera de interrupción PORTB esta levantada
	call int_iocb
	btfsc   T0IF ; verifica si la bandera de interrupcion tmr0 esta levantada
	call    int_timer0	;subrutina de interrupción de timer0
	btfsc   TMR1IF; verifica si la bandera de interrupcion tmr1 esta levantada
	call    int_timer1	; subrutina de interrupción de timer1
    
    pop:
	swapf STATUS_TEMP, W
	movwf STATUS
	swapf W_TEMP,F
	swapf W_TEMP, W
	
	retfie
	
	
int_iocb:
    banksel PORTA
    btfss PORTB, MODE ;verificar pin activado como pull-up
    ;decf PORTA
    btfss PORTB, UP ;verificar pin activado como pull-up
    ;incf PORTA
    btfss PORTB, DOWN ;verificar pin activado como pull-up
    ;decf PORTA
    
    bcf RBIF ; limpiar bandera
    
    return

	
int_timer0:
    
    reiniciar_timer0
    
    banksel PORTA
    incf PORTD
    
    
    return
    
int_timer1:
    reiniciar_timer1
    
    banksel PORTA    
    incf PORTA ; incrementar contador en el PORTA con timer1
    
    
    return
    
    

    
;-----------------------------Código principal----------------------------------
	
PSECT code, delta=2, abs
ORG 100h   
    
   
tabla: ; tabla de valor de pines encendido para mostrar x valor en el display
    clrf PCLATH
    bsf PCLATH, 0 ; PCLATH = 01 PCL = 02
    andlw 0x0f ; para solo llegar hasta f
    addwf PCL ;PC = PCLATH + PCL + W
    retlw 00111111B ;0
    retlw 00000110B ;1
    retlw 01011011B ;2
    retlw 01001111B ;3
    retlw 01100110B ;4
    retlw 01101101B ;5
    retlw 01111101B ;6
    retlw 00000111B ;7
    retlw 01111111B ;8
    retlw 01101111B ;9
    retlw 01110111B ;A
    retlw 01111100B ;B
    retlw 00111001B ;C
    retlw 01011110B ;D
    retlw 01111001B ;E
    retlw 01110001B ;F 
	
    
;----------- Configuración -----------------------

setup:
    
    call config_io ;
    call config_reloj ;
    call config_timer0 ;  
    call config_timer1  ;
    call config_int_enable ; 
    call config_iocrb ;
    

loop:
    
    
    goto loop
    
    
    
config_io:
    banksel ANSEL ;banco 11
    clrf ANSEL
    clrf ANSELH ; habilitar puertos digitales A y B
    
    banksel TRISA ;banco 01
    clrf TRISA
   
    bcf PORTB, 0
    bsf PORTB, MODE
    bsf PORTB, UP
    bsf PORTB, DOWN
    
    clrf TRISC
    clrf TRISD
    clrf TRISE
  
    bcf OPTION_REG, 7 ;habilitar pull-ups
    bsf WPUB, MODE
    bsf WPUB, UP
    bsf WPUB, DOWN
    
    
    banksel PORTA ; banco 00
    clrf PORTA
    clrf PORTC
    clrf PORTD ; limpiar salidas
    
    
    
    return
    
    
config_reloj:
    banksel OSCCON
    bcf IRCF2 ; IRCF = 100 (1MHz) 
    bcf IRCF1
    bsf IRCF0
    bsf SCS ; reloj interno
    
    return
 
config_int_enable:; INTCON
    Banksel PORTA
    bsf	GIE	; Se habilitan las interrupciones globales
    
    bsf RBIE ; habilitar banderas de interrupción puertos B
    bcf RBIF	
    
    bsf	T0IE    ; Se habilitan la interrupción del TMR0
    bcf	T0IF    ; Se limpia la bandera
    
    bsf	PEIE
    Banksel TRISA
    bsf	TMR1IE	; Se habilitan la interrupción del TMR1 Registro PIE1
    ;bsf	TMR2IE	; Se habilitan la interrupción del TMR2 Registro PIE1
    Banksel PORTA
    bcf	TMR1IF  ; Se limpia la bandera Registro PIR1
    ;bcf	TMR2IF  ; Se limpia la bandera Registro PIR1
    
    return
       
    
config_iocrb:
    banksel TRISA
    bsf IOCB, MODE
    bsf IOCB, UP
    bsf IOCB, DOWN ; setear IOC en los pines 0 y 7 del puerto B
    
    banksel PORTA
    movf PORTB, W ; al leer termina condición del mismatch
    bcf RBIF
    
    return
    
;t = 4 * (T_osc) * (256-n) (Preescaler) = 1ms
config_timer0:
    banksel TRISA
    bcf T0CS ; reloj interno
    bcf PSA ; prescaler
    bcf PS2 
    bsf PS1 
    bsf PS0 ; PS = 110 (1:128)
    banksel PORTA
    
    reiniciar_timer0
      
    return
    
    
;t=4 * (T_osc) * (63536-n) (Preescaler) = 1s
config_timer1:
    Banksel PORTA  
    bsf	    TMR1ON
    bcf	    TMR1CS ; Seleccion del reloj interno
    bsf	    T1CKPS1
    bsf	    T1CKPS0 ; PS a 1:8
    
    reiniciar_timer1
    
    return
    
   

  


    
    

    


    
    

end