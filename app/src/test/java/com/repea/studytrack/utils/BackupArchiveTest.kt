package com.repea.studytrack.utils

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class BackupArchiveTest {
    private fun fixture(name: String) = File("../ios/StudyTrackTests/Fixtures/$name").readBytes()
    @Test fun importsIndependentIOSGoldenBackup() {
        val archive = BackupArchive.decode(fixture("golden.studytrackbackup"))
        assertEquals(2,archive.data.getJSONArray("users").length())
        assertEquals(4,archive.data.getJSONArray("semesters").length())
    }
    @Test fun rejectsTraversalUnknownVersionAndBrokenRelationships() {
        for(name in listOf("unsafe-path.studytrackbackup","unknown-version.studytrackbackup","broken-reference.studytrackbackup")) {
            assertThrows(Exception::class.java) { BackupArchive.decode(fixture(name)) }
        }
    }
    @Test fun corruptedBackupDoesNotPassIntegrityChecks() {
        val bytes = fixture("golden.studytrackbackup"); bytes[bytes.size/2] = (bytes[bytes.size/2].toInt() xor 0x40).toByte()
        assertThrows(Exception::class.java) { BackupArchive.decode(bytes) }
    }
}
