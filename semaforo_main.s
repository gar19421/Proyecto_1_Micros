
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
    movlw 255 ; valor de n para (256-n)
    movwf TMR0 ; delay inicial TMR0
    bcf T0IF
endm
    
  
reiniciar_timer1 macro	; reiniciar de Timer1
    Banksel PORTA   ; banco 0
    ;n = 34,911
    movlw   0x88   ; cargar al registro W el valor inicial del tmr1 high
    movwf   TMR1H   ; cargar timer 1 high
    movlw   0x5F    ;cargar al registro W el valor inicial del tmr1 low
    movwf   TMR1L    ; cargar timer 1 low
    bcf	    TMR1IF    ; limpiar bandera de interrupción	 timer1
endm 
  
  
;---------------------------------Variables-------------------------------------
    
Global banderas, display_var, unidades, decenas, var_temp, bandera_vias
PSECT udata_bank0 ;variables almacenadas en el banco 0
    ;var: DS 1 ;1 byte -> para bucle
    ;nibble: DS 2; variables para contador hexademimal
    ;centenas: DS 1
    ;centenas_disp: DS 1
    banderas: DS 1 ;1 byte -> para contador de display timer0
    display_var: DS 2	
    unidades: DS 1; variables de contador BCD
    decenas: DS 1
    unidades_disp: DS 1 ; variables a mostrar en displays BCD
    decenas_disp: DS 1
    var_temp: DS 1 ;variable temporal para valor de portb
    tiempo_via1: DS 1
    tiempo_via2: DS 1
    tiempo_via3: DS 1
    bandera_vias: DS 1
    
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
	btfsc	RBIF ;verificar si la bandera de interrupción PORTB esta levantada
	call	int_iocb
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
    clrf PORTD 
    btfsc banderas,0
    goto display_unidades; multiplexado de displays con timer0
    
display_decenas:; mostrar display decenas
    movf decenas_disp, W
    movwf PORTC
    call preparar_display1_via
    bsf PORTD,0;habilitar pin 3 D para encender display 3
    goto next_display
    
display_unidades:;mostrar display unidades
    movf unidades_disp, W
    movwf PORTC
    call preparar_display2_via
    goto next_display
    
next_display:; subrutina para ir iterando entre cada uno de los display
    movlw 1
    xorwf banderas,F 
    return
    
    
preparar_display1_via:
    movlw 1
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 0
    movlw 2
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 2
    movlw 3
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 4
    
    return
    
preparar_display2_via:
    movlw 1
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 1
    movlw 2
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 3
    movlw 3
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 5
    
    return
    
    
int_timer1:
    reiniciar_timer1
    
    banksel PORTA    
    
    movlw 1
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call decrementar_via1
    movlw 2
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call decrementar_via2
    movlw 3
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call decrementar_via3
    
    
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
	
    
;-------------------------------Configuración-----------------------------------

setup:
    
    call configuracion_inicial_vias
    call config_reloj ;
    call config_io ;
    call config_int_enable ;
    call config_timer1  ; 
    call config_timer0 ;  
    call config_iocrb ;
    
    
;-------------------------------Loop forever------------------------------------
loop:
    
   ;mover valor de puerto A a la variable temporal de displays BCD
   movlw 0x01
   xorwf bandera_vias, W
   btfsc STATUS,2 ;Verificar bandera de zero
   call  mover_tiempo_via1
   
   movlw 0x02
   xorwf bandera_vias, W
   btfsc STATUS,2 ;Verificar bandera de zero
   call  mover_tiempo_via2
   
   movlw 0x03
   xorwf bandera_vias, W
   btfsc STATUS,2 ;Verificar bandera de zero
   call  mover_tiempo_via3
   
    
   call binario_decimal
    
   goto loop
 
;--------------------------------Subrutinas-------------------------------------
   
mover_tiempo_via1:
    movf tiempo_via1,W 
    movwf var_temp
    return
  
mover_tiempo_via2:
    movf tiempo_via2,W 
    movwf var_temp
    return

mover_tiempo_via3:
    movf tiempo_via3,W 
    movwf var_temp
    return  
   
    
