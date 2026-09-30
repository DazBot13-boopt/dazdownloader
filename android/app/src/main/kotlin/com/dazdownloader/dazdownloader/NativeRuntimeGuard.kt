package com.dazdownloader.dazdownloader

internal object NativeRuntimeGuard {
    fun <T> run(operation: () -> T): T {
        try {
            return operation()
        } catch (error: LinkageError) {
            // Includes ExceptionInInitializerError and NoClassDefFoundError.
            // They are not Exceptions and would otherwise kill the whole app
            // from the executor thread. Do not swallow fatal VM errors (OOM).
            throw MediaFailure(
                "engine_initialization",
                "Le moteur Android n’a pas pu démarrer (${error.javaClass.simpleName}). " +
                    "Envoyez une capture de ce message avec le modèle du téléphone.",
            ).apply { initCause(error) }
        }
    }
}
