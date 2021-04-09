
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
DOWN EQU 7; ; declarar puertos RB de entrada
  
;----------------------------------Macros---------------------------------------
 
reiniciar_timer0 macro ; macro para reutilizar reinicio de tmr0
    movlw 255 ; valor de n para (256-n)
    movwf TMR0 ; delay inicial TMR0
    bcf T0IF
endm
    
  
reiniciar_timer1 macro	; reiniciar de Timer1
    Banksel PORTA   ; banco 0
    ;n = 49,912
    movlw   0xC2   ; cargar al registro W el valor inicial del tmr1 high
    movwf   TMR1H   ; cargar timer 1 high 
    movlw   0xF8    ;cargar al registro W el valor inicial del tmr1 low
    movwf   TMR1L    ; cargar timer 1 low
    bcf	    TMR1IF    ; limpiar bandera de interrupción	 timer1
endm 
  

reiniciar_timer2 macro	; reiniciar de Timer2
    ; PR2 = 244
    Banksel PORTA   ; banco 0
    movlw   0xF4   ; cargar al registro W el valor inicial del tmr2
    movwf   PR2    ; cargar PR2 2
    bcf	    TMR2IF    ;limpiar bandera de interrupción	timer2	
endm
    
  
;---------------------------------Variables-------------------------------------
    
Global cont_delay, decenas_disp_conf,unidades_conf, decenas_conf, banderas, display_var, unidades, decenas, var_temp, bandera_vias, modo_semaforo
PSECT udata_bank0 ;variables almacenadas en el banco 0
    
    banderas: DS 1 ;1 byte -> para contador de display timer0
    display_var: DS 2	
    unidades: DS 1; variables de contador BCD
    decenas: DS 1
    unidades_disp: DS 1 ; variables a mostrar en displays BCD
    decenas_disp: DS 1
    var_temp: DS 1 ;variable temporal para valor de portb
    tiempo_via1: DS 1
    tiempo_via2: DS 1
    tiempo_via3: DS 1;variables tiempos de via
    
    tiempo_via1_usr: DS 1 ;variables tiempos de vía para actualizar
    tiempo_via2_usr: DS 1
    tiempo_via3_usr: DS 1
    
    tiempo_vias_temporal: DS 1 ;->variable temporal ingresada por el usuario
    
    bandera_vias: DS 1 ; -> banderas de que vía tiene que mostrarse
    bandera_vias_temp: DS 1
    
    verde_titilante: DS 1 ; -> bandera de verde titilante
    detener_verde_titilante: DS 1 ;-> 3 seg que tarda el verde titilante
    
    led_t: DS 1; -> encendido de verde titilante 
    
    modo_semaforo: DS 1 ; variables de manejo al entrar en modos de config.
    display_conf: DS 1
    bandera_display_conf: DS 1
    unidades_conf: DS 1; 
    decenas_conf: DS 1
    decenas_disp_conf: DS 1
    unidades_disp_conf: DS 1 ; variables a mostrar en displays BCD
    
    cont_delay: DS 1 ;variable de conteo delay cuando al actualizar cambios
    aceptar: DS 1 ; variable para aceptar/rechazar cambios 01->A  10->R

    var_temp1: DS 1
    var_temp2: DS 1 ;variables temporales para multiplexado
	
 
    ;variables para multiplexar en cero las vías que no se usan
    unidades1: DS 1; variables de contador BCD
    decenas1: DS 1
    unidades_disp1: DS 1 ; variables a mostrar en displays BCD
    decenas_disp1: DS 1
    
    unidades2: DS 1; variables de contador BCD
    decenas2: DS 1
    unidades_disp2: DS 1 ; variables a mostrar en displays BCD
    decenas_disp2: DS 1
    
    
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
	btfsc   TMR2IF ; verifica si la bandera de interrupcion tmr2 esta levantada
	call    int_timer2	; subrutina de interrupción de timer2
	btfsc	RBIF ;verificar si la bandera de interrupción PORTB esta levantada
	call	int_iocb
	
    pop:
	swapf STATUS_TEMP, W ;reobtener los valores de STATUS y W
	movwf STATUS
	swapf W_TEMP,F
	swapf W_TEMP, W
	
	retfie ;salir de interrupcion
	
	
