package com.repea.studytrack.domain

import com.repea.studytrack.utils.BackupValues
import java.time.LocalDate
import java.time.ZoneId

enum class SchoolStage(val wire: String, val label: String, val years: Int) {
    PRIMARY("primary", "小学阶段", 6), JUNIOR("junior", "初中阶段", 3),
    HIGH("high", "高中阶段", 3), UNIVERSITY("university", "大学阶段", 4);
    companion object { fun fromWire(value: String?) = entries.firstOrNull { it.wire == value } }
}

data class SchoolTerm(val stage: SchoolStage, val year: Int, val half: Int) {
    init { require(year in 1..stage.years && half in 1..2) { "无效学期" } }
    val order get() = year * 2 + half
    val label: String get() {
        val number = "一二三四五六"[year - 1]
        val prefix = when (stage) {
            SchoolStage.PRIMARY -> "${number}年级"; SchoolStage.JUNIOR -> "初$number"
            SchoolStage.HIGH -> "高$number"; SchoolStage.UNIVERSITY -> "大$number"
        }
        return prefix + if (half == 1) "上学期" else "下学期"
    }
    companion object {
        fun catalog(stage: SchoolStage) = (1..stage.years).flatMap { year -> (1..2).map { SchoolTerm(stage, year, it) } }
        fun recognize(name: String): SchoolTerm? {
            val value = BackupValues.normalized(name).replace(" · ", "").replace(" ", "")
            return SchoolStage.entries.flatMap(::catalog).firstOrNull {
                value == it.label || value == "${it.stage.label}-${it.label}" ||
                    (it.stage == SchoolStage.PRIMARY && value == "${it.year}年级${if (it.half == 1) "上学期" else "下学期"}")
            }
        }
        fun next(stage: SchoolStage, existing: List<SchoolTerm>): SchoolTerm? {
            val created = existing.filter { it.stage == stage }.toSet()
            val catalog = catalog(stage)
            val last = created.maxOfOrNull { it.order } ?: 0
            return catalog.firstOrNull { it.order > last && it !in created } ?: catalog.firstOrNull { it !in created }
        }
    }
}

object RecordValidation {
    fun name(text: String): String = BackupValues.normalized(text).also {
        require(it.isNotBlank() && it.length <= 100) { "名称需为 1–100 个字符" }
    }
    fun score(text: String, full: Double): Double {
        val normalized = text.trim().replace(',', '.')
        require(Regex("^[0-9]+(\\.[0-9]{1,2})?$").matches(normalized)) { "分数须为非负数，最多两位小数" }
        val value = normalized.toDoubleOrNull() ?: throw IllegalArgumentException("请填写有效分数")
        require(value.isFinite() && value in 0.0..full) { "分数应在 0–${formatScore(full)} 之间" }
        require(runCatching { BackupValues.score(value) }.isSuccess) { "分数超出范围或精度" }
        return value
    }
    fun fullScore(text: String) = score(text, 10_000_000.0).also { require(it > 0) { "满分必须大于零" } }
    fun rank(text: String): Int? = text.trim().takeIf { it.isNotEmpty() }?.let {
        (it.toIntOrNull() ?: error("排名必须为正整数")).also { value -> require(value > 0) { "排名必须为正整数" } }
    }
    fun date(text: String): Long { val date = LocalDate.parse(text.trim()); require(date.year in 1900..2100) { "日期应在 1900–2100 年内" }; return date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli() }
}

fun formatScore(value: Double): String = java.math.BigDecimal.valueOf(value).stripTrailingZeros().toPlainString()
fun localDate(timestamp: Long): String = java.time.Instant.ofEpochMilli(timestamp).atZone(ZoneId.systemDefault()).toLocalDate().toString()
