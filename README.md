# Lectura de piano (iOS)

App SwiftUI (iOS 17) para practicar lectura de partituras en el piano: muestra uno o dos compases con figuras, notas sueltas, intervalos o tríadas, en clave de sol o de fa, y tú los tocas en tu piano (MIDI por USB o Bluetooth) o en el teclado en pantalla.

## Generar el proyecto

```bash
brew install xcodegen
xcodegen generate
open PianoReader.xcodeproj
```

En Xcode elige tu Team en Signing. Bundle id: `com.amiguel.pianoreader`.

## Cómo funciona (un solo modo)

- **Sin metrónomo:** tocas las notas en orden a tu ritmo. Si fallas, cuenta el fallo y repites esa nota al instante. Se mide el tiempo por nota.
- **Con metrónomo:** un compás de cuenta y se juzga cuándo empieza cada nota (perfecto ±60 ms, bien ±130 ms, adelantado/atrasado, equivocada, no tocada, de más) y cuánto se mantiene (soltar antes del 60% de su valor, ligaduras, legato). Si el compás no sale perfecto, se repite (se puede desactivar).
- El metrónomo se enciende/apaga, y el tempo y el compás se cambian durante la práctica (toca el botón de BPM).
- Se muestra en azul lo que tocas: en el pentagrama, con su nombre y en el teclado en pantalla.
- "Escuchar" reproduce el ejercicio con sonido de piano; ese ejercicio vale la mitad.

## Niveles

Diez niveles que aplican todos los ajustes de una vez (luego se puede cambiar lo que sea; el nombre de las notas queda a tu elección):

1. Primer contacto: mano derecha, Do mayor, notas sueltas, negras, blancas y redondas, con nombre, sin metrónomo.
2. Clave de fa y sin ayudas: mano izquierda, silencios, octava exacta, solo partitura.
3. Dos manos y 3/4: compases 2/4, 3/4 y 4/4 al azar, metrónomo a 60, repetir si fallas.
4. Grupo 1 e intervalos: Do, Sol, Fa, dos notas, corcheas, 65 BPM.
5. Acordes y fluidez: 2 compases, tríadas, ligaduras de prolongación, 70 BPM, sin repetir.
6. Grupo 2 (sostenidos): Re, La, Mi, puntillo, ligaduras de expresión, alteraciones, 75 BPM.
7. Grupo 3 (bemoles): Si♭, Mi♭, La♭, semicorcheas, saltillo, líneas adicionales, 80 BPM.
8. Compás compuesto: hasta 4♯/4♭, 6/8, tresillos, 85 BPM.
9. Armaduras complejas: Si, Fa♯, Re♭, Sol♭, 95 BPM.
10. Primera vista total: todas las tonalidades, 110 BPM.

Niveles 1–4: 10 ejercicios por sesión; desde el 5: 20.

## Ajustes

- Mano: derecha (clave de sol), izquierda (clave de fa) o ambas (pentagrama doble; lo que empieza a la vez en las dos manos se toca junto, la izquierda con ritmo más sencillo). Tonalidades: una o varias armaduras (de 7♭ a 7♯).
- Notas y acordes: nota suelta, dos notas, tríada (se mezclan dentro del compás). En los acordes hay que mantener las teclas a la vez.
- Figuras: negras siempre; blancas y redondas, corcheas, semicorcheas, puntillo, saltillo, tresillos, silencios, ligaduras de prolongación y de expresión. 1 o 2 compases.
- Alteraciones accidentales (♯ ♭ ♮), líneas adicionales y octava exacta.
- Mostrar: partitura, nombre o ambos; nombres en C D E o Do Re Mi.
- Metrónomo: tempo 40–200 BPM, uno o varios compases (2/4, 3/4, 4/4, 6/8; con varios, cada ejercicio sale en uno al azar), sonido de clic.

## Puntaje

- Sin metrónomo: 10 por nota (−30% por fallo en esa nota) × rapidez (×1.5 si < 1.5 s por nota, ×1.25 si < 3 s).
- Con metrónomo: 10 perfecta, 7 bien, 4 adelantada/atrasada, −5 por nota de más; × tempo.
- Todo × racha (ejercicios perfectos seguidos: ×2 desde 5, ×3 desde 10, ×4 desde 15) × ½ si usaste la pista. Récords guardados en el dispositivo.

## Créditos

Sonido de piano: "Upright Piano KW" de [FreePats](https://freepats.zenvoid.org/Piano/acoustic-grand-piano.html), dominio público (CC0).