int_iocb:
    banksel PORTA
    
    btfss PORTB, MODE ;verificar pin activado como pull-up
    call actualizar_modo ; si presiona mode cambia entre modos de 1 a 5
    
    movlw 0x05; reniciar modo cuando llega a modo 5 -> overflow
    xorwf modo_semaforo,W
    btfsc STATUS,2
    clrf modo_semaforo ; si llega a modo 5 reinicio las banderas para modo normal
    btfsc STATUS,2
    clrf aceptar

    
    btfss PORTB, UP ;verificar pin activado como pull-up
    call actualizar_vias_inc ;para incrementar vias / aceptar
    
    
    btfss PORTB, DOWN ;verificar pin activado como pull-up
    call actualizar_vias_dec ; para decrementar vías / rechazar
    
    bcf RBIF ; limpiar bandera
    
    return
    
    
actualizar_modo:
    incf modo_semaforo, F ; incremento el siguiente modo y reseteo las var de conf. via
    movlw 10
    movwf display_conf
    movwf tiempo_vias_temporal
    
    return
    
actualizar_vias_inc: 
    
    movlw 0x14; reniciar cuando llega a 20 -> 10
    xorwf tiempo_vias_temporal,W
    btfsc STATUS,2
    goto $+8

    movlw 0x04 ;excepcción cuando esté en modo 5 no haga ningún incremento
    xorwf modo_semaforo,W
    btfss STATUS,2
    incf tiempo_vias_temporal,F ; si esta en modo conf. tiempo via incrementa
    btfsc STATUS,2
    bsf aceptar,0 ;si esta en modo 5, el boton esta en modo aceptar/rechazar y acepta
    
    return
    
    movlw 0x0A ; mueve el valor de 10 en el overflow de 20
    movwf tiempo_vias_temporal,F
    return
    

actualizar_vias_dec:
    
    movlw 0x0A;  reniciar cuando llega a 10 -> 20
    xorwf tiempo_vias_temporal,W
    btfsc STATUS,2
    goto $+8
    
    movlw 0x04; si esta en modo 5 el boton es para rechazar sino decrementa los tiempos
    xorwf modo_semaforo,W ; en modo conf. tiempo
    btfss STATUS,2
    decf tiempo_vias_temporal,F
    btfsc STATUS,2
    bsf aceptar,1
    
    return
    
    movlw 0x14 ; pasa a 20 en el underflow
    movwf tiempo_vias_temporal,F
    return
    
    
int_timer0: 
    reiniciar_timer0
    clrf PORTD  ;multiplexado de los displays, limpio puerto D
        
    btfsc banderas,0 ;verifico el display a encender
    goto display_decenas
    
    btfsc banderas,1
    goto display_unidades
    
    btfsc banderas,2
    goto display_decenas1
    
    btfsc banderas,3
    goto display_unidades1
    
    btfsc banderas,4
    goto display_decenas2
    
    btfsc banderas,5
    goto display_unidades2
    
    btfss bandera_display_conf,0 ; verifico primero si esta en modo conf.
    goto $+3
    btfsc banderas,6
    goto display_decenas_conf
    
    btfss bandera_display_conf,0 ;verifica primero si esta en modo conf.
    goto $+3
    btfsc banderas,7
    goto display_unidades_conf
    
    
display_decenas:; mostrar display decenas
    clrf banderas ; limpio banderas en cada display
    movf decenas_disp, W
    movwf PORTC ;muestro valor en display
    call preparar_display1_via; verifico que display se enciende
    bsf banderas,1 ;voy cambiando al siguiente display
    return
    
display_unidades:;mostrar display unidades
    clrf banderas
    movf unidades_disp, W
    movwf PORTC
    call preparar_display2_via
    bsf banderas,2
    return
    
display_decenas1:; mostrar display decenas
    clrf banderas
    movf decenas_disp1, W
    movwf PORTC
    call preparar_display1_via_1
    bsf banderas,3
    return
    
display_unidades1:;mostrar display unidades
    clrf banderas
    movf unidades_disp1, W
    movwf PORTC
    call preparar_display2_via_1
    bsf banderas,4
    return
    
display_decenas2:; mostrar display decenas
    clrf banderas
    movf decenas_disp2, W
    movwf PORTC
    call preparar_display1_via_2
    bsf banderas,5
    return
    
