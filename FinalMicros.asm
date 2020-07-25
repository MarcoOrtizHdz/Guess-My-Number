    
    ; Proyecto Final - Adivina el numero
    ; Emiliano Aguirre Bayli	A01338896
    ; Marco Antonio Ortiz Hdz	A00823250 
    
    #include "p18f45k50.inc"
    
    org 0x00
    goto configura
    
    org 0x08 ; interrupciones de alta prioridad
    goto aborto
    
    org 0x18 ; interrupciones de baja prioridad
    retfie ;goto IOCint
    
    org 0x30
configura movlb d'15'
    clrf    ANSELB, BANKED          ; configura el puerto B como digital
    clrf    ANSELD, BANKED          ; configura el puerto D como digital
    clrf    ANSELA, BANKED          ; configura el puerto A como digital
    setf    ANSELE, BANKED          ; configura el puerto E como analogo
    clrf    ANSELC, BANKED          ; configura el puerto C como digital
    clrf    TRISD, A                ; configura el puerto D como salida, este puerto se usa para el bus de Datos del LCD
    setf    TRISB, A                ; configura el puerto B como entrada
    clrf    TRISA, A                ; configura el puerto A como salida, este puerto se usara para el LCD
    clrf    TRISC, A                ; configura el puerto C como salidad, C6 y C7 se usarán para los LEDs de Win/Lose
    setf    TRISE, A                ; congfigura el puerto E como entrada
    #define RS LATA, 1, A           ; RS del LCD
    #define E LATA, 2, A            ; Enable del LCD
    #define RW LATA, 3, A           ; Read/Write del LCD
    #define dataLCD LATD, A         ; Bus de Datos para el LCD
    #define botonA PORTB, 0, A      ; boton "principal" para pasar de pantallas, selecionar numero, etc
    #define botonB PORTB, 1, A      ; boton "secundario" para pasar elegir ver el marcador
    #define botonAbort PORTB, 2, A  ; boton para ejecutar la interrupcion
    #define ledWin LATC, 6, A       ; LED que se enciende si se gana la partida
    #define ledLose LATC, 7, A      ; LED que se enciende si se pierde la partida


vidas           EQU 0x34    ; Registro es en donde se almacenarán las vidas restantes
randomNumber    EQU 0x35    ; Registro es en donde se almacenará el random number
numWins         EQU 0x36    ; Registro es para mantener el puntaje de victorias
numDefeats      EQU 0x37    ; Eegistro es para mantener el puntaje de derrotas
resultadoResta  EQU 0x38    ; Registro es para guardar el resultado de la resta entre lo seleccionado con el potencimoetro y el random number
numPot          EQU 0x39    ; Registro para guardar num que ira al LCD 
contador        EQU 0x40    ; Contador auxiliar
acumulado       EQU 0X41    ; Contador extra para llevar acumulado de la resta de la seleccion de numero
dirVictorias    EQU d'10'   ; Direccion Victorias en EEPROM
dirDerrotas     EQU d'11'   ; Direccion Derrotas en EEPROM


    clrf contador, A

    ; Configurar ADC -------------------------------------------------------------------------------------------------------
    MOVLW   B'00011100'     ; AN7, aqui estara conectado el potenciometro
    MOVWF   ADCON0
    MOVLW   B'00000000'     ; internal voltage references
    MOVWF   ADCON1
    MOVLW   B'00100100'     ; left-justified, ACT=8TAD, ADCS=Fosc/4
    MOVWF   ADCON2
    BSF     ADCON0, 0       ; enable ADC


    ; Configuracion de la interrupcion de aborto ---------------------------------------------------------------------------
    clrf    LATC, A         ;Limpiar los valores de salida del puerto C (Según esto, es buena práctica)
    movlw   b'00000000'     ;Configurando enables globales
    movwf   INTCON, A
    bcf     INTCON3, 1, A   ;Se limpia la bandera
    bcf     RCON, 7, A      ;Se habilita el uso de interrupciones
    movlw   b'10010000'
    movwf   INTCON3, A      ;Se configura el INT2
    bsf     INTCON2, 4, A   ;Rising edge en INT2

    movlw   d'0'
    movwf   numWins         ; se inicializa el marcador de victorias en 0
    movwf   numDefeats      ; se inicializa el marcador de derrotas en 0

    
    ; Se define el valor inicial del registro para retardo para LCD 
    movlw   .247
    movwf   0x32, A
    
    
