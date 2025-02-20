;-----------------------------------------------
; Universidad del Valle de Guatemala
; IE2023: Programacion de Microcontroladores
; Laboratorio2.asm

; Autor: Alma Mata Ixcayau
; Proyecto: Laboratorio 2
; Descripcion: Contador binario de 4 bits que incrementa
;	cada 100ms. Incluye otro contador que se muestra en un 7 segmentos
;	cuando son iguales, se activa una alarma
; Hardware: ATMEGA328P
; Creado: 14/02/2025
; Ultima modificacion: 19/02/2025
;-----------------------------------------------

// Encabezado. Define registros, variables y constantes
.include "M328PDEF.inc"
.cseg
.org 0x0000
.def COUNTER = R20		// Contador para el timer0
.def CONTADOR7 = R21	// Variable contador del display
.def SALIDA7 = R23		// Salida para el display
// Configurar de PILA
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R16, HIGH(RAMEND)
OUT SPH, R16
// Tabla de valores del display de 7 segmentos
Tabla7seg: .db 0x40, 0x79, 0x24, 0x30, 0x19, 0x12, 0x02, 0x78, 0x00, 0x10, 0x08, 0x03, 0x46, 0x21, 0x06, 0x0E
// Configuracion inicial
SETUP:
	// Configuración del CLOCK en 1 MHz
	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16				// Habilita cambios en el PRESCALER
	LDI		R16, 0x04
	STS		CLKPR, R16				// Configura el prescalar a 16 F_cpu = 1MHz

	// Inicializacion del timer 0
	CALL INIT_TMR0

	// PORTC como entrada con pull-up habilitado
	LDI		R16, 0x00
	OUT		DDRC, R16	// Establecer puerto C como entrada
	LDI		R16, 0xFF
	OUT		PORTC, R16	// Habilitar pull-ups en puerto C

	// PORTB como salida inicialmente apagado
	LDI		R16, 0xFF
	OUT		DDRB, R16			// Establecer puerto B como salida
	LDI		R16, 0x00 
	OUT		PORTB, R16			// Todos los bits del puerto B están apagados

	// PORTD como salida inicial "0" en display
	LDI		R16, 0xFF
	OUT		DDRD, R16	// Establecer puerto D como salida
	LDI		R16, 0b00011000 
	OUT		PORTD, R16	// Todos los bits del puerto D están encendidos
	
	// Deshabilitar serial (apaga los otros LEDS del Arduino)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	// Inicializacion de variables
	LDI		R17, 0x7F			// Variable que guarda el estado de los botones
	LDI		R18, 0x00			// Variable para el contador de 4 bits
	LDI		CONTADOR7, 0x00		// Contador display 7 segmentos
	LDI		R24, 0x00			// Contador repetir cada segundo
	LDI		R25, 0x00			// Alarma de match
	LDI		R26, 0x00			// Salida contador de 4 bits

/****************************************/
// Loop Infinito
MAIN:
	// Bloque que espera el Overflow del timer
	IN		R16, TIFR0
	CALL	CONTADOR_DISPLAY	// Se llama al bloque del contador del display
	SBRS	R16, TOV0
	RJMP	MAIN
	SBI		TIFR0, TOV0		// Limpiar bandera de "overflow"
	LDI		R16, 100
	OUT		TCNT0, R16		// Volver a cargar valor inicial en TCNT0
	INC		COUNTER
	CPI		COUNTER, 10		// R20 = 10 after 100ms (since TCNT0 is set to 10 ms)
	BRNE	MAIN
	CLR		COUNTER			// Limpia contador para el nuevo ciclo
	INC		R24
	CPI		R24, 10			// R24 cuenta hasta que se cumpla un segundo
	BRNE	MAIN
	CLR		R24
	CALL	CONTADOR		// Contador de 4 bits
	RJMP	MAIN

/****************************************/
// Sub rutinas sin interrupcion
ALARMA:
	LDI		R18, 0x00		// Resetea el valor del contador de 4 bits
	SWAP	R25				// Swap del registro 000X0000 --> 0000000X
	INC		R25				// Aumento del valor de la alarma
	ANDI	R25, 0x01		// Mascara para el ultimo bit
	SWAP	R25				// Regresa al estado inicial
	RJMP	SALIDA_4BITS	// Llama a la salida del PORT B

CONTADOR:
	CP		CONTADOR7, R18	// Compara ambos contadores
	BREQ	ALARMA			// De ser iguales salta a ALARMA
	INC		R18				// Incremento del contador de 4 bits
	ANDI	R18, 0x0F		// Mascara para no superar 4 bits
SALIDA_4BITS:
	MOV		R26, R18		// Copia al primer contador en el registro de salida
	OR		R26, R25		// Combina contador y alarma
	OUT		PORTB, R26		// Muestra la salida en los LEDS
	RET

CONTADOR_DISPLAY:
	IN		R22, PINC
	CP		R17, R22	// Comparación entre estado nuevo y estado viejo
	BREQ	RESULTADO		// Regresa al inicio
	CALL	DELAY		// Pequeño delay de confirmación
	IN		R22, PINC	// Se repite para confirmar el cambío de estado
	CP		R17, R22	
	BREQ	RESULTADO		// Regresa al inicio
	MOV		R17, R22	// Guarda el estado viejo para futura comparación

	// Lógica para aumento o decremento del contador
	SBRS	R22, 0		// Salta si Bit 0 de PORTC esta en 1 (apagado)
	INC		CONTADOR7
	SBRS	R22, 1		// Salta si Bit 1 de PORTC esta en 1 (apagado)
	DEC		CONTADOR7
	ANDI	CONTADOR7, 0x0F
RESULTADO:
	LDI		ZH, HIGH(Tabla7seg<<1)	// Parte alta de Tabla7seg que esta en la Flash
	LDI		ZL, LOW(Tabla7seg<<1)	// Parte baja de la tabla
	ADD		ZL, CONTADOR7			// Suma el contador al puntero Z
	LPM		SALIDA7, Z				// Copia el valor del puntero
	OUT		PORTD, SALIDA7			// Muestra la salida en PORT D
	RET		// Regresa

INIT_TMR0:
	LDI		R16, (1<<CS01) | (1<<CS00)
	OUT		TCCR0B, R16					// Setear prescaler del TIMER 0 a 64
	LDI		R16, 100
	OUT		TCNT0, R16					// Cargar valor inicial en TCNT0
	RET

// Sub rutina de interrupción
DELAY:
	LDI		R19, 0xFF
SUB_DELAY1:
	DEC		R19
	CPI		R19, 0
	BRNE	SUB_DELAY1
	LDI		R19, 0xFF
SUB_DELAY2:
	DEC		R19
	CPI		R19, 0
	BRNE	SUB_DELAY2
	LDI		R19, 0xFF
SUB_DELAY3:
	DEC		R19
	CPI		R19, 0
	BRNE	SUB_DELAY3
	RET					// Regresa a donde fue llamado