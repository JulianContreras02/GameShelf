package com.gameshelf

import com.gameshelf.domain.Game
import com.gameshelf.domain.GameTag
import com.gameshelf.domain.PlayStatus
import com.gameshelf.domain.Store
import com.gameshelf.domain.StoreEntry
import com.gameshelf.domain.TrophyCounts
import com.gameshelf.domain.containsNormalized
import com.gameshelf.domain.hasPrefixNormalized
import com.gameshelf.domain.normalizedForSearch
import com.gameshelf.ui.library.GameFilter
import com.gameshelf.ui.library.GameQuery
import com.gameshelf.ui.library.GameSearch
import com.gameshelf.ui.library.GameSortOrder
import com.gameshelf.ui.library.LibraryInsights
import com.gameshelf.ui.tags.TagsViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

/** Crea un juego de prueba sin repetir los mismos diez parametros. */
private fun juego(
  nombre: String,
  horas: Double = 0.0,
  estado: PlayStatus = PlayStatus.BACKLOG,
  recientes: Double = 0.0,
  ultimaVez: Instant? = null,
  tiendas: List<Store> = listOf(Store.STEAM),
  agregado: Instant = Instant.EPOCH,
) = Game(
  name = nombre,
  playtimeHours = horas,
  status = estado,
  addedAt = agregado,
  storeEntries = tiendas.map { tienda ->
    StoreEntry(
      store = tienda,
      storeGameID = "$nombre-${tienda.id}",
      playtimeHours = horas / tiendas.size,
      recentPlaytimeHours = recientes / tiendas.size,
      lastPlayedAt = ultimaVez,
    )
  },
)

class NormalizacionTest {

  @Test
  fun `ignora mayusculas y tildes`() {
    assertEquals("accion", "Acción".normalizedForSearch)
    assertEquals("rpg", "  RPG  ".normalizedForSearch)
  }

  @Test
  fun `buscar accion encuentra Accion con tilde`() {
    assertTrue("Juego de Acción".containsNormalized("accion"))
    assertTrue("Hollow Knight".hasPrefixNormalized("hollow"))
    assertFalse("Hollow Knight".hasPrefixNormalized("knight"))
  }

  @Test
  fun `una busqueda vacia coincide con todo`() {
    assertTrue("lo que sea".containsNormalized(""))
    assertTrue("lo que sea".hasPrefixNormalized("   "))
  }
}

class GameSearchTest {

  private val juegos = listOf(
    juego("Hollow Knight"),
    juego("Bloodstained: Hollow"),
    juego("Celeste"),
  )

  @Test
  fun `una busqueda vacia devuelve todos`() {
    // Escribir y borrar no puede dejar la biblioteca en blanco.
    assertEquals(3, GameSearch.filter(juegos, "").size)
    assertEquals(3, GameSearch.filter(juegos, "   ").size)
  }

  @Test
  fun `los que empiezan por lo buscado van primero`() {
    val resultado = GameSearch.filter(juegos, "hollow")

    assertEquals(2, resultado.size)
    assertEquals("Hollow Knight", resultado.first().name)
  }

  @Test
  fun `sin coincidencias devuelve la lista vacia`() {
    assertTrue(GameSearch.filter(juegos, "zelda").isEmpty())
  }
}

class GameFilterTest {

  private val juegos = listOf(
    juego("Uno", estado = PlayStatus.PLAYING, tiendas = listOf(Store.STEAM)),
    juego("Dos", estado = PlayStatus.FINISHED, tiendas = listOf(Store.PSN)),
    juego("Tres", estado = PlayStatus.PLAYING, tiendas = listOf(Store.STEAM, Store.PSN)),
  )

  @Test
  fun `un filtro vacio no filtra nada`() {
    // Vacio significa "cualquiera", no "ninguno".
    assertFalse(GameFilter.NONE.isActive)
    assertEquals(3, GameFilter.NONE.apply(juegos).size)
  }

  @Test
  fun `dentro de una categoria se aplica O`() {
    val filtro = GameFilter(stores = setOf(Store.STEAM, Store.PSN))
    assertEquals(3, filtro.apply(juegos).size)
  }

  @Test
  fun `entre categorias se aplica Y`() {
    val filtro = GameFilter(stores = setOf(Store.PSN), statuses = setOf(PlayStatus.PLAYING))
    val resultado = filtro.apply(juegos)

    assertEquals(1, resultado.size)
    assertEquals("Tres", resultado.first().name)
  }

