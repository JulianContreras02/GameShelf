package com.gameshelf.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

/**
 * Las esquinas de la app.
 *
 * Mas redondeadas que las de serie de Material 3. La razon no es estetica: casi
 * todo lo que se muestra son caratulas, que son rectangulos con imagen dentro,
 * y con esquinas poco redondeadas las tarjetas que las contienen se confunden
 * con la propia imagen. Al redondear mas, la tarjeta se lee como contenedor y
 * la caratula como contenido.
 */
val GameShelfShapes = Shapes(
  extraSmall = RoundedCornerShape(6.dp),
  small = RoundedCornerShape(10.dp),
  medium = RoundedCornerShape(16.dp),
  large = RoundedCornerShape(20.dp),
  extraLarge = RoundedCornerShape(28.dp),
)

/**
 * Radio de las caratulas.
 *
 * Va aparte de la escala de Material porque no es un contenedor sino contenido:
 * se usa igual en una fila de 88 dp de ancho que en la ficha del juego, y tiene
 * que verse como la misma cosa en los dos sitios.
 */
val FormaDeCaratula = RoundedCornerShape(10.dp)
