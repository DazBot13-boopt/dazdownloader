package com.dazdownloader.dazdownloader

import org.junit.Assert.*
import org.junit.Test

class MediaFilesTest {
    @Test fun recognisesAnEarlierDownloadOfTheSameVideoAndFormat() {
        assertTrue(MediaFiles.isDownloadOf("Ma vidéo-8b6482b2.mp4", "Ma vidéo", "mp4"))
    }

    @Test fun usesTheSameSafeTitleAsTheSavedFile() {
        // "/" and ":" are replaced when the file is saved.
        assertTrue(MediaFiles.isDownloadOf("AC_DC_ live-0a1b2c3d.mp3", "AC/DC: live", "mp3"))
    }

    @Test fun anotherFormatOrTitleIsNotTheSameDownload() {
        assertFalse(MediaFiles.isDownloadOf("Ma vidéo-8b6482b2.mp4", "Ma vidéo", "mp3"))
        assertFalse(MediaFiles.isDownloadOf("Ma vidéo 2-8b6482b2.mp4", "Ma vidéo", "mp4"))
        assertFalse(MediaFiles.isDownloadOf("Ma vidéo.mp4", "Ma vidéo", "mp4"))
        assertFalse(MediaFiles.isDownloadOf("Ma vidéo-8b6482b2.mp4", "Ma vidéo", ""))
    }

    @Test fun regexCharactersInTitlesAreTakenLiterally() {
        assertTrue(MediaFiles.isDownloadOf("Top (10) + bonus-12345678.webm", "Top (10) + bonus", "webm"))
        assertFalse(MediaFiles.isDownloadOf("Top 10-12345678.webm", "Top (10)", "webm"))
    }
}