start
    ; se inicializan las victorias y derrotas de la eeprom en 0 ------------------------------------------------------------------------
    movlw   d'0' 
    movwf   numDefeats, A
    movwf   numWins, A
    movlw   dirDerrotas
    call    escribeDerrotasEEPROM
    movlw   dirVictorias
    call    escribeVictoriasEEPROM


    
    ; retardo inicial para que la LCD se inicialice ------------------------------------------------------------------------
    call    ret40
    movlw   .247
    movwf   0x32, A
    
    
    ; Empieza la configuración de la LCD -----------------------------------------------------------------------------------
    
    bcf RS                  ; se pone en 0 el RS porque aun no se necesita
    movlw   b'00111000'     ; Modo de funcionamiento de 2 lineas 
    call    enviaDatos
    movlw   b'00001100'     ; Encender el display, el cursor y el parpadeo 
    call    enviaDatos
    movlw   b'00010100'     ; Configurar el incremento del cursor hacia la derecha
    call    enviaDatos

    ;Se activan las interrupciones--------------------------------------------------------------------------------------------
    bsf     INTCON, 7, A
    bsf     INTCON, 6, A
    
reiniciaJuego   ; Aqui viene cuando se acaba el juego o se presiona la interrupcion de Abortar
    ; Limpiar el display y enviar al home (posicion 0)
    call    limpiaDisplay
    nop

    ; Creación de custom characters para LCD -------------------------------------------------------------------------------
    call    crearCustoms
    nop
    
    ; Aqui empieza el menu (cartel) de Bienvenida --------------------------------------------------------------------------
    
    ; Moverse a la posicion 4 de la primera linea (0x04) 
    movlw   b'10000100' ; se carga el 0x04 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS			; ya se pone en 1 el RS para escribir el mensaje
    ; Se empieza a escribir el mensaje letra por letra 
    movlw   'W'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'L'
    call    enviaDatos
    movlw   'C'
    call    enviaDatos
    movlw   'O'
    call    enviaDatos
    movlw   'M'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   '!'
    call    enviaDatos
    bcf     RS          ; vuelve a poner el RS en 0 para mover la posicion del cursor
    ; Moverse a la posicion 0 de la segunda linea (0x40)
    movlw   b'11000000' ; se carga el 0x40 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS          ; se pone el RS en 1 para escribir los nuevos valores
    ; Se escribe el mensaje letra por letra
    movlw   'C'
    call    enviaDatos
    movlw   'h'
    call    enviaDatos
    movlw   'o'
    call    enviaDatos
    movlw   'o'
    call    enviaDatos
    movlw   's'
    call    enviaDatos
    movlw   'e'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'a'
    call    enviaDatos
    movlw   'n'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'o'
    call    enviaDatos
    movlw   'p'
    call    enviaDatos
    movlw   't'
    call    enviaDatos
    movlw   'i'
    call    enviaDatos
    movlw   'o'
    call    enviaDatos
    movlw   'n'
    call    enviaDatos
    
checkBotonWelcome               ; cambio de pantalla al presionar el boton RE0
    btfss   botonA              ; checa si se presiono el boton para pasar de pantalla
        goto checkBotonWelcome  ; si no se presiono, se queda esperando
    ; si se presiona, cambia de pantalla

afterScore
    ; Limpiar el display y enviar al home (posicion 0)
    call    limpiaDisplay
    nop
    ; Moverse a la posicion 2 de la primera linea (0x02) 
    movlw   b'10000010' ; se carga el 0x02 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS			; ya se pone en 1 el RS para escribir el mensaje
    ; Se empieza a escribir el mensaje letra por letra 
    movlw   'P'
    call    enviaDatos
    movlw   'L'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'Y'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'G'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'M'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   ':'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    
    bcf     RS              ; vuelve a poner el RS en 0 para mover la posicion del cursor
    ; Moverse a la posicion 1 de la segunda linea (0x41)
    movlw   b'11000001'     ; se carga el 0x41 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS              ; se pone el RS en 1 para escribir los nuevos valores
    ; Se escribe el mensaje letra por letra
    movlw   'S'
    call    enviaDatos
    movlw   'C'
    call    enviaDatos
    movlw   'O'
    call    enviaDatos
    movlw   'R'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'S'
    call    enviaDatos
    movlw   'T'
    call    enviaDatos
    movlw   'R'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'K'
    call    enviaDatos
    movlw   ':'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'B'
    call    enviaDatos
    
    