display_unidades2:;mostrar display unidades
    clrf banderas
    movf unidades_disp2, W
    movwf PORTC
    call preparar_display2_via_2
    bsf banderas,6
    return

display_decenas_conf:; mostrar display decenas
    clrf banderas
    movf decenas_disp_conf, W
    movwf PORTC
    bsf PORTD,6
    bsf banderas,7
    return
    
display_unidades_conf:;mostrar display unidades
    clrf banderas
    movf unidades_disp_conf, W
    movwf PORTC
    bsf PORTD,7
    bsf banderas,0
    return

    
    
preparar_display1_via: ; verifico que display1 encender de acuerdo a cual lleva la vía
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
    
preparar_display2_via: ; verifico que display2 encender de acuerdo a cual lleva la vía
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
    
preparar_display1_via_1: ;verifico cual display poner en su valor de espera que no lleve vía
    movlw 1
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 2
    movlw 2
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 4
    movlw 3
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 0
    
    return
    
preparar_display2_via_1:  ;verifico cual display poner en su valor de espera que no lleve vía
    movlw 1
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 3
    movlw 2
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 5
    movlw 3
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 1
    
    return

preparar_display1_via_2:; verifico cual display poner en su valor de espera que no lleve vía
    movlw 1
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 4
    movlw 2
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 0
    movlw 3
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 2
    
    return
  
preparar_display2_via_2:;verifico cual display poner en su valor de espera que no lleve vía
    movlw 1
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 5
    movlw 2
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 1
    movlw 3
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTD, 3
    
    return   
 
    
    
int_timer1:
    reiniciar_timer1
    
    banksel PORTA  
    
    
    btfsc aceptar,0
    decf cont_delay,F ; delay cuando se da aceptar cambio -> secuencia de cambio
    btfsc aceptar,0
    return
    
    ;verde titilante
    btfsc verde_titilante,0
    decf detener_verde_titilante, F
    
    
    ;verificar banderas y vias
    movf bandera_vias, W
    movwf bandera_vias_temp
    
   ; verifico que variable de vía decrememtar en cada segundo
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
    
    movf bandera_vias_temp, W
    movwf bandera_vias
    
    return
    

int_timer2:
    reiniciar_timer2
    ;temporizacion de parpadeo en verde titilante
    btfsc verde_titilante,0 ;realizar el el titileo de 0.5s 
    call titileo_verde	    ; solo si esta encendida la bandera
    
    return

  
titileo_verde: ;verificar de que via es el titileo
    movlw 1
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call via1_verde_titilante
    movlw 2
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call via2_verde_titilante
    movlw 3
    xorwf bandera_vias, W
    btfsc STATUS,2 ;Verificar bandera de zero
    call via3_verde_titilante
    
    
;-----------------------------Código principal----------------------------------
	
PSECT code, delta=2, abs
ORG 120h    ; guardar codigo en la posición 0x120
    
   
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
    
    call config_reloj ;
    call config_io ;
    call configuracion_inicial_vias ; configuracion inicial de valores por default vías
    call config_int_enable ;
    call config_timer0 ;
    call config_timer1  ; 
    call config_timer2 ;
    call config_iocrb ;
    
    
;-------------------------------Loop forever------------------------------------
loop:
   
   banksel PORTA
    
   ;----Código que realiza el trabajo de que via esta activa----
   
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
   
   ;llamar a los conversores hex -> decimal para cada par de displays
   call binario_decimal
   call binario_decimal1
   call binario_decimal2
   call binario_decimal_conf
   
   ;llamar a binario decimal para los display de configuraciones
   ;btfsc bandera_display_conf,0
   
    
    ;----Código que realiza el trabajo de que modo esta activo----
   
   ;modo de funcionamiento via 1 es el funcionamiento normal
   movf modo_semaforo, W
   btfsc STATUS,2 ;Verificar bandera de zero
   call modo_conf_via0
   
   movlw 0x01 ; modo de funcionamiento 2 (confi via 1)
   xorwf modo_semaforo, W
   btfsc STATUS,2 ;Verificar bandera de zero
   call modo_conf_via1
   
   movlw 0x02 ; modo de funcionamiento 3 (conf via 2)
   xorwf modo_semaforo, W
   btfsc STATUS,2 ;Verificar bandera de zero
   call modo_conf_via2
   
   movlw 0x03 ; modo de funcionamiento 4 (conf via 3)
   xorwf modo_semaforo, W
   btfsc STATUS,2 ;Verificar bandera de zero
   call modo_conf_via3
   
   movlw 0x04 ; modo de funcionamiento 5 (aceptar/rechazar cambios)
   xorwf modo_semaforo, W
   btfsc STATUS,2 ;Verificar bandera de zero
   call modo_verificar_cambios
   
   
   goto loop
 