  @Test
  fun `cuenta los criterios puestos`() {
    val filtro = GameFilter(
      stores = setOf(Store.STEAM),
      statuses = setOf(PlayStatus.PLAYING, PlayStatus.BACKLOG),
    )
    assertEquals(3, filtro.activeCount)
  }
}

class GameSortOrderTest {

  private val juegos = listOf(
    juego("Zelda", horas = 10.0, ultimaVez = Instant.ofEpochSecond(200)),
    juego("Ángel", horas = 30.0),
    juego("celeste", horas = 20.0, ultimaVez = Instant.ofEpochSecond(100)),
  )

  @Test
  fun `por nombre respeta tildes y mayusculas del idioma`() {
    // Sin comparacion por idioma, "Ángel" caeria despues de "Zelda".
    val ordenados = GameSortOrder.NAME_ASCENDING.sort(juegos).map { it.name }
    assertEquals(listOf("Ángel", "celeste", "Zelda"), ordenados)
  }

  @Test
  fun `por horas descendente`() {
    val ordenados = GameSortOrder.PLAYTIME_DESCENDING.sort(juegos).map { it.name }
    assertEquals(listOf("Ángel", "celeste", "Zelda"), ordenados)
  }

  @Test
  fun `los que no tienen fecha van al final`() {
    // Un juego sin fecha no es "el mas antiguo": es uno del que no se sabe.
    val ordenados = GameSortOrder.LAST_PLAYED_DESCENDING.sort(juegos).map { it.name }
    assertEquals(listOf("Zelda", "celeste", "Ángel"), ordenados)
  }

  @Test
  fun `solo la fecha de lanzamiento avisa de que no funciona todavia`() {
    assertNull(GameSortOrder.NAME_ASCENDING.unavailableNoteRes)
    assertTrue(GameSortOrder.RELEASE_DATE_DESCENDING.unavailableNoteRes != null)
  }

  @Test
  fun `un id desconocido cae al orden por defecto`() {
    assertEquals(GameSortOrder.DEFAULT, GameSortOrder.fromId("loQueSea"))
    assertEquals(GameSortOrder.DEFAULT, GameSortOrder.fromId(null))
  }
}

class GameQueryTest {

  @Test
  fun `el orden elegido gana sobre la relevancia de la busqueda`() {
    // Si el usuario pidio "mas jugados", eso es lo que quiere ver, tambien
    // entre los resultados de la busqueda.
    val juegos = listOf(
      juego("Hollow Knight", horas = 5.0),
      juego("Bloodstained: Hollow", horas = 50.0),
    )

    val consulta = GameQuery(search = "hollow", sort = GameSortOrder.PLAYTIME_DESCENDING)
    assertEquals("Bloodstained: Hollow", consulta.apply(juegos).first().name)
  }

  @Test
  fun `sabe si esta recortando la lista`() {
    assertFalse(GameQuery().isNarrowing)
    assertTrue(GameQuery(search = "algo").isNarrowing)
    assertFalse(GameQuery(search = "   ").isNarrowing)
    assertTrue(GameQuery(filter = GameFilter(stores = setOf(Store.STEAM))).isNarrowing)
  }
}

class LibraryInsightsTest {

  private val juegos = listOf(
    juego("Sin jugar"),
    juego("Apenas probado", horas = 0.5),
    juego("Jugado", horas = 100.0, recientes = 3.0),
  )

  @Test
  fun `el resumen cuenta cada grupo`() {
    val resumen = LibraryInsights.summary(juegos)

    assertEquals(3, resumen.totalGames)
    assertEquals(1, resumen.unplayedCount)
    assertEquals(1, resumen.barelyTriedCount)
    assertEquals(1, resumen.recentlyPlayedCount)
    assertEquals(100.5, resumen.totalHours, 0.0001)
  }

  @Test
  fun `el promedio solo cuenta los jugados`() {
    // Incluir los de 0 h hundiria el promedio y no diria nada util.
    assertEquals(50.25, LibraryInsights.summary(juegos).averageHoursPerPlayedGame, 0.0001)
  }

  @Test
  fun `una biblioteca vacia no divide por cero`() {
    val resumen = LibraryInsights.summary(emptyList())

    assertTrue(resumen.isEmpty)
    assertEquals(0.0, resumen.unplayedFraction, 0.0)
    assertEquals(0.0, resumen.averageHoursPerPlayedGame, 0.0)
  }