checkBotonMode                      ; cambia de pantalla el modo que se haya seleccionado con el boton
    incf    randomNumber, F, A      ; se genera un numero "aleatorio"
    btfsc   botonA                  ; checa si se presiono el boton RE0 para iniciar el juego
        goto playGame               ; si se presiono, inicia el juego
        ; si no se presiono, checa el boton RE1 para ver el marcador
    btfsc   botonB
        goto viewScore              ; si se presiono, va al marcador
    goto    checkBotonMode          ; si no se presiono, vuelve a checar el otro boton



    ; Pantalla de Play Game ------------------------------------------------------------------------------------------------

playGame                            ; se queda esperando el potenciometro y seleccion del numero (no implementado)    
    ; Limpiar el display y enviar al home (posicion 0)
    call    limpiaDisplay
    nop
    ; Moverse a la posicion 0 de la primera linea (0x00) 
    movlw   b'10000000' ; se carga el 0x00 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS			; ya se pone en 1 el RS para escribir el mensaje
    ; Se empieza a escribir el mensaje letra por letra 
    movlw   'N'
    call    enviaDatos
    movlw   'O'
    call    enviaDatos
    movlw   'R'
    call    enviaDatos
    movlw   'M'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'L'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   '('
    call    enviaDatos
    movlw   0x02
    call    enviaDatos
    movlw   0x03
    call    enviaDatos
    movlw   'x'
    call    enviaDatos
    movlw   '6'
    call    enviaDatos
    movlw   ')'
    call    enviaDatos
    movlw   ':'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    
    bcf     RS              ; vuelve a poner el RS en 0 para mover la posicion del cursor
    ; Moverse a la posicion 1 de la segunda linea (0x41)
    movlw   b'11000001'     ; se carga el 0x41 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS              ; se pone el RS en 1 para escribir los nuevos valores
    ; Se escribe el mensaje letra por letra
    movlw   'H'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'R'
    call    enviaDatos
    movlw   'D'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   '('
    call    enviaDatos
    movlw   0X02
    call    enviaDatos
    movlw   0X03
    call    enviaDatos
    movlw   'x'
    call    enviaDatos
    movlw   '2'
    call    enviaDatos
    movlw   ')'
    call    enviaDatos
    movlw   ':'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'B'
    call    enviaDatos

checkDifficulty
    btfsc   botonA                  ; checa si se presiono el botonA
        goto carga6vidas               ; si se presiono, carga 6 vidas
        ; si no se presiono, checa el botonB
    btfsc   botonB
        goto carga2vidas              ; si se presiono, carga 2 vidas
    goto    checkDifficulty          ; si no se presiono, vuelve a checar el otro boton


vidasCargadas
    ; Despliegue de vidas en la segunda linea
    ; Moverse a la posicion 5 de la segunda linea (0x45)
    bcf     RS 
    movlw   b'11000101' ; se carga el 0x45 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS			; ya se pone en 1 el RS para escribir el mensaje
    ; Se escribe el custom caracter del corazon y se forma "<3 = "
    movlw   0x02        ; parte izquierda del corazon
    call    enviaDatos
    movlw   0x03        ; parte derecha del corazon
    call    enviaDatos
    movlw   ' ' 
    call    enviaDatos
    movlw   '='
    call    enviaDatos
    movlw   ' ' 
    call    enviaDatos 

    ; Se muestra el numero de vidas 
    movf    vidas, W, A     ; se cargan las vidas al WREG (en decimal)
    addlw   d'48'           ; le sumamos un 48 decimal (30 hex) que corresponde al '0' en ASCII
    call    enviaDatos      ; se despliegan las vidas


    ; Pantalla de seleccionar numero ---------------------------------------------------------------------------------------
    ; Despliegue del numero del potenciometro en la primera linea
    ; Moverse a la posicion 7 de la primera linea (0x07)
    bcf     RS 
    movlw   b'10000111'      ; se carga el 0x07 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos       ; se envian los datos
    bsf     RS			     ; ya se pone en 1 el RS para escribir el mensaje

