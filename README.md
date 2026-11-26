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
- Líneas adicionales, sostenidos/bemoles y octava exacta (si no la activas, cualquier G vale).
- Mostrar: partitura, nombre (G, C-E-G, G → D → E) o ambos. Nombres en C D E o Do Re Mi.
- En los acordes hay que mantener las teclas pulsadas a la vez.
- Metrónomo: tempo (40–200 BPM), compás (2/4, 3/4, 4/4, 6/8) y tiempo por nota (1 tiempo, 2 tiempos, 1 compás, 2 compases). Empieza con un compás de cuenta; si no tocas a tiempo, el ejercicio cuenta como sin tiempo y pasa al siguiente.
- "Escuchar" reproduce el ejercicio como pista; ese ejercicio vale la mitad.

## Puntaje

10 pts por nota × precisión (−30% por fallo) × velocidad × racha (×2 desde 5 seguidas sin fallo, ×3 desde 10, ×4 desde 15) × ½ si usaste la pista.
Velocidad: sin metrónomo, premia la rapidez; con metrónomo, premia más tempo y menos tiempo por nota. Récords (puntaje y racha) se guardan en el dispositivo.
