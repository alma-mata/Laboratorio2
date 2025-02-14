;-----------------------------------------------
; Universidad del Valle de Guatemala
; IE2023: Programacion de Microcontroladores
; Laboratorio2.asm

; Autor: Alma Mata Ixcayau
; Proyecto: Laboratorio 2
; Descripcion: Contador binario de 4 bits que incrementa
;	cada 100ms
; Hardware: ATMEGA328P
; Creado: 14/02/2024
; Ultima modificacion: 
;-----------------------------------------------

// Encabezado. Define registros, variables y constantes
.include "M328PDEF.inc"
.cseg
.org 0x0000
.def COUNTER = R20		// Contador para el timer0
// Configurar de PILA
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R16, HIGH(RAMEND)
OUT SPH, R16

SETUP:
	// Configuración del CLOCK en 1 MHz
	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16				// Habilita cambios en el PRESCALER
	LDI		R16, 0x04
	STS		CLKPR, R16				// Configura el prescalar a 16 F_cpu = 1MHz

	// Inicializacion del timer 0
	CALL INIT_TMR0

	// PORTB como salida inicialmente apagado
	LDI		R16, 0xFF
	OUT		DDRB, R16			// Establecer puerto B como salida
	LDI		R16, 0x00 
	OUT		PORTB, R16			// Todos los bits del puerto B están apagados

	// Deshabilitar serial (apaga los otros LEDS del Arduino)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	LDI		R18, 0x00		// Variable para el contador de 4 bits

/****************************************/
// Loop Infinito
MAIN:
	// Bloque que espera el Overflow del timer
	IN		R16, TIFR0
	SBRS	R16, TOV0
	RJMP	MAIN
	SBI		TIFR0, TOV0		// Limpiar bandera de "overflow"
	LDI		R16, 100
	OUT		TCNT0, R16		// Volver a cargar valor inicial en TCNT0
	INC		COUNTER
	CPI		COUNTER, 10		// R20 = 10 after 100ms (since TCNT0 is set to 10 ms)
	BRNE	MAIN
	CLR		COUNTER			// Limpia contador para el nuevo ciclo
	CALL	CONTADOR
	RJMP	MAIN

/****************************************/
// Sub rutinas sin interrupcion
CONTADOR:
	INC		R18
	ANDI	R18, 0x0F
	OUT		PORTB, R18
	RET

INIT_TMR0:
	LDI		R16, (1<<CS01) | (1<<CS00)
	OUT		TCCR0B, R16					// Setear prescaler del TIMER 0 a 64
	LDI		R16, 100
	OUT		TCNT0, R16					// Cargar valor inicial en TCNT0
	RET