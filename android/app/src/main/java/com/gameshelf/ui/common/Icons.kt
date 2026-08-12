package com.gameshelf.ui.common

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.HourglassBottom
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.SortByAlpha
import androidx.compose.material.icons.filled.SouthEast
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Star
import androidx.compose.ui.graphics.vector.ImageVector
import com.gameshelf.domain.CollectionSymbol
import com.gameshelf.domain.StatusIcon
import com.gameshelf.ui.library.SectionIcon
import com.gameshelf.ui.library.SortIcon

/**
 * De los nombres de icono del dominio a los vectores de Material.
 *
 * El modelo nombra el icono pero no lo construye, igual que en iOS guardaba el
 * nombre del SF Symbol sin importar SwiftUI. Toda la traduccion vive aca, en un
 * solo sitio, para que cambiar la pinta de la app no toque el dominio.
 */

val StatusIcon.vector: ImageVector
  get() = when (this) {
    StatusIcon.TRAY -> Icons.Default.Inbox
    StatusIcon.PLAY -> Icons.Default.PlayCircle
    StatusIcon.CHECK -> Icons.Default.CheckCircle
    StatusIcon.CROSS -> Icons.Default.Cancel
    StatusIcon.HEART -> Icons.Default.Favorite
  }

val CollectionSymbol.vector: ImageVector
  get() = when (this) {
    CollectionSymbol.FOLDER -> Icons.Default.Folder
    CollectionSymbol.STAR -> Icons.Default.Star
    CollectionSymbol.HEART -> Icons.Default.Favorite
    CollectionSymbol.BOOKMARK -> Icons.Default.Bookmark
    CollectionSymbol.FLAG -> Icons.Default.Flag
    CollectionSymbol.TROPHY -> Icons.Default.EmojiEvents
    CollectionSymbol.GAMEPAD -> Icons.Default.SportsEsports
    CollectionSymbol.CLOCK -> Icons.Default.AccessTime
    CollectionSymbol.SPARKLES -> Icons.Default.AutoAwesome
    CollectionSymbol.LIST -> Icons.AutoMirrored.Filled.List
  }

val SortIcon.vector: ImageVector
  get() = when (this) {
    SortIcon.ALPHABET -> Icons.Default.SortByAlpha
    SortIcon.CLOCK_BACK -> Icons.Default.AccessTime
    SortIcon.CLOCK -> Icons.Default.AccessTime
    SortIcon.CALENDAR -> Icons.Default.CalendarMonth
    SortIcon.SPARKLE -> Icons.Default.AutoAwesome
    SortIcon.INBOX -> Icons.Default.Inbox
    SortIcon.TAG -> Icons.Default.LocalOffer
    SortIcon.ARROW_DOWN -> Icons.Default.SouthEast
  }

val SectionIcon.vector: ImageVector
  get() = when (this) {
    SectionIcon.FLAME -> Icons.Default.LocalFireDepartment
    SectionIcon.TROPHY -> Icons.Default.EmojiEvents
    SectionIcon.HOURGLASS -> Icons.Default.HourglassBottom
    SectionIcon.BOX -> Icons.Default.Inventory2
  }
