# Lectura de piano (iOS)

App SwiftUI (iOS 17) para practicar lectura de partituras: muestra una nota, intervalo, tríada o progresión (máx. 5 notas) en clave de sol o de fa, y tú la tocas en tu piano.

- Cuenta fallos; si fallas, repites el mismo ejercicio al instante.
- Mide el tiempo de cada ejercicio y al final muestra un resumen: promedio, las más lentas y las que tuvieron fallos.
- Entrada MIDI con CoreMIDI: piano por USB (adaptador Lightning/USB-C) o Bluetooth MIDI. Si no hay piano, usa el teclado en pantalla.

## Generar el proyecto

```bash
brew install xcodegen
xcodegen generate
open PianoReader.xcodeproj
```

En Xcode elige tu Team en Signing. Bundle id: `com.amiguel.pianoreader`.

## Ajustes

- Clave: sol, fa o ambas.
- Ejercicios: nota, dos notas, tríada o progresión (de 2 a 5 notas). Si eliges varios, se mezclan.
- Tonalidades: elige una o varias armaduras (de 7♭ a 7♯); cada ejercicio usa una al azar y las notas siguen la armadura (en Sol mayor, el F se toca F♯).
- Alteraciones accidentales (♯ ♭ ♮) que se apartan de la armadura y duran hasta la barra de compás, en todos los modos.
- Líneas adicionales y octava exacta (si no la activas, cualquier G vale).
- Mostrar: partitura, nombre (G, C-E-G, G → D → E) o ambos. Nombres en C D E o Do Re Mi.
- En los acordes hay que mantener las teclas pulsadas a la vez.
- Metrónomo: tempo (40–200 BPM), compás (2/4, 3/4, 4/4, 6/8) y tiempo por nota (1 tiempo, 2 tiempos, 1 compás, 2 compases). Empieza con un compás de cuenta; si no tocas a tiempo, el ejercicio cuenta como sin tiempo y pasa al siguiente.
- "Escuchar" reproduce el ejercicio como pista; ese ejercicio vale la mitad.

## Práctica (un solo modo)

Muestra 1 o 2 compases con figuras: negras, blancas, redondas, corcheas, semicorcheas, puntillo, saltillo, tresillos, silencios, ligaduras de prolongación y de expresión (cada figura se activa en Configuración). El metrónomo no para: un compás de cuenta y luego tocas el compás; una línea azul marca por dónde vas.

- Cada nota se juzga por cuándo empieza: perfecto (±60 ms), bien (±130 ms), adelantado/atrasado, nota equivocada o no tocada. Tocar notas que no están en el compás cuenta como nota de más.
- Duración: soltar la nota antes del 60% de su valor es error. Una nota ligada no se vuelve a tocar y se mantiene todo su valor. Con legato hay que mantener cada nota hasta la siguiente.
- Si el compás no sale perfecto, se repite (se puede desactivar).
- Puntos: 10 perfecta, 7 bien, 4 adelantada/atrasada, −5 por nota de más; × tempo × racha × ½ con pista.
- Usa la hora de llegada de cada mensaje MIDI; con el teclado en pantalla la medición es menos precisa.

## Puntaje

10 pts por nota × precisión (−30% por fallo) × velocidad × racha (×2 desde 5 seguidas sin fallo, ×3 desde 10, ×4 desde 15) × ½ si usaste la pista.
Velocidad: sin metrónomo, premia la rapidez; con metrónomo, premia más tempo y menos tiempo por nota. Récords (puntaje y racha) se guardan en el dispositivo.

## Créditos

Sonido de piano: "Upright Piano KW" de [FreePats](https://freepats.zenvoid.org/Piano/acoustic-grand-piano.html), dominio público (CC0).