;--------------------------------Subrutinas-------------------------------------
   
;---sección de modos

modo_conf_via0:
    
    clrf PORTE ;mantener apagados displays y led de conf.
    bcf bandera_display_conf,0
    ;call prender_config_displays
    ;bandera de modo semaforo para incremento 
    
    return   

modo_conf_via1:
    bsf PORTE,0
    bcf PORTE,1
    bcf PORTE,2
    
    bsf bandera_display_conf,0
    movf tiempo_vias_temporal,W
    movwf display_conf
    ;call prender_config_displays
    ;bandera de modo semaforo para incremento
      
    movwf tiempo_via1_usr
    
    
    return
   
modo_conf_via2:
    bcf PORTE,0
    bsf PORTE,1
    bcf PORTE,2
    
    movf tiempo_vias_temporal,W
    movwf display_conf
    
    movwf tiempo_via2_usr
    
    return
   
modo_conf_via3:
    bcf PORTE,0
    bcf PORTE,1
    bsf PORTE,2
    
    movf tiempo_vias_temporal,W
    movwf display_conf
    
    movwf tiempo_via3_usr
    
    return
   
modo_verificar_cambios:
    ;bcf PORTE,0
    ;bcf PORTE,1
    ;bcf PORTE,2
    banksel PORTA
    
    bsf PORTE,0
    bsf PORTE,1
    bsf PORTE,2
    ;call delay
    
    ;bandera aceptar o denegar
    bcf bandera_display_conf,0;apago los displays modo
    btfsc aceptar,0
    call actualizar_programa ; si acepta actualizo programa
    
    btfsc aceptar,1 ; si lo que hace es rechazar cambios
    clrf modo_semaforo
    btfsc aceptar,1
    clrf aceptar
    
    
    return
    
actualizar_programa:
    
        
    movf tiempo_via1_usr,W
    movwf tiempo_via1
    movf tiempo_via2_usr,W
    movwf tiempo_via2
    movf tiempo_via3_usr,W
    movwf tiempo_via3 ; mover tiempos metidos por usuario a tiempos del programa
    
    ;reseteo las banderas y valores a iniciales y para la secuencia de reseteo
    movlw 1
    movwf bandera_vias
    movwf led_t
    
    movlw 3
    movwf detener_verde_titilante
    
    movlw 10
    movwf display_conf
    movwf tiempo_vias_temporal
    
    movlw 0x00
    movwf banderas
    
    
    ;clrf banderas
    clrf verde_titilante
    clrf bandera_display_conf
    clrf modo_semaforo
    
    
    clrf PORTA
    bcf PORTB,0
    bsf PORTA,0; poner semaforo via 1 en rojo
    bsf	PORTA,3; poner semaforo via 2 en rojo
    bsf PORTA,6; poner semaforo via 3 en rojo
    
    
    movlw 00111111B
    movwf unidades_disp
    movwf unidades_disp1
    movwf unidades_disp2
    movwf decenas_disp
    movwf decenas_disp1
    movwf decenas_disp2 ;pongo por un instante displays en cero
    
    movf cont_delay,W; se queda aqui por un ciclo y medio del timer1
    btfss STATUS,2
    goto  $-2 
    
    
    movlw 0x02 ; se cumplio el tiempo y resetea estos dos valores del delay
    movwf cont_delay
    clrf aceptar
    
    clrf PORTA
    bcf PORTB,0
    bsf PORTA,2; poner semaforo via 1 en verde
    bsf	PORTA,3; poner semaforo via 2 en rojo
    bsf PORTA,6; poner semaforo via 3 en rojo
   
    
    return
    
    
   