selecNum
RUN_ADC:
    BSF     ADCON0, 1       ; comenzar conversion
    BTFSC   ADCON0, 1       ; si no ha acabado:
    BRA     RUN_ADC         ;    atrapar ejecucion

    btfsc   ADRESH, 7, A    ; si el MSB de ADRESH esta en 1, ya se paso de 255
        goto    cargar255
    btfsc   ADRESH, 6, A    ; si el 2MSB de ADRESH esta en 1, ya se paso de 255
        goto    cargar255
	
	
    ; Merge de ADRESH y ADRESL
    
    clrf    numPot, A

    btfsc   ADRESL,6 ,A
        bsf numPot, 0, A
	nop
    btfsc   ADRESL,7 ,A
        bsf numPot, 1, A
	nop
    btfsc   ADRESH,0 ,A
        bsf numPot, 2, A
	nop
    btfsc   ADRESH,1 ,A
        bsf numPot, 3, A
	nop
    btfsc   ADRESH,2 ,A
        bsf numPot, 4, A
	nop
    btfsc   ADRESH,3 ,A
        bsf numPot, 5, A
	nop
    btfsc   ADRESH,4 ,A
        bsf numPot, 6, A
	nop
    btfsc   ADRESH,5 ,A
        bsf numPot, 7, A
	nop
    

	movff	numPot, acumulado
resta100
    movlw   0x64
    subwf   acumulado, W, A         ; Se resta 100 para sacar la centena 
    btfsc   STATUS, N, A            ; Se checa si el resultado fue negativo 
        goto	imprimecentena
    incf    contador, F, A
    movwf   acumulado, A            ; Se guarda el acumulado del num antes de que sea negativo 
    goto    resta100
resta10
    movlw   0x0A
    subwf   acumulado, W, A         ; Se resta 10 para sacar la decena
    btfsc   STATUS, N, A            ; Se checa si el resultado fue negativo 
        goto	imprimedecena
    incf    contador, F, A
    movwf   acumulado, A
    goto    resta10
 
 

AFTER_CHECK:
    btfss   botonA                  ; checa si ya se confirmo el numero elegido
        bra RUN_ADC


    ;movlw d'150'                   ;[TODO]Supongamos que el usuarios escoge el num 150 con el potenciometro
                                    ;momentareamente usaremos numeros hardcodeados para simular la seleccion de los numeros
                                    ;Esto hasta desarrollar la parte del potenciometro
    movf    numPot, W, A

    subwf   randomNumber,W, A       ;Se hace la resta y se guarda el resultado
    btfsc   STATUS,2,A              ;Se verifica si el bit dos del status es zero, de ser asÃ­ se gano el juego
        goto    gameWon
    movf    STATUS,W,A              ;Guardo lo que se genero en el STATUS despues de la operacion para despues checar si el resultado fue negativo
    movwf   resultadoResta,A
    dcfsnz  vidas, 1, A             ;Se quita una vida al jugador, de tener cero despues de esto, se acaba el juego -----MARCA MAL DECFSNZ
        goto    gameOver
    
                                    ;[TODO] Agregar logica para saber si el numero correcto es mayor o menor, tambien hace falta crear esos custom characters
    btfsc resultadoResta, 4, A      ;Validar esta logica, si es negativo salta linea
        goto arrowDown
    goto arrowUp                    ;[TODO] goto o call Â¿?


;Seccion de codigo que indica si se gano o perdio----------------------------------------------------------------------------------------

