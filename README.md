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