;---sección de mover tiempo de via actual a var_temp
mover_tiempo_via1: 
    
    movf tiempo_via1,W 
    movwf var_temp
    
    movf tiempo_via1,W 
    movwf var_temp1 ;  tiempo de espera 2 en rojo
    movf tiempo_via1,W 
    addwf tiempo_via2, W
    movwf var_temp2
    
    return
  
mover_tiempo_via2:
    
    movf tiempo_via2,W 
    movwf var_temp
    
    
    movf tiempo_via2,W 
    movwf var_temp1 ;tiempo de espera 3 en rojo
    movf tiempo_via2,W
    addwf tiempo_via3, W
    movwf var_temp2
    
    return

mover_tiempo_via3:
    
    movf tiempo_via3,W 
    movwf var_temp
    
    movf tiempo_via3,W 
    movwf var_temp1 ;tiempo de espera 1 en rojo
    movf tiempo_via3,W
    addwf tiempo_via1, W
    movwf var_temp2
    
    return  
   
    
;---Sección de convertir valores a formato decimal
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
    
    
binario_decimal1:
    ;limpiar variables BCD

    clrf decenas1
    clrf unidades1
    
    ;ver decenas
    movlw 10
    subwf var_temp1,F; se resta el al valor de porta 10D
    btfsc STATUS, 0 ;Revisión de la bandera de carry
    incf decenas1, F; si porta>10 incrementa decenas
    btfsc STATUS, 0 ;Revisión de la bandera de carry
    goto $-4; si porta>10 repite proceso 
    addwf var_temp1,F;ya no es posible restar mas
	      ;suma nuevamente el valor de var_temp sumandole nuevamente 10D
	      
    ;ver unidades
    movf var_temp1, W
    movwf unidades1 ; mueve a unidades el restante del procedimiento anterior
		   ; var_temp en este punto es menor o igual a nueve y >0
    
    call preparar_displays1
    
    return
    
    
binario_decimal2:
    ;limpiar variables BCD

    clrf decenas2
    clrf unidades2
    
    ;ver decenas
    movlw 10
    subwf var_temp2,F; se resta el al valor de porta 10D
    btfsc STATUS, 0 ;Revisión de la bandera de carry
    incf decenas2, F; si porta>10 incrementa decenas
    btfsc STATUS, 0 ;Revisión de la bandera de carry
    goto $-4; si porta>10 repite proceso 
    addwf var_temp2,F;ya no es posible restar mas
	      ;suma nuevamente el valor de var_temp sumandole nuevamente 10D
	      
    ;ver unidades
    movf var_temp2, W
    movwf unidades2 ; mueve a unidades el restante del procedimiento anterior
		   ; var_temp en este punto es menor o igual a nueve y >0
    
    call preparar_displays2
    
    return
    
binario_decimal_conf:
    ;limpiar variables BCD conf

    clrf decenas_conf
    clrf unidades_conf
    movf display_conf,W
    movwf var_temp
    
    ;ver decenas
    movlw 10
    subwf var_temp,F; se resta el al valor de porta 10D
    btfsc STATUS, 0 ;Revisión de la bandera de carry
    incf decenas_conf, F; si porta>10 incrementa decenas
    btfsc STATUS, 0 ;Revisión de la bandera de carry
    goto $-4; si porta>10 repite proceso 
    addwf var_temp,F;ya no es posible restar mas
	      ;suma nuevamente el valor de var_temp sumandole nuevamente 10D
	      
    ;ver unidades
    movf var_temp, W
    movwf unidades_conf ; mueve a unidades el restante del procedimiento anterior
		   ; var_temp en este punto es menor o igual a nueve y >0
    
    call preparar_displays_conf
    
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
    
;-----preparar los displays moviendo valores convertidos tablay y luego a display-----------
preparar_displays1:
    clrf decenas_disp1
    clrf unidades_disp1 ; variables para prender displays
    
    movf decenas1, W ; obtener el valor para display de decenas
    call tabla
    movwf decenas_disp1
    
    movf unidades1, W ; obtener el valor para display de unidades
    call tabla
    movwf unidades_disp1
    
    return
    
    
