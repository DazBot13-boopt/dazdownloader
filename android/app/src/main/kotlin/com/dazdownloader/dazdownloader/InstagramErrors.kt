package com.dazdownloader.dazdownloader

object InstagramErrors {
    fun classify(message: String): MediaFailure {
        val text = message.lowercase()
        return when {
            "429" in text || "rate-limit" in text || "too many requests" in text ->
                MediaFailure("instagram_limited", "Instagram limite l’accès depuis cette connexion. Attendez avant de réessayer ; ce refus ne signifie pas forcément que la publication est privée.")
            listOf(
                "login required", "login page", "log in", "sign in",
                "private account", "account is private", "content is private",
                "registered users", "authentication"
            ).any { it in text } ->
                MediaFailure("instagram_login", "Instagram demande une connexion ou refuse l’accès anonyme. Vérifiez que ce lien s’ouvre dans un navigateur sans compte. L’app n’importe pas votre connexion Instagram.")
            "no video" in text -> MediaFailure("instagram_no_video", "Cette publication Instagram ne contient pas de vidéo accessible. Loady télécharge les vidéos.")
            "unsupported url" in text -> MediaFailure("instagram_url", "Utilisez le lien direct du Reel ou de la publication Instagram, pas un profil ni un lien de partage /share/.")
            else -> MediaFailure("instagram_extraction", "Instagram n’a pas fourni de vidéo exploitable. Copiez le diagnostic ci-dessous et transmettez-le avec le lien de la publication pour identifier le blocage.")
        }
    }
}