  @Test
  fun `las secciones vacias no se muestran`() {
    val secciones = LibraryInsights.sections(listOf(juego("Solo uno", horas = 5.0)))
    assertTrue(secciones.none { it.isEmpty })
  }

  @Test
  fun `sin horas la concentracion queda en cero`() {
    val concentracion = LibraryInsights.concentration(listOf(juego("Sin jugar")))
    assertEquals(0, concentracion.gamesForHalfTheTime)
    assertEquals(0.0, concentracion.topGameShare, 0.0)
  }

  @Test
  fun `los candidatos excluyen los que el usuario ya clasifico`() {
    // Si marco como terminado un juego que jugo en consola, cambiarselo seria
    // pisar su decision.
    val lista = listOf(
      juego("Sin tocar"),
      juego("Terminado en consola", estado = PlayStatus.FINISHED),
      juego("Ya pendiente", estado = PlayStatus.BACKLOG),
      juego("Jugado", horas = 5.0, estado = PlayStatus.PLAYING),
    )

    val candidatos = LibraryInsights.candidatesForBacklog(lista).map { it.name }
    assertEquals(listOf("Terminado en consola"), candidatos)
  }
}

class GameTagTest {

  @Test
  fun `limpia los espacios sobrantes`() {
    assertEquals("juego coop", GameTag.clean("  juego   coop "))
  }

  @Test
  fun `RPG y rpg son la misma etiqueta`() {
    assertTrue(GameTag.areEquivalent("RPG", "rpg"))
    assertTrue(GameTag.areEquivalent("Acción", "accion"))
    assertFalse(GameTag.areEquivalent("coop", "coop local"))
  }

  @Test
  fun `el autocompletado pone primero las que empiezan por lo escrito`() {
    val todas = listOf(
      GameTag.create("cooperativo"),
      GameTag.create("para el Deck"),
      GameTag.create("coop"),
    )

    // Las dos empiezan por "coo" y ninguna se usa mas que la otra, asi que el
    // desempate es alfabetico: "coop" antes que "cooperativo".
    val sugerencias = TagsViewModel.suggestions("coo", todas, emptyList()).map { it.name }
    assertEquals(listOf("coop", "cooperativo"), sugerencias)
  }

  @Test
  fun `no sugiere las que el juego ya tiene`() {
    val puesta = GameTag.create("coop")
    val todas = listOf(puesta, GameTag.create("rpg"))

    val sugerencias = TagsViewModel.suggestions("", todas, listOf(puesta))
    assertEquals(listOf("rpg"), sugerencias.map { it.name })
  }

  @Test
  fun `crear solo se ofrece cuando de verdad no existe`() {
    val todas = listOf(GameTag.create("RPG"))

    assertFalse(TagsViewModel.wouldCreateNew("rpg", todas))
    assertFalse(TagsViewModel.wouldCreateNew("  ", todas))
    assertTrue(TagsViewModel.wouldCreateNew("metroidvania", todas))
  }
}

class TrophyBreakdownTest {

  @Test
  fun `sin trofeos definidos no hay desglose`() {
    assertNull(juego("Sin trofeos").trophyBreakdown)
  }

  @Test
  fun `el porcentaje y los conteos salen de la misma lista`() {
    // Una entrada con porcentaje pero sin conteos no debe aportar su
    // porcentaje al desglose de otra: se veria un "90%" sobre un "15 / 38"
    // que no le corresponde.
    val base = juego("Con dos listas")
    val conDos = base.copy(
      storeEntries = listOf(
        base.storeEntries.first().copy(trophyProgress = 90),
        base.storeEntries.first().copy(
          id = java.util.UUID.randomUUID(),
          trophyProgress = 15,
          earnedTrophies = TrophyCounts(bronze = 15),
          definedTrophies = TrophyCounts(bronze = 38),
        ),
      ),
    )

    val desglose = checkNotNull(conDos.trophyBreakdown)

    assertEquals(15, desglose.progress)
    assertEquals(38, desglose.defined.bronze)
    // El maximo de todas las entradas si es 90: son dos lecturas distintas a
    // proposito.
    assertEquals(90, conDos.trophyProgress)
  }

  @Test
  fun `los conteos suman por tipo`() {
    val conteos = TrophyCounts(bronze = 10, silver = 5, gold = 2, platinum = 1)
    assertEquals(18, conteos.total)
    assertFalse(conteos.isEmpty)
    assertTrue(TrophyCounts().isEmpty)
  }
}