preparar_displays2:
    clrf decenas_disp2
    clrf unidades_disp2 ; variables para prender displays
    
    movf decenas2, W ; obtener el valor para display de decenas
    call tabla
    movwf decenas_disp2
    
    movf unidades2, W ; obtener el valor para display de unidades
    call tabla
    movwf unidades_disp2
    
    return
    
    
preparar_displays_conf:
    clrf decenas_disp_conf
    clrf unidades_disp_conf ; variables para prender displays
    
    movf decenas_conf, W ; obtener el valor para display de decenas
    call tabla
    movwf decenas_disp_conf
    
    movf unidades_conf, W ; obtener el valor para display de unidades
    call tabla
    movwf unidades_disp_conf
    
    return
    
    
;---- Sección de configuraciones iniciales/actualizacion   
configuracion_inicial_vias:
    
    clrf modo_semaforo
    
    movlw 10
    movwf tiempo_via1
    movwf tiempo_via2
    movwf tiempo_via3
    
    movwf tiempo_via1_usr
    movwf tiempo_via2_usr
    movwf tiempo_via3_usr
    
    movlw 1
    movwf bandera_vias
    movwf led_t
    
    movlw 3
    movwf detener_verde_titilante
    
    movlw 10
    movwf display_conf
    movwf tiempo_vias_temporal
    
    movlw 0x00
    movwf banderas
    
    movlw 0x02
    movwf cont_delay
    
    ;clrf banderas
    clrf verde_titilante
    clrf bandera_display_conf
    clrf aceptar
    
    
    bsf PORTA,2; poner semaforo via 1 en verde
    bsf	PORTA,3; poner semaforo via 2 en rojo
    bsf PORTA,6; poner semaforo via 3 en rojo
    
    return
    
;--- subrutinas de decremento en cada segundo de los tiempos de vías--------

decrementar_via1:
    
    decf tiempo_via1,F
    
    movlw 0x06
    xorwf tiempo_via1, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf verde_titilante,0
    
    ;btfsc verde_titilante,0
    ;call via1_verde_titilante
    
    movlw 0x03
    xorwf tiempo_via1, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTA,1 ; poner semaforo via 1 en amarillo
    
    movf tiempo_via1
    btfsc STATUS,2 ;Verificar bandera de zero
    call actualizar_bandera_via1
    return
    
decrementar_via2:
    
    decf tiempo_via2,F
    
    movlw 0x06
    xorwf tiempo_via2, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf verde_titilante,0
    
    movlw 0x03
    xorwf tiempo_via2, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTA,4 ; poner semaforo via 2 en amarillo
    
    movf tiempo_via2
    btfsc STATUS,2 ;Verificar bandera de zero
    call actualizar_bandera_via2
    return
    
decrementar_via3:
    
    decf tiempo_via3,F
    
    movlw 0x06
    xorwf tiempo_via3, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf verde_titilante,0
    
    movlw 0x03
    xorwf tiempo_via3, W
    btfsc STATUS,2 ;Verificar bandera de zero
    bsf PORTA,7 ; poner semaforo via 3 en amarillo
    
    movf tiempo_via3
    btfsc STATUS,2 ;Verificar bandera de zero
    call actualizar_bandera_via3
    
    return
    
    
; ----- cada vez que termina el tiempo en semaforo actualizo la via que se pondra en 
    ;verde
actualizar_bandera_via1:
    
    movlw 0x02
    movwf bandera_vias_temp; y hacer rojo el led
    
    movf tiempo_via1_usr, W
    movwf tiempo_via1 ;reseteo el valor de conteo
    
    bsf PORTA,0; poner semaforo via 1 en rojo
    bsf	PORTA,5; poner semaforo via 2 en verde
    bcf	PORTA,3; apagar luz roja via 2 
    bsf PORTA,6; poner semaforo via 3 en rojo
    bcf PORTA,1; apagar luz amarilla via 1
    
    return
    
actualizar_bandera_via2:
    movlw 0x03
    movwf bandera_vias_temp; y hacer rojo el led
    
    movf tiempo_via2_usr, W 
    movwf tiempo_via2
    
    bsf PORTA,0; poner semaforo via 1 en rojo
    bsf	PORTA,3; poner semaforo via 2 en rojo
    bsf PORTB,0; poner semaforo via 3 en verde
    bcf PORTA,6; apagar luz roja via 3
    bcf PORTA,4; apagar luz amarilla via 2
    
    return
    
