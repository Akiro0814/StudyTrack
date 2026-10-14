import com.repea.studytrack.utils.BackupValues

fun main() {
    check(BackupValues.score(89.5) == "89.50")
    check(BackupValues.score(0.0) == "0.00")
    check(runCatching { BackupValues.score(89.501) }.isFailure)
    check(runCatching { BackupValues.score(Double.NaN) }.isFailure)
    check(BackupValues.date(0L, "Asia/Shanghai") == "1970-01-01")
    check(BackupValues.date(0L, "America/Los_Angeles") == "1969-12-31")
    check(BackupValues.normalized("  e\u0301  ") == "é")
    println("PASS: actual Android BackupValues precision, timezone and normalization rules")
}
