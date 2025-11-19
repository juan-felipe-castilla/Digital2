# Seguidor de Sol Automático (Solar Tracker)

## Trabajo Final Digital 2

### 1. Introducción y Objetivo del Proyecto

El **Seguidor de Sol Automático** (o *Solar Tracker*) es un sistema electromecánico diseñado para **orientar un panel** hacia la posición óptima del sol a lo largo del día. El objetivo principal de este proyecto es **maximizar la eficiencia de captación de energía lumínica** 

### 2. Marco Conceptual y Principios de Funcionamiento

#### 2.1. Principio Básico

El sistema se basa en la comparación de la intensidad lumínica detectada por dos **resistencias dependientes de la luz (LDRs)**. La diferencia en la lectura de voltaje entre los sensores indica la dirección en la que debe moverse el sistema para alinearse con la fuente de luz más intensa.

#### 2.2. Arquitectura de Control

Se implementa un PIC16F887 que ajusta la posición de un servomotor, en relación a las LDR conectadas, el mismo modula el pulso de salida en relación a la diferencia de potencial entre las resistencias variables.

### 3. Componentes de Hardware y Software

| Tipo | Componente | Descripción |
| :--- | :--- | :--- |
| **Microcontrolador** | PIC16f887 | Plataforma de desarrollo principal para procesar las lecturas y controlar los actuadores. |
| **Sensores** | Resistencias LDR (x2) | Utilizadas para detectar la intensidad lumínica y el diferencial de luz. |
| **Actuadores** | Servomotores (x1) | Para el eje vertical 
| **Otros** | Resistencias (10kΩ), Cables de conexión, Protoboard, Estructura de soporte, Display de 7 segmentos, placas experimentales, componentes pertinentes para la configuración y optimo funcionamiento de microcontrolador.
| **Software** | **MPLAB y AN1310** | Entorno de desarrollo para la programación y carga del código. |
| **Lenguaje** | **ASSEMBLER** Lenguaje de programación utilizado para implementar la lógica de control. |

### 4. Montaje e Instalación
El montaje en primera instancia fue realizado integramente en protoboard, luego de esto implementamos un "modulo" realizado en una placa experimental el cual se encargaba del control y polarización del módulo de 7 segmentos, este siendo practiamente indispensable para montarlo en un chasis, ya que en protoboard no teniamos forma de que el mismo se vea de la externa.
La imagen adjunta es del montaje en protoboard y ese módulo mencionado, el mismo está realizado completamente con cables macho-macho, por eso se ve un poco desprolijo, tenemos intenciones de en un futuro, poder realizar las placas impresas, las cuales se encuentran el repositorio, son funcionales, pero por temas de no poseer las herramientas adecuadas, traian más problemas q soluciones.

<p align="center">
  <img src="Imagenes/montaje.jpeg" width="400">
</p>

Estas son Imagenes de los circuitos

**LDR**
<p align="center">
  <img src="Imagenes/LDR.jpeg" width="400">
</p>

**7 Segmentos**
<p align="center">
  <img src="Imagenes/Modulo.jpeg" width="400">
</p>


**Configuración del PIC**
<p align="center">
  <img src="Imagenes/Diagrama_LEV.png" width="400">
</p>

**PCB de LDR Y 7SEG**
<p align="center">
  <img src="Imagenes/pcb.jpeg" width="400">
</p>



### 5. Diagrama de Flujo del Código
```mermaid
flowchart TD

%% === SETUP ===
A([Inicio]) --> B[Configurar Puertos I/O]
B --> C[Configurar ADC]
C --> D[Configurar Timer0]
D --> E[Configurar Interrupciones]
E --> F([Loop Principal])

%% === LOOP ===
F --> G[Leer ADC0]
G --> H[Leer ADC1]
H --> I{ADC0 > ADC1?}

%% === DECISIONES DEL SERVO ===
I -- Sí --> J[Mover Servo →]
I -- No --> K[Mover Servo ←]

J --> L[Actualizar PWM]
K --> L

L --> F

%% === INTERRUPCIONES ===
E --> M[[INT0]]
M --> N[Ejecutar VERIFICARP]
N --> O([Retornar de Interrupción])

E --> P[[Interrupción TMR0]]
P --> Q[Incrementar contador]
Q --> R[Chequear desbordes / flags]
R --> S([Retornar de Interrupción])

%% === ADC FUNCION ===
G -.-> T[[Función ADC]]
H -.-> T
T --> U[Iniciar conversión]
U --> V[Esperar fin de conversión]
V --> W[Leer ADRESH/ADRESL]
W --> X[Retornar valor]




### 6. Conclusión

El proyecto Seguidor de Sol cumplió con los objetivos planteados, demostrando la aplicación práctica de los conocimientos de la materia Digital 2 en el sensado (LDRs), el procesamiento de señales (Microcontrolador) y la actuación (Servomotores). La implementación de la lógica de control digital permite una respuesta eficiente a los cambios de la fuente de luz.

---

## Autores 

Este proyecto fue desarrollado por:

|  | Nombre |   |
| :--- | :--- | :--- |
| Alumno | **Juan Felipe Castilla** | [GitHub: @juan-felipe-castilla]((https://github.com/juan-felipe-castilla)) |
| Alumno | **Agustín Dalmazzo** | [GitHub: @agustindalmazzo-cyber](https://github.com/agustindalmazzo-cyber) |
| Alumno | **Benjamín Viberti** | [GitHub: @benjaviberti](https://github.com/benjaviberti) |



---
