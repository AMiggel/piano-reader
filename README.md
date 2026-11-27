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
- **Con metrónomo:** un compás de cuenta y se juzga cuándo empieza cada nota (perfecto ±60 ms, bien ±130 ms, adelantado/atrasado, equivocada, no tocada, de más) y cuánto se mantiene (hay que mantener al menos la mitad de su valor, menos 0,1 s; soltarla antes no es fallo: cuenta la mitad, en naranja). Si el compás no sale perfecto, se repite (se puede desactivar).
- El metrónomo se enciende/apaga, y el tempo y el compás se cambian durante la práctica (toca el botón de BPM).
- Se muestra en azul lo que tocas: en el pentagrama, con su nombre y en el teclado en pantalla.
- "Escuchar" para el metrónomo y reproduce el ejercicio (o la obra) una vez con la línea azul avanzando; al terminar se vuelve a empezar el intento. Tocarlo mientras suena lo detiene. Ese ejercicio vale la mitad.

## Niveles (pantalla principal)

La pantalla principal es un solo camino de 26 lecciones, sin nada que elegir: se sigue en orden con "Continuar". Está dividido en cinco niveles de dificultad y mezcla lectura (las 16 unidades de Czerny) con ritmo (10 lecciones):

- **Principiante:** ritmo 1, unidades 1–2, ritmo 2, unidad 3.
- **Principiante avanzado:** unidad 4, ritmo 3, unidades 5–6, ritmo 4.
- **Intermedio:** ritmo 5–7, unidades 7–9.
- **Intermedio avanzado:** unidades 10–11, ritmo 8, unidades 12–13.
- **Avanzado:** ritmo 9, unidades 14–15, ritmo 10, unidad 16.

Cada sesión usa un solo compás y un solo tempo de principio a fin (si la lección tiene varios, cambian de una sesión a otra, nunca a mitad). Se empieza por la primera; cada sesión completa de práctica da estrellas según los ejercicios perfectos (★ 60%, ★★ 80%, ★★★ 95%); con una estrella se abre la evaluación final, y al aprobarla, la unidad siguiente. Bajar el tempo, apagar el metrónomo o terminar antes no da estrellas.

Todo lo demás (piano, práctica libre con tus propios ajustes, nombres de notas, récords, reiniciar progreso) está en el botón de configuración (⚙︎).

## Unidades (orden de Czerny Op. 599)

Primero cada mano sola y luego juntas. El nombre de las notas queda a tu elección.

1. Mano derecha (Nos. 1–7): Do mayor, redondas, blancas y negras, 5 dedos, con nombre, sin metrónomo.
2. Mano izquierda (Nos. 1–7): en clave de fa, con nombre (la izquierda siempre va en clave de fa; las obras del libro que la escriben en sol se pasan a fa una octava más grave).
3. Las dos manos (Nos. 1–7): octava exacta.
4. Líneas adicionales (Nos. 2, 4, 6, 7).
5. Primeros acordes (Nos. 8–10): tríadas, metrónomo a 60, repetir si fallas.
6. Cinco dedos: corcheas y silencios (Nos. 11–14): terceras, legato, bajo de Alberti.
7. Tresillos y semicorcheas (Nos. 15–18).
8. Paso del pulgar y nuevos compases (Nos. 19–26): escalas en una octava, 2/4, 3/4, 6/8, puntillo, 2 compases, 65 BPM, sin repetir.
9. Más de una octava (Nos. 27–31): saltos, sextas, ligaduras de prolongación.
10. Mano izquierda sola (Nos. 32–35): la izquierda sola, moviendo la mano.
11. Las dos manos, mano libre (Nos. 32–35).
12. Sostenidos y bemoles (Nos. 36–38): alteraciones accidentales, 70 BPM.
13. Sol mayor y Fa mayor (Nos. 39–42).
14. Silencios, puntillo y nuevas tonalidades (Nos. 43–57): hasta 2♯/2♭, saltillo, 75 BPM.
15. Ejercicios de velocidad (Nos. 58–79): hasta 3♯/3♭, todas las figuras, 85 BPM.
16. Tonalidades lejanas (Nos. 80–100): hasta 5♯/5♭, 100 BPM.