actualizar_bandera_via3:
    movlw 0x01
    movwf bandera_vias_temp; y hacer rojo el led
    
    movf tiempo_via3_usr, W
    movwf tiempo_via3
    
    bsf PORTA,2; poner semaforo via 1 en verde
    bcf PORTA,0; apagar luz roja via 1
    bsf	PORTA,3; poner semaforo via 2 en rojo
    bsf PORTA,6; poner semaforo via 3 en rojo
    bcf PORTA,7; apagar luz amarilla via 3
    
    return
    
via1_verde_titilante:
    
    btfsc PORTA,2 ; si esta encendido lo apaga
    bcf led_t,0
    btfss PORTA,2
    bsf led_t,0
    
    btfss led_t,0 ; si esta encendido lo apaga
    bcf PORTA,2
    btfsc led_t,0
    bsf PORTA,2
    
    movf detener_verde_titilante, W ; verifica que hayan pasado los 3s
    btfss STATUS, 2
    return
    
    bsf led_t,0	    ; reincia los valores de las banderas y apaga led verde
    bcf PORTA,2 
    clrf verde_titilante
    movlw 3
    movwf detener_verde_titilante
    
    return
    
via2_verde_titilante:
    
    btfsc PORTA,5 ; si esta encendido lo apaga
    bcf led_t,0
    btfss PORTA,5
    bsf led_t,0
    
    btfss led_t,0
    bcf PORTA,5
    btfsc led_t,0
    bsf PORTA,5
    
    movf detener_verde_titilante, W
    btfss STATUS, 2
    return
    
    bsf led_t,0
    bcf PORTA,5
    clrf verde_titilante
    movlw 3
    movwf detener_verde_titilante
    
    return

via3_verde_titilante:
    btfsc PORTB,0 ; si esta encendido lo apaga
    bcf led_t,0
    btfss PORTB,0
    bsf led_t,0
    
    btfss led_t,0
    bcf PORTB,0
    btfsc led_t,0
    bsf PORTB,0
    
    movf detener_verde_titilante, W
    btfss STATUS, 2
    return
    
    bsf led_t,0
    bcf PORTB,0
    clrf verde_titilante
    movlw 3
    movwf detener_verde_titilante
    
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
    bcf IRCF2 ; IRCF = 011 (500kHz) 
    bsf IRCF1
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
    bsf	TMR2IE	; Se habilitan la interrupción del TMR2 Registro PIE1
    Banksel PORTA
    bcf	TMR1IF  ; Se limpia la bandera Registro PIR1
    bcf	TMR2IF  ; Se limpia la bandera Registro PIR1
    
    return
       
    
config_iocrb:
    banksel TRISA
    bsf IOCB, MODE
    bsf IOCB, UP
    bsf IOCB, DOWN ; setear IOC en los pines 5,6,7 del puerto B
    
    banksel PORTA
    movf PORTB, W ; al leer termina condición del mismatch
    bcf RBIF
    
    return
    
;t = 4 * (T_osc) * (256-n) (Preescaler) = 2.05ms
config_timer0:
    banksel TRISA
    bcf T0CS ; reloj interno
    bcf PSA ; prescaler
    bsf PS2 
    bsf PS1 
    bsf PS0 ; PS = 110 (1:128)
    banksel PORTA
    
    reiniciar_timer0
      
    return
    
    
;t = 4 * (T_osc) * (65536-n) (Preescaler) = 1s
config_timer1:
    Banksel PORTA  
    bsf	    TMR1ON
    bcf	    TMR1CS ; Seleccion del reloj interno
    bsf	    T1CKPS1
    bsf	    T1CKPS0 ; PS a 1:8
    
    reiniciar_timer1
    
    return
    
    
;t=4 * (T_osc) * (Preescaler) (PR2) (Postcaler)= 0.5
config_timer2:
    banksel PORTA
    bsf TMR2ON ; reloj interno
    
    bsf TOUTPS3
    bsf TOUTPS2
    bsf TOUTPS1
    bsf TOUTPS0;POSTCALEER (1:16)
    
    bsf T2CKPS1
    bsf TOUTPS0;PS (1:16)
 
    reiniciar_timer2
      
    return
    
    
end