gameWon                         ; [TODO] Implementar lÃ³gica para prender el led de ganador y para regresar al menu principal
    bsf     ledWin                  ; se prende el LED de Win

    ; Guardar el numero de victorias en la EEPROM
    movlw   dirVictorias
    call    leeEEPROM
    movwf   numWins, A
    incf    numWins, F, A 
    movlw   dirVictorias
    call    escribeVictoriasEEPROM

    ; Limpiar el display y enviar al home (posicion 0)
    call    limpiaDisplay
    nop
    bcf     RS
    ; Moverse a la posicion 1 de la primera linea (0x01) 
    movlw   b'10000001' ; se carga el 0x01 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS			; ya se pone en 1 el RS para escribir el mensaje
    ; Se empieza a escribir el mensaje letra por letra 
    movlw   'V'
    call    enviaDatos
    movlw   'I'
    call    enviaDatos
    movlw   'C'
    call    enviaDatos
    movlw   'T'
    call    enviaDatos
    movlw   'O'
    call    enviaDatos
    movlw   'R'
    call    enviaDatos
    movlw   'Y'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'R'
    call    enviaDatos
    movlw   'O'
    call    enviaDatos
    movlw   'Y'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'L'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos

    bcf     RS          ; vuelve a poner el RS en 0 para mover la posicion del cursor
    ; Moverse a la posicion 4 de la segunda linea (0x44)
    movlw   b'11000100' ; se carga el 0x44 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS          ; se pone el RS en 1 para escribir los nuevos valores
    ; Se escribe el mensaje letra por letra
    movlw   'A'
    call    enviaDatos
    movlw   'G'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'I'
    call    enviaDatos
    movlw   'N'
    call    enviaDatos
    movlw   '?'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    

    bcf     RS
checkNewGame
    btfss   botonA              ; Checa si se presiono el botonA (RE0)
        goto    shifteoWin      ; Si no se ha presionado, shiftea la LCD
    bcf     ledWin              ; Si se presiona, apaga el led y reinicia el juego
    bsf     RS
    goto    reiniciaJuego       ; Reinicia el juego

shifteoWin                      ; Hace un shift de la pantalla
    movlw   b'00011000'
    call    enviaDatos
    goto    checkNewGame


gameOver                         ;[TODO] Implementar lÃ³gica para prender el led de perdedor y para regresar al menu principal
    bsf ledLose

    ; Guardar el numero de defeats en la EEPROM
    movlw   dirDerrotas
    call    leeEEPROM
    movwf   numDefeats, A
    incf    numDefeats, F, A 
    movlw   dirDerrotas
    call    escribeDerrotasEEPROM

    ; Limpiar el display y enviar al home (posicion 0)
    call    limpiaDisplay
    nop
    bcf     RS
    ; Moverse a la posicion 3 de la primera linea (0x03) 
    movlw   b'10000011' ; se carga el 0x04 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS			; ya se pone en 1 el RS para escribir el mensaje
    ; Se empieza a escribir el mensaje letra por letra 
    movlw   'G'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'M'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'O'
    call    enviaDatos
    movlw   'V'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'R'
    call    enviaDatos
    movlw   '!'
    call    enviaDatos

    bcf     RS          ; vuelve a poner el RS en 0 para mover la posicion del cursor
    ; Moverse a la posicion 4 de la segunda linea (0x44)
    movlw   b'11000100' ; se carga el 0x44 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS          ; se pone el RS en 1 para escribir los nuevos valores
    ; Se escribe el mensaje letra por letra
    movlw   'R'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'T'
    call    enviaDatos
    movlw   'R'
    call    enviaDatos
    movlw   'Y'
    call    enviaDatos
    movlw   '?'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    
    bcf     RS
checkRetry
    btfss   botonA              ; Checa si se presiono el botonA (RE0)
        goto    shifteoLose      ; Si no se ha presionado, vuelve a checar 
    bcf     ledLose             ; Si se presiona, apaga el led y reinicia el juego
    bsf     RS
    goto    reiniciaJuego       ; Reinicia el juego

shifteoLose                      ; Hace un shift de la pantalla
    movlw   b'00011000'
    call    enviaDatos
    goto    checkRetry

    ; Despliegue de flechas hacia arriba -----------------------------------------------------------------------------------
arrowUp
    ; Moverse a la posicion 3 de la primera linea (0x03) para desplegar flecha hacia arriba
    bcf     RS
    movlw   b'10000011'     ; se carga el 0x03 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS			    ; ya se pone en 1 el RS para escribir el mensaje
    ; Se escriben 4 flechas hacia arriba en la primera linea de la LCD
    movlw   0x00
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   0x00
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   0x00
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   0x00
    call    enviaDatos

    ; Moverse a la posicion 10 de la segunda linea (0x50) para desplegar nuevo numero de vidas
    bcf     RS
    movlw   b'11010000'     ; se carga el 0x50 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS			    ; ya se pone en 1 el RS para escribir el mensaje
    ; Se escribe la nueva cantidad de vidas
    movf    vidas, W, A     ; se cargan las vidas al WREG (en decimal)
    addlw   d'48'           ; le sumamos un 48 decimal (30 hex) que corresponde al '0' en ASCII
    call    enviaDatos      ; se despliegan las vidas