Unidades de 1 compás: 10 ejercicios por sesión; de 2 compases: 20. No se incluyen los ornamentos (Nos. 71–79), el compás de 3/8, las tonalidades menores ni el cruce de manos.

## Evaluación final

Cada unidad termina con una obra completa del libro, tocada con las manos de la unidad: 1 → No. 1 (derecha), 2 → No. 1 (izquierda), 3 → No. 1, 4 → No. 2, 5 → No. 10, 6 → No. 12, 7 → No. 18, 8 → No. 21, 9 → No. 28, 10 → No. 32 (izquierda), 11 → No. 32, 12 → No. 36, 13 → No. 39, 14 → No. 47, 16 → No. 94. La unidad 15 aún no tiene obra (la No. 58 no se pudo transcribir con seguridad): se pasa con la práctica.

- Se abre con 1 estrella de práctica. La obra se toca entera de corrido: la partitura avanza sola y la línea azul queda a un tercio de la pantalla (con metrónomo sigue el tempo; sin él, avanza con lo que tocas).
- Estrellas según las notas tocadas bien en toda la obra: ★ 80%, ★★ 90%, ★★★ 97%. Aprobarla abre la unidad siguiente.
- Las obras están transcritas en `Core/Pieces.swift` (cada compás una vez, sin repeticiones; sin ornamentos, digitación ni articulación).

## Ritmo

Las lecciones de ritmo están intercaladas en el camino (ícono de metrónomo). Solo se lee el ritmo: una línea con clave de percusión y cualquier tecla del piano (o el botón grande de la pantalla) vale. Siempre con metrónomo: se juzga cuándo empieza cada figura y cuánto se mantiene.

Cada sesión sale con un término italiano de tempo
 escrito sobre la partitura (p. ej. *Allegro* ♩ = 132) y el metrónomo arranca a ese tempo con su compás de cuenta.

| Término | BPM | Típico |
|---|---|---|
| Grave | 20–44 | 40 |
| Largo | 45–59 | 50 |
| Adagio | 60–75 | 70 |
| Andante | 76–99 | 88 |
| Moderato | 100–111 | 108 |
| Allegretto | 112–119 | 116 |
| Allegro | 120–155 | 132 |
| Vivace | 156–175 | 164 |
| Presto | 176–199 | 184 |
| Prestissimo | 200+ | 208 |

1. Negras y blancas (4/4) · 2. Silencios y redondas (4/4, 3/4) · 3. Corcheas (2/4, 3/4, 4/4) · 4. Puntillo y ligaduras · 5. 3/8 y 6/8 · 6. Semicorcheas · 7. Tresillos y saltillo · 8. 2/2, 5/4, 9/8 y 12/8 · 9. Tempos rápidos (Allegro, Vivace, Presto) · 10. Todo junto.

Compases disponibles: 2/4, 3/4, 4/4, 5/4, 2/2, 3/8, 6/8, 9/8 y 12/8 (en los de corchea el clic marca corcheas con acento cada tres; en 2/2, blancas). En la práctica libre: "Solo ritmo" y "Términos de tempo" en los ajustes; la hoja de tempo muestra el término del BPM elegido.

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
- Metrónomo: tempo 40–220 BPM con su término italiano, uno o varios compases (2/4, 3/4, 4/4, 5/4, 2/2, 3/8, 6/8, 9/8, 12/8; con varios, cada sesión sale en uno al azar y no cambia hasta el final), sonido de clic.

## Puntaje

- Sin metrónomo: 10 por nota (−30% por fallo en esa nota) × rapidez (×1.5 si < 1.5 s por nota, ×1.25 si < 3 s).
- Con metrónomo: 10 perfecta, 7 bien, 5 a tiempo pero soltada antes, 4 adelantada/atrasada, −5 por nota de más; × tempo.
- Todo × racha (ejercicios perfectos seguidos: ×2 desde 5, ×3 desde 10, ×4 desde 15) × ½ si usaste la pista. Récords guardados en el dispositivo.

## Créditos

Sonido de piano: "Upright Piano KW" de [FreePats](https://freepats.zenvoid.org/Piano/acoustic-grand-piano.html), dominio público (CC0).
