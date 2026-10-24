package com.repea.studytrack.utils

import java.io.ByteArrayOutputStream
import java.io.InputStream

/** Bounded reads also work on Android 10–12, where InputStream.readNBytes is absent. */
fun InputStream.readLimited(limit: Int): ByteArray {
    val output = ByteArrayOutputStream(); val buffer = ByteArray(16*1024)
    while(true) {
        val count = read(buffer); if(count < 0) break
        require(output.size().toLong()+count <= limit) { "文件超过 ${limit/1024/1024}MB 大小限制" }
        output.write(buffer,0,count)
    }
    return output.toByteArray()
}