checkArrowUp ; cambio de pantalla al presionar el boton RE0
    btfss   botonA          ; checa si se presiono el boton para pasar de pantalla
        goto    checkArrowUp ; si no se presiono, se queda esperando
    goto    selecNum        ; si se presiona, cambia de pantalla y se regresa a seleccionar un numero



    ; Despliegue de las flechas hacia abajo --------------------------------------------------------------------------------

arrowDown
; Moverse a la posicion 3 de la primera linea (0x03) para desplegar flecha hacia abajo
    bcf     RS
    movlw   b'10000011' ; se carga el 0x03 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS			; ya se pone en 1 el RS para escribir el mensaje
    ; Se escriben 4 flechas hacia abajo en la primera linea de la LCD
    movlw   0x01
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   0x01
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   0x01
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   0x01
    call    enviaDatos

    ; Moverse a la posicion 10 de la segunda linea (0x50) para desplegar nuevo numero de vidas
    bcf     RS
    movlw   b'11010000'     ; se carga el 0x50 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS			    ; ya se pone en 1 el RS para escribir el mensaje
    ; Se escribe la nueva cantidad de vidas
    movf    vidas, W, A     ; se cargan las vidas al WREG (en decimal)
    addlw   d'48'           ; le sumamos un 48 decimal (30 hex) que corresponde al '0' en ASCII
    call    enviaDatos      ; se despliegan las vidas

checkArrowDown ; cambio de pantalla al presionar el boton RE0
    btfss   botonA          ; checa si se presiono el boton para pasar de pantalla
        goto    checkArrowDown ; si no se presiono, se queda esperando
    goto    selecNum        ; si se presiona, cambia de pantalla y se regresa a seleccionar un numero



    ; Pantalla para ver el Marcador ----------------------------------------------------------------------------------------

viewScore ; se muestra el marcador en la pantalla del LCD (Falta lo de la memoria de la EEPROM)
    ; Limpiar el display y enviar al home (posicion 0)
    call    limpiaDisplay
    nop
    ; Moverse a la posicion 0 de la primera linea (0x00) 
    movlw   b'10000000'     ; se carga el 0x00 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS			    ; ya se pone en 1 el RS para escribir el mensaje
    ; Se empieza a escribir el mensaje letra por letra 
    movlw   'W'
    call    enviaDatos
    movlw   'I'
    call    enviaDatos
    movlw   'N'
    call    enviaDatos
    movlw   'S'
    call    enviaDatos
    movlw   ':'
    call    enviaDatos
    movlw   dirVictorias
    call    leeEEPROM
    addlw   d'48'
    call    enviaDatos
    bcf     RS              ; vuelve a poner el RS en 0 para mover la posicion del cursor
    ; Moverse a la posicion 12 de la primera linea (0x11)
    movlw   b'10010001'     ; se carga el 0x12 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS              ; se pone el RS en 1 para escribir los nuevos valores
    ; Se escribe el mensaje letra por letra
    movlw   'R'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'S'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'T'
    call    enviaDatos
    bcf     RS              ; vuelve a poner el RS en 0 para mover la posicion del cursor
    ; Moverse a la posicion 0 de la segunda linea (0x40)
    movlw   b'11000000'     ; se carga el 0x40 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS              ; se pone el RS en 1 para escribir los nuevos valores
    ; Se escribe el mensaje letra por letra
    movlw   'D'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'F'
    call    enviaDatos
    movlw   'E'
    call    enviaDatos
    movlw   'A'
    call    enviaDatos
    movlw   'T'
    call    enviaDatos
    movlw   'S'
    call    enviaDatos
    movlw   ':'
    call    enviaDatos
    movlw   ' '
    call    enviaDatos
    movlw   dirDerrotas
    call    leeEEPROM
    addlw   d'48'
    call    enviaDatos
    bcf     RS              ; vuelve a poner el RS en 0 para mover la posicion del cursor
    ; Moverse a la posicion 14 de la segunda linea (0x53)
    movlw   b'11010011'     ; se carga el 0x53 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos      ; se envian los datos
    bsf     RS              ; se pone el RS en 1 para escribir los nuevos valores
    ; Se escribe el mensaje letra por letra
    movlw   'R'
    call    enviaDatos
    movlw   'B'
    call    enviaDatos
    movlw   '1' 
    call    enviaDatos