binario_decimal:
    ;limpiar variables BCD

    clrf decenas
    clrf unidades
    
    ;ver decenas
    movlw 10
    subwf var_temp,F; se resta el al valor de porta 10D
    btfsc STATUS, 0 ;Revisión de la bandera de carry
    incf decenas, F; si porta>10 incrementa decenas
    btfsc STATUS, 0 ;Revisión de la bandera de carry
    goto $-4; si porta>10 repite proceso 
    addwf var_temp,F;ya no es posible restar mas
	      ;suma nuevamente el valor de var_temp sumandole nuevamente 10D
	      
    ;ver unidades
    movf var_temp, W
    movwf unidades ; mueve a unidades el restante del procedimiento anterior
		   ; var_temp en este punto es menor o igual a nueve y >0
    
    call preparar_displays
    
    return
    
preparar_displays:
    clrf decenas_disp
    clrf unidades_disp ; variables para prender displays
    
    movf decenas, W ; obtener el valor para display de decenas
    call tabla
    movwf decenas_disp
    
    movf unidades, W ; obtener el valor para display de unidades
    call tabla
    movwf unidades_disp
    
    return
    
configuracion_inicial_vias:
    movlw 20
    movwf tiempo_via1
    movwf tiempo_via2
    movwf tiempo_via3
    
    movlw 1
    movwf bandera_vias
    
    return
    
    

decrementar_via1:
    
    decf tiempo_via1,F
    
    movlw 0x06
    xorwf tiempo_via1, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call verde_titilante
    movlw 0x03
    xorwf tiempo_via1, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call amarillo
    movf tiempo_via1
    btfsc STATUS,2 ;Verificar bandera de zero
    movlw 0x02
    btfsc STATUS,2 ;Verificar bandera de zero
    movwf bandera_vias; y hacer rojo el led
    
decrementar_via2:
    
    decf tiempo_via2,F
    
    movlw 0x06
    xorwf tiempo_via2, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call verde_titilante
    movlw 0x03
    xorwf tiempo_via2, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call amarillo ; sería macro?
    movf tiempo_via2
    btfsc STATUS,2 ;Verificar bandera de zero
    movf 0x03
    btfsc STATUS,2 ;Verificar bandera de zero
    movwf bandera_vias; y hacer rojo el led
    
decrementar_via3:
    
    decf tiempo_via3,F
    
    movlw 0x06
    xorwf tiempo_via3, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call verde_titilante
    movlw 0x03
    xorwf tiempo_via3, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call amarillo
    movf tiempo_via3
    btfsc STATUS,2 ;Verificar bandera de zero
    movf 0x01
    btfsc STATUS,2 ;Verificar bandera de zero
    movwf bandera_vias; y hacer rojo el led
    
verde_titilante:
    return
amarillo:
    return
    
;-------------------------Subrutinas de configuración--------------------------- 
    
config_io:
    banksel ANSEL ;banco 11
    clrf ANSEL
    clrf ANSELH ; habilitar puertos digitales A y B
    
    banksel TRISA ;banco 01
    clrf TRISA
   
    bcf TRISB, 0
    bsf TRISB, MODE
    bsf TRISB, UP
    bsf TRISB, DOWN
    
    clrf TRISC
    clrf TRISD
    clrf TRISE
  
    bcf OPTION_REG, 7 ;habilitar pull-ups
    bsf WPUB, MODE
    bsf WPUB, UP
    bsf WPUB, DOWN
    
    
    banksel PORTA ; banco 00
    clrf PORTB
    clrf PORTA
    clrf PORTC
    clrf PORTD ; limpiar salidas
    clrf PORTE 
    
    return
    
    
config_reloj:
    banksel OSCCON
    bsf IRCF2 ; IRCF = 100 (1MHz) 
    bcf IRCF1
    bcf IRCF0
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
    
;t = 4 * (T_osc) * (256-n) (Preescaler) = 1.03ms
config_timer0:
    banksel TRISA
    bcf T0CS ; reloj interno
    bcf PSA ; prescaler
    bsf PS2 
    bsf PS1 
    bsf PS0 ; PS = 110 (1:256)
    banksel PORTA
    
    reiniciar_timer0
      
    return
    
    
;t = 4 * (T_osc) * (65536-n) (Preescaler) = 0.98s
config_timer1:
    Banksel PORTA  
    bsf	    TMR1ON
    bcf	    TMR1CS ; Seleccion del reloj interno
    bsf	    T1CKPS1
    bsf	    T1CKPS0 ; PS a 1:8
    
    reiniciar_timer1
    
    return
    

end