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

## Niveles (pantalla principal)

La pantalla principal es un mapa de 16 unidades que siguen el libro. Se empieza por el 1; cada sesión completa de práctica da estrellas según los ejercicios perfectos (★ 60%, ★★ 80%, ★★★ 95%); con una estrella se abre la evaluación final, y al aprobarla, la unidad siguiente. Bajar el tempo, apagar el metrónomo o terminar antes no da estrellas.

Todo lo demás (piano, práctica libre con tus propios ajustes, nombres de notas, récords, reiniciar progreso) está en el botón de configuración (⚙︎).

## Unidades (orden de Czerny Op. 599)

Primero cada mano sola y luego juntas. El nombre de las notas queda a tu elección.

1. Mano derecha (Nos. 1–7): Do mayor, redondas, blancas y negras, 5 dedos, con nombre, sin metrónomo.
2. Mano izquierda (Nos. 1–7): en clave de sol alrededor del do central, como en el libro, con nombre.
3. Las dos manos (Nos. 1–7): octava exacta.
4. Líneas adicionales (Nos. 2, 4, 6, 7).
5. Primeros acordes (Nos. 8–10): tríadas, metrónomo a 60, repetir si fallas.
6. Cinco dedos: corcheas y silencios (Nos. 11–14): terceras, legato, bajo de Alberti.
7. Tresillos y semicorcheas (Nos. 15–18).
8. Paso del pulgar y nuevos compases (Nos. 19–26): escalas en una octava, 2/4, 3/4, 6/8, puntillo, 2 compases, 65 BPM, sin repetir.
9. Más de una octava (Nos. 27–31): saltos, sextas, ligaduras de prolongación.
10. Clave de fa: mano izquierda (Nos. 32–35): la izquierda sola en clave de fa.
11. Clave de fa: las dos manos (Nos. 32–35).
12. Sostenidos y bemoles (Nos. 36–38): alteraciones accidentales, 70 BPM.
13. Sol mayor y Fa mayor (Nos. 39–42).
14. Silencios, puntillo y nuevas tonalidades (Nos. 43–57): hasta 2♯/2♭, saltillo, 75 BPM.
15. Ejercicios de velocidad (Nos. 58–79): hasta 3♯/3♭, todas las figuras, 85 BPM.
16. Tonalidades lejanas (Nos. 80–100): hasta 5♯/5♭, 100 BPM.

Unidades de 1 compás: 10 ejercicios por sesión; de 2 compases: 20. No se incluyen los ornamentos (Nos. 71–79), el compás de 3/8, las tonalidades menores ni el cruce de manos.

## Evaluación final

Cada unidad termina con una obra completa del libro, tocada con las manos de la unidad: 1 → No. 1 (derecha), 2 → No. 1 (izquierda), 3 → No. 1, 4 → No. 2, 5 → No. 10, 6 → No. 12, 7 → No. 18, 8 → No. 21, 9 → No. 28, 10 → No. 32 (izquierda), 11 → No. 32, 12 → No. 36, 13 → No. 39, 14 → No. 47, 16 → No. 94. La unidad 15 aún no tiene obra (la No. 58 no se pudo transcribir con seguridad): se pasa con la práctica.

- Se abre con 1 estrella de práctica. Se toca de dos en dos compases y, con metrónomo, de corrido (sin cuenta entre tramos).
- Estrellas según las notas tocadas bien en toda la obra: ★ 80%, ★★ 90%, ★★★ 97%. Aprobarla abre la unidad siguiente.
- Las obras están transcritas en `Core/Pieces.swift` (cada compás una vez, sin repeticiones; sin ornamentos, digitación ni articulación).

## Cómo se generan las notas (estilo Czerny Op. 599)

- Cada ejercicio tiene una armonía: un acorde por compás (2/4, 3/4) o por medio compás (4/4, 6/8), empezando en I y cerrando en V–I. Los acordes intermedios salen de IV, ii, vi, I o V.
- La melodía pone notas del acorde en los tiempos fuertes y avanza por grados entre ellos (notas de paso y bordaduras), y termina en la tónica.
- Movimiento de la mano: 5 dedos (posición fija sobre la tónica o la dominante, Nos. 1–18), octava (paso del pulgar, Nos. 19–26) o libre (más de una octava con saltos, Nos. 27 en adelante). Unidades 1–7: 5 dedos; 8: octava; 9 en adelante: libre (la 10, octava).
- Intervalos: tercera debajo de la melodía (o sexta, fuera de la posición fija). Tríadas: con la melodía arriba, solo sobre notas del acorde.
- Alteraciones accidentales: solo en notas de paso, como bordaduras cromáticas.
- Con las dos manos, la izquierda acompaña con un patrón del libro según lo que esté activado: acordes largos (Nos. 9–11), bajo y acorde (oom-pah), vals (No. 21), bajo de Alberti (No. 14), acorde quebrado (Nos. 20, 23), tresillos (Nos. 15, 31) o acordes con silencios (No. 43).

## Ajustes

- Mano: derecha (clave de sol), izquierda (clave de fa) o ambas (pentagrama doble; lo que empieza a la vez en las dos manos se toca junto, la izquierda con ritmo más sencillo). Tonalidades: una o varias armaduras (de 7♭ a 7♯).
- Notas y acordes: nota suelta, dos notas, tríada (se mezclan dentro del compás). En los acordes hay que mantener las teclas a la vez.
- Figuras: negras siempre; blancas y redondas, corcheas, semicorcheas, puntillo, saltillo, tresillos, silencios, ligaduras de prolongación y de expresión. 1 o 2 compases.
- Alteraciones accidentales (♯ ♭ ♮), líneas adicionales y octava exacta.
- Mostrar: partitura, nombre o ambos (el nombre va dentro de cada nota); nombres en C D E o Do Re Mi.
- Metrónomo: tempo 40–200 BPM, uno o varios compases (2/4, 3/4, 4/4, 6/8; con varios, cada ejercicio sale en uno al azar), sonido de clic.

## Puntaje

- Sin metrónomo: 10 por nota (−30% por fallo en esa nota) × rapidez (×1.5 si < 1.5 s por nota, ×1.25 si < 3 s).
- Con metrónomo: 10 perfecta, 7 bien, 4 adelantada/atrasada, −5 por nota de más; × tempo.
- Todo × racha (ejercicios perfectos seguidos: ×2 desde 5, ×3 desde 10, ×4 desde 15) × ½ si usaste la pista. Récords guardados en el dispositivo.

## Créditos

Sonido de piano: "Upright Piano KW" de [FreePats](https://freepats.zenvoid.org/Piano/acoustic-grand-piano.html), dominio público (CC0).