checkBotonScore
    btfsc   botonA          ; checa si se presiona el botonA
        goto afterScore     ; si se presiona, se regresa al menu
    btfsc   botonB          ; si no, checa si se presiona el botonB
        goto resetScore     ; si se presiona, resetea el marcador
    goto    checkBotonScore ; si no, vuelve a checar el botonA

    
    ; Creación de custom characters para LCD -------------------------------------------------------------------------------
crearCustoms
    bcf     RS
    movlw   b'01000000'       ; va a la direccion 0x00 de la CGRAM 
    call    enviaDatos
    ; Creación de la Flecha hacia arriba (Caracter 0x00)
    bsf     RS
    movlw   b'00000000'
    call    enviaDatos
    movlw   b'00000100'
    call    enviaDatos
    movlw   b'00001110'
    call    enviaDatos
    movlw   b'00011111'
    call    enviaDatos
    movlw   b'00001110'
    call    enviaDatos
    movlw   b'00001110'
    call    enviaDatos
    movlw   b'00001110'
    call    enviaDatos
    movlw   b'00000000'
    call    enviaDatos
    ; Creación de la Flecha hacia abajo (Caracter 0x01)
    movlw   b'00000000'
    call    enviaDatos
    movlw   b'00001110'
    call    enviaDatos
    movlw   b'00001110'
    call    enviaDatos
    movlw   b'00001110'
    call    enviaDatos
    movlw   b'00011111'
    call    enviaDatos
    movlw   b'00001110'
    call    enviaDatos
    movlw   b'00000100'
    call    enviaDatos
    movlw   b'00000000'
    call    enviaDatos
    ; Creación de la parte izquierda del corazon (Caracter 0x02)
    movlw   b'00000110'
    call    enviaDatos
    movlw   b'00001111'
    call    enviaDatos
    movlw   b'00011111'
    call    enviaDatos
    movlw   b'00011111'
    call    enviaDatos
    movlw   b'00001111'
    call    enviaDatos
    movlw   b'00000111'
    call    enviaDatos
    movlw   b'00000011'
    call    enviaDatos
    movlw   b'00000001'
    call    enviaDatos
    ; Creación de la parte derecha del corazon (Caracter 0x03)
    movlw   b'00001100'
    call    enviaDatos
    movlw   b'00011110'
    call    enviaDatos
    movlw   b'00011111'
    call    enviaDatos
    movlw   b'00011111'
    call    enviaDatos
    movlw   b'00011110'
    call    enviaDatos
    movlw   b'00011100'
    call    enviaDatos
    movlw   b'00011000'
    call    enviaDatos
    movlw   b'00010000'
    call    enviaDatos


    bcf     RS  ; regresar RS a 0 porque asi estaba antes del call
    return      ; regresa del call de la linea 95 y continua con la inicializacion del codigo
    


    ; Subrutina para limpiar el display y enviar a la posicion 0 -----------------------------------------------------------
limpiaDisplay
    bcf     RS
    bcf     RW
    bsf     E
    movlw   b'00000001'
    movwf   dataLCD
    nop
    bcf     E
    call    ret2ms
    nop
    return



    ; Subrutina para protocolo de envio de datos al LCD --------------------------------------------------------------------
enviaDatos 
    bcf     RW
    bsf     E
    movwf   dataLCD
    nop
    bcf     E
    call    ret40
    movlw   .247
    movwf   0x32, A
    
    ; Retardos para LCD ----------------------------------------------------------------------------------------------------
ret40 incf  0x32, F, A
    btfss   STATUS, 1
    goto    ret40
    return
    
ret1ms movlw .8
    movwf   0x33, A
incRut incf 0x33, F, A
    btfss   STATUS, 2
    goto    incRut
    return
    
ret2ms call ret1ms
    call    ret1ms
    return
    

    ; Subrutina para cargar vidas segun la dificultad ----------------------------------------------------------------------
