# Los DTOs se deserializan con kotlinx.serialization: sus nombres de campo
# importan en tiempo de ejecucion.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class com.gameshelf.** {
  *** Companion;
}
-keepclasseswithmembers class com.gameshelf.** {
  kotlinx.serialization.KSerializer serializer(...);
}