carga6vidas
    movlw   d'6'                    ; se carga la cantidad de vidas
    movwf   vidas  
    goto    vidasCargadas

carga2vidas
    movlw   d'2'                    ; se carga la cantidad de vidas
    movwf   vidas  
    goto    vidasCargadas


    ; Subrutinas para EEPROM ----------------------------------------------------------------------------------------------------

escribeDerrotasEEPROM
    movwf   EEADR, A
    movff   numDefeats,EEDATA
    movlw   b'00000100'     ; Habilita Write
    movwf   EECON1, A
    bcf     RCON, 7, A      ; Deshabilitar interrupciones
    bcf     RCON, 6, A      ; Deshabilitar interrupciones
    movlw   0x55            ; Contraseñas
    movwf   EECON2, A
    movlw   0x0AA
    movwf   EECON2, A
    bsf     EECON1, WR, A    ; Empieza a escribir
    bsf     RCON, 7, A      ; Habilitar interrupciones
    bsf     RCON, 6, A      ; Habilitar interrupciones
waitwriteD
    btfsc   EECON1, WR, A    ; revisa si ya termino de escribir
        goto waitwriteD
    bcf     EECON1, 2, A
    clrf    EEDATA, A       ; Para verificar que se cargue el dato

    return

escribeVictoriasEEPROM
    movwf   EEADR, A
    movff   numWins,EEDATA
    movlw   b'00000100'     ; Habilita Write
    movwf   EECON1, A
    bcf     RCON, 7, A      ; Deshabilitar interrupciones
    bcf     RCON, 6, A      ; Deshabilitar interrupciones
    movlw   0x55            ; Contraseñas
    movwf   EECON2, A
    movlw   0x0AA
    movwf   EECON2, A
    bsf     EECON1, WR, A   ; Comienza a escribir
    bsf     RCON, 7, A      ; Habilitar interrupciones
    bsf     RCON, 6, A      ; Habilitar interrupciones
waitwriteV
    btfsc   EECON1, WR, A    ; revisa si ya termino de escribir
        goto waitwriteV
    bcf     EECON1, 2, A
    clrf    EEDATA, A       ; Para verificar que se cargue el dato

    return


leeEEPROM:                  ;Hay que cargar la direccion antes de mandar a llamar
    movwf   EEADR, A
    movlw   b'00000001'
    movf    EEDATA, W, A
    return

    ; Subrutina para resetear el marcador ---------------------------------------------------------------------------------- 
resetScore
    ; Pone en 0 el numero de victorias de la EEPROM
    movlw   d'0' 
    movwf   numDefeats, A
    movwf   numWins, A
    movlw   dirDerrotas
    call    escribeDerrotasEEPROM
    movlw   dirVictorias
    call    escribeVictoriasEEPROM
    goto    viewScore


    ; Subrutina para cargar centena ----------------------------------------------------------------------------------------
imprimecentena 
    movf    contador, W, A
    addlw   0x30
    call    enviaDatos
    clrf    contador, A
    goto    resta10

    ; Subrutina para cargar centena ----------------------------------------------------------------------------------------
imprimedecena 
    movf    contador, W, A
    addlw   0x30
    call    enviaDatos
    movf    acumulado, W, A
    addlw   0x30
    call    enviaDatos
    goto    AFTER_CHECK    



    ; Subrutina para cargar un 255 -----------------------------------------------------------------------------------------
cargar255: 
    movlw   '2'
    call    enviaDatos
    movlw   '5'
    call    enviaDatos
    movlw   '5'
    call    enviaDatos

    ; Selecciona la direccion para escribir el siguiente caracter
    ; Moverse a la posicion 7 de la primera linea (0x07)
    bcf     RS 
    movlw   b'10000111' ; se carga el 0x07 en binario, el b7 es 1 por sintaxis de Set DDRAM address
    call    enviaDatos  ; se envian los datos
    bsf     RS			; ya se pone en 1 el RS para escribir el mensaje

    goto AFTER_CHECK
    
    ; Rutinas de interrupciones --------------------------------------------------------------------------------------------
    ;org 0x100
aborto
    bcf INTCON3, 1, A   ;Se apaga la bandera
    goto reiniciaJuego
    retfie
    
    end

