package dev.luminatech.oob_pos

import android.database.sqlite.SQLiteDatabase
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey

class JournalSigner {
    private val key: SecretKey by lazy {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey("oob-audit-v1", null) as? SecretKey) ?: KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_HMAC_SHA256, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder("oob-audit-v1", KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY).setDigests(KeyProperties.DIGEST_SHA256).build())
            generateKey()
        }
    }
    fun sign(value: String): String = Mac.getInstance("HmacSHA256").run {
        init(key); doFinal(value.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }
}

fun createReportTables(db: SQLiteDatabase) {
    db.execSQL("CREATE TABLE journal (seq INTEGER PRIMARY KEY, body TEXT NOT NULL, previous TEXT NOT NULL, signature TEXT NOT NULL)")
    db.execSQL("CREATE TABLE sales_ledger (order_id INTEGER PRIMARY KEY REFERENCES orders(id), approved_at INTEGER NOT NULL, day TEXT NOT NULL, amount INTEGER NOT NULL, grand_total INTEGER NOT NULL, snapshot TEXT NOT NULL)")
    db.execSQL("CREATE TABLE saved_reports (id INTEGER PRIMARY KEY AUTOINCREMENT, request TEXT NOT NULL UNIQUE, kind TEXT NOT NULL, day TEXT NOT NULL, snapshot TEXT NOT NULL)")
    db.execSQL("CREATE UNIQUE INDEX one_z_per_day ON saved_reports(day) WHERE kind='Z'")
    for (table in listOf("journal", "sales_ledger", "saved_reports", "payments")) {
        for (op in listOf("UPDATE", "DELETE")) db.execSQL("CREATE TRIGGER ${table}_${op.lowercase()} BEFORE $op ON $table BEGIN SELECT RAISE(ABORT, 'Append-only record'); END")
    }
}

object ReportPeriod {
    val zone: TimeZone get() = TimeZone.getTimeZone("Asia/Manila")
    fun day(time: Long): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = zone }.format(java.util.Date(time))
    fun bounds(kind: String, day: String): Pair<Long, Long> {
        if (!Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}").matches(day)) fail("Choose a valid date")
        val format = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = zone; isLenient = false }
        val date = try { format.parse(day)!! } catch (_: Exception) { fail("Choose a valid date") }
        val c = Calendar.getInstance(zone).apply { time = date }
        when (kind) {
            "weekly" -> c.add(Calendar.DATE, -((c.get(Calendar.DAY_OF_WEEK) + 5) % 7))
            "monthly" -> c.set(Calendar.DAY_OF_MONTH, 1)
            "daily", "X", "Z" -> Unit
            else -> fail("Unknown report period")
        }
        val start = c.timeInMillis
        when (kind) {
            "weekly" -> c.add(Calendar.DATE, 7)
            "monthly" -> c.add(Calendar.MONTH, 1)
            else -> c.add(Calendar.DATE, 1)
        }
        return start to c.timeInMillis
    }
}

class Reports(private val store: OrderStore, private val sign: (String) -> String) {
    private val db get() = store.writableDatabase
    fun <T> transaction(block: () -> T): T {
        db.beginTransaction()
        try { return block().also { db.setTransactionSuccessful() } } finally { db.endTransaction() }
    }
    fun append(event: String, data: JSONObject = JSONObject(), at: Long = System.currentTimeMillis()) {
        check(db.inTransaction()) { "Journal writes must share the business transaction" }
        var seq = 1L; var previous = "GENESIS"
        db.rawQuery("SELECT seq,signature FROM journal ORDER BY seq DESC LIMIT 1", null).use {
            if (it.moveToFirst()) { seq = it.getLong(0) + 1; previous = it.getString(1) }
        }
        val body = canonical(JSONObject().put("event", event).put("at", at).put("data", data))
        val signature = sign("$seq\n$previous\n$body")
        db.execSQL("INSERT INTO journal VALUES(?,?,?,?)", arrayOf<Any>(seq, body, previous, signature))
    }
    fun verify(): JSONObject {
        var seq = 1L; var previous = "GENESIS"
        val sales = mutableMapOf<Long,String>(); val reports = mutableMapOf<Long,String>()
        db.rawQuery("SELECT seq,body,previous,signature FROM journal ORDER BY seq", null).use {
            while (it.moveToNext()) {
                if (it.getLong(0) != seq || it.getString(2) != previous || sign("$seq\n$previous\n${it.getString(1)}") != it.getString(3)) throw ApiError(409, "Audit integrity check failed at entry $seq. Preserve the database and contact the owner")
                val event=JSONObject(it.getString(1));val data=event.getJSONObject("data")
                if(event.getString("event") in listOf("PAYMENT_APPROVED","LEGACY_SALE_IMPORTED")) {
                    val sale=data.getJSONObject("sale")
                    sales[sale.getLong("id")]=canonical(JSONObject().put("sale",sale).put("at",event.getLong("at")).put("grandTotal",data.getLong("grandTotal")))
                }
                if(event.getString("event")=="REPORT_SAVED") reports[data.getLong("id")]=canonical(data.getJSONObject("report"))
                previous = it.getString(3); seq++
            }
        }
        db.rawQuery("SELECT order_id,snapshot,approved_at,grand_total,amount,day FROM sales_ledger ORDER BY grand_total,approved_at,order_id",null).use {
            var grand=0L
            while(it.moveToNext()) {
                val sale=JSONObject(it.getString(1));grand=Math.addExact(grand,it.getLong(4))
                val actual=canonical(JSONObject().put("sale",sale).put("at",it.getLong(2)).put("grandTotal",it.getLong(3)))
                if(sales.remove(it.getLong(0))!=actual || grand!=it.getLong(3) || sale.getLong("total")!=it.getLong(4) || ReportPeriod.day(it.getLong(2))!=it.getString(5)) throw ApiError(409,"Sales ledger integrity check failed")
            }
        }
        db.rawQuery("SELECT id,snapshot,kind,day FROM saved_reports",null).use {while(it.moveToNext()) {
            val saved=JSONObject(it.getString(1))
            if(reports.remove(it.getLong(0))!=canonical(saved) || saved.getString("kind")!=it.getString(2) || saved.getString("day")!=it.getString(3)) throw ApiError(409,"Saved report integrity check failed")
        }}
        if(sales.isNotEmpty() || reports.isNotEmpty()) throw ApiError(409,"Missing audited sales or reports")
        val missing=db.rawQuery("SELECT count(*) FROM payments p LEFT JOIN sales_ledger s ON p.order_id=s.order_id WHERE s.order_id IS NULL OR p.approved_at!=s.approved_at",null).use{it.moveToFirst();it.getInt(0)}
        if(missing!=0) throw ApiError(409,"Payment ledger reconciliation failed")
        return JSONObject().put("entries", seq - 1).put("head", previous).put("valid", true)
    }
    fun initialize() = transaction {
        if (db.rawQuery("SELECT count(*) FROM journal", null).use { it.moveToFirst(); it.getInt(0) } == 0) {
            append("JOURNAL_STARTED", JSONObject().put("note", "Earlier transactions are imported, not retrospectively audited"))
            db.rawQuery("SELECT o.snapshot,p.approved_at FROM payments p JOIN orders o ON o.id=p.order_id ORDER BY p.approved_at,o.id", null).use {
                while (it.moveToNext()) recordSale(JSONObject(it.getString(0)), it.getLong(1), true)
            }
        }
        verify()
        db.rawQuery("SELECT value FROM pos_settings WHERE id='autoCutoff'",null).use {
            if(!it.moveToFirst()) { val defaults=cutoff(); persistCutoff(defaults); append("AUTO_CUTOFF_CONFIGURED",defaults) }
        }
    }
    fun profile(): JSONObject = db.rawQuery("SELECT value FROM pos_settings WHERE id='businessProfile'", null).use { if (it.moveToFirst()) JSONObject(it.getString(0)) else JSONObject() }
    fun saveProfile(args: JSONObject): JSONObject = transaction {
        val p = JSONObject()
        for (key in listOf("businessName", "tin", "address", "taxStatus", "serialNumber", "ptuNumber", "posModel", "accreditationNumber", "minNumber")) {
            val value = args.optString(key).trim()
            if (value.length > 250 || value.any { it == '\n' || it == '\r' }) fail("Invalid $key")
            p.put(key, value)
        }
        if (p.getString("taxStatus") !in listOf("VAT", "NON-VAT", "UNCONFIGURED")) fail("Choose VAT or NON-VAT status")
        db.execSQL("INSERT OR REPLACE INTO pos_settings VALUES('businessProfile',?)", arrayOf(p.toString()))
        append("BUSINESS_PROFILE_SAVED", p)
        p
    }
    fun cutoff(): JSONObject = db.rawQuery("SELECT value FROM pos_settings WHERE id='autoCutoff'", null).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)) else JSONObject().put("enabled",true).put("time","20:30").put("nextDay",ReportPeriod.day(System.currentTimeMillis()))
    }
    private fun persistCutoff(value: JSONObject) {
        db.execSQL("INSERT OR REPLACE INTO pos_settings VALUES('autoCutoff',?)",arrayOf(value.toString()))
    }
    fun configureCutoff(args: JSONObject, at: Long = System.currentTimeMillis()): JSONObject {
        store.operations.owner(args)
        return transaction {
            val time=args.optString("time")
            if (!Regex("(?:[01][0-9]|2[0-3]):[0-5][0-9]").matches(time) || args.opt("enabled") !is Boolean) fail("Choose a valid cutoff time")
            val previous=cutoff()
            if(args.has("enforceSalesDay") && args.opt("enforceSalesDay") !is Boolean) fail("Choose a valid sales-day setting")
            val value=JSONObject().put("enabled",args.getBoolean("enabled")).put("time",time)
                .put("enforceSalesDay",args.optBoolean("enforceSalesDay",previous.optBoolean("enforceSalesDay",true)))
                .put("nextDay",if(previous.getBoolean("enabled") && previous.optBoolean("enforceSalesDay",true)) previous.getString("nextDay") else ReportPeriod.day(at))
            persistCutoff(value); append("AUTO_CUTOFF_CONFIGURED",value,at); value
        }
    }
    private fun cutoffAt(day: String, time: String): Long = ReportPeriod.bounds("daily",day).first +
        (time.substring(0,2).toLong()*60 + time.substring(3).toLong())*60000
    // Called by the foreground service and before local operations. The cursor and
    // immutable Z-reading commit together, so restart/retry cannot close twice.
    fun runCutoff(at: Long = System.currentTimeMillis()) = transaction {
        val config=cutoff()
        if(!config.getBoolean("enabled") || !config.optBoolean("enforceSalesDay",true)) return@transaction
        var day=config.getString("nextDay")
        var processed=0
        while(cutoffAt(day,config.getString("time")) <= at && processed < 366) {
            if(day > lastClosed()) {
                val saved=save("Z",day,"auto-cutoff-"+day,at)
                append("AUTO_CUTOFF_COMPLETED",JSONObject().put("day",day).put("reportId",saved.getLong("id"))
                    .put("scheduledAt",cutoffAt(day,config.getString("time"))),at)
            }
            day=ReportPeriod.day(ReportPeriod.bounds("daily",day).second)
            processed++
        }
        if(processed > 0) persistCutoff(config.put("nextDay",day))
    }
    fun grandTotal(): Long = db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM sales_ledger", null).use { it.moveToFirst(); it.getLong(0) }
    fun assertOpen(at: Long) {
        verify()
        val config=cutoff()
        if(config.optBoolean("enforceSalesDay",true) && config.getBoolean("enabled") && ReportPeriod.day(at) >= config.getString("nextDay") && at >= cutoffAt(ReportPeriod.day(at),config.getString("time")))
            throw ApiError(409,"Daily cutoff reached at " + config.getString("time") + " Philippine time. Payments resume at midnight")
        val last = lastClosed()
        if (config.optBoolean("enforceSalesDay",true) && last.isNotEmpty() && ReportPeriod.day(at) <= last) throw ApiError(409, "This sales day is closed by Z-reading. Check tablet date/time; payment can resume on the next day")
        val newest = db.rawQuery("SELECT COALESCE(MAX(approved_at),0) FROM sales_ledger", null).use { it.moveToFirst(); it.getLong(0) }
        if (at < newest) throw ApiError(409, "Tablet clock moved backwards. Correct date/time before approving payment")
    }
    fun lastClosed(): String = db.rawQuery("SELECT COALESCE(MAX(day),'') FROM saved_reports WHERE kind='Z'", null).use { it.moveToFirst(); it.getString(0) }
    fun recordSale(order: JSONObject, at: Long, imported: Boolean = false) {
        val snapshot = JSONObject(order.toString()).put("business", profile()).put("imported", imported).put("salesDayEnforced",cutoff().optBoolean("enforceSalesDay",true))
        val total = order.getLong("total"); val grand = Math.addExact(grandTotal(), total)
        db.execSQL("INSERT INTO sales_ledger VALUES(?,?,?,?,?,?)", arrayOf<Any>(order.getLong("id"), at, ReportPeriod.day(at), total, grand, snapshot.toString()))
        append(if (imported) "LEGACY_SALE_IMPORTED" else "PAYMENT_APPROVED", JSONObject().put("sale", snapshot).put("grandTotal", grand), at)
    }
    fun summary(kind: String, day: String, at: Long = System.currentTimeMillis()): JSONObject = transaction {
        val (start, end) = ReportPeriod.bounds(kind, day)
        val methods = linkedMapOf<String, JSONObject>(); val cashiers = linkedMapOf<String, JSONObject>(); val days = linkedMapOf<String, JSONObject>()
        var total = 0L; var count = 0; var cash = 0L; var first = ""; var last = ""
        fun group(map: MutableMap<String, JSONObject>, key: String, name: String, amount: Long) {
            val row = map.getOrPut(key) { JSONObject().put("name", name).put("count", 0).put("total", 0L) }
            row.put("count", row.getInt("count") + 1).put("total", Math.addExact(row.getLong("total"), amount))
        }
        db.rawQuery("SELECT snapshot,amount,day FROM sales_ledger WHERE approved_at>=? AND approved_at<? AND approved_at<=? ORDER BY approved_at,order_id", arrayOf(start.toString(), end.toString(), at.toString())).use {
            while (it.moveToNext()) {
                val o = JSONObject(it.getString(0)); val amount = it.getLong(1)
                val p = o.optJSONObject("paymentMethod") ?: JSONObject().put("name", "Legacy / unspecified").put("cash", false)
                total = Math.addExact(total, amount); count++; if (p.optBoolean("cash")) cash += amount
                if (first.isEmpty()) first = o.optString("number"); last = o.optString("number")
                group(methods, canonical(p), p.getString("name"), amount)
                group(cashiers, o.optString("cashierId") + ":" + o.optString("operator"), o.optString("operator", "Legacy / unspecified"), amount)
                group(days, it.getString(2), it.getString(2), amount)
            }
        }
        var cancelled = 0; var cancelledAmount = 0L
        val orders = store.history()
        for (i in 0 until orders.length()) {
            val o = orders.getJSONObject(i); val whenCancelled = o.optLong("decisionAt")
            if (o.optString("state") == "cancelled" && whenCancelled >= start && whenCancelled < end && whenCancelled <= at) { cancelled++; cancelledAmount += o.getLong("total") }
        }
        val previous = db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM sales_ledger WHERE approved_at<?", arrayOf(start.toString())).use { it.moveToFirst(); it.getLong(0) }
        JSONObject().put("kind", kind).put("day", day).put("start", ReportPeriod.day(start)).put("end", ReportPeriod.day(end - 1)).put("timezone", "Asia/Manila")
            .put("generatedAt", at).put("business", profile()).put("total", total).put("count", count).put("cashSales", cash).put("otherSales", total - cash)
            .put("cancelledCount", cancelled).put("cancelledAmount", cancelledAmount).put("firstOrder", first).put("lastOrder", last)
            .put("previousGrandTotal", previous).put("periodGrandTotal", previous + total).put("lifetimeGrandTotal", grandTotal())
            .put("methods", JSONArray(methods.values.toList())).put("cashiers", JSONArray(cashiers.values.toList())).put("days", JSONArray(days.values.toList()))
            .put("lastClosedDay", lastClosed()).put("audit", verify())
    }
    fun save(kind: String, day: String, request: String, at: Long = System.currentTimeMillis()): JSONObject = transaction {
        if (!Regex("[A-Za-z0-9-]{16,100}").matches(request)) fail("Invalid report request ID")
        db.rawQuery("SELECT id,snapshot FROM saved_reports WHERE request=? OR (kind='Z' AND ?='Z' AND day=?)", arrayOf(request, kind, day)).use {
            if (it.moveToFirst()) {
                val saved = JSONObject(it.getString(1)).put("id", it.getLong(0))
                if (saved.getString("kind") != kind || saved.getString("day") != day) throw ApiError(409, "Report request already used")
                return@transaction saved
            }
        }
        if (kind == "Z") {
            if (day > ReportPeriod.day(at)) fail("Cannot close a future day")
            if (day <= lastClosed()) throw ApiError(409, "Close sales days in chronological order")
        }
        val report = summary(kind, day, at)
        db.execSQL("INSERT INTO saved_reports(request,kind,day,snapshot) VALUES(?,?,?,?)", arrayOf(request, kind, day, report.toString()))
        val id = db.rawQuery("SELECT last_insert_rowid()", null).use { it.moveToFirst(); it.getLong(0) }
        // ID belongs to the immutable row, not a subsequent UPDATE.
        append("REPORT_SAVED", JSONObject().put("id", id).put("report", report))
        JSONObject(report.toString()).put("id", id)
    }
    fun saved(id: Long): JSONObject = db.rawQuery("SELECT snapshot FROM saved_reports WHERE id=?", arrayOf(id.toString())).use {
        if (!it.moveToFirst()) throw ApiError(404, "Saved report not found")
        JSONObject(it.getString(0)).put("id", id)
    }
    fun list(): JSONArray = JSONArray().also { rows -> db.rawQuery("SELECT id,snapshot FROM saved_reports ORDER BY id DESC", null).use { while (it.moveToNext()) rows.put(JSONObject(it.getString(1)).put("id", it.getLong(0))) } }
    fun state(): JSONObject = transaction { JSONObject().put("profile", profile()).put("autoCutoff",cutoff()).put("reports", list()).put("lastClosedDay", lastClosed()).put("grandTotal", grandTotal()).put("today", ReportPeriod.day(System.currentTimeMillis())).put("audit", verify()) }
    fun export(): JSONObject = transaction {
        val journal = JSONArray(); val sales = JSONArray()
        db.rawQuery("SELECT seq,body,previous,signature FROM journal ORDER BY seq", null).use { while (it.moveToNext()) journal.put(JSONObject().put("seq", it.getLong(0)).put("body", it.getString(1)).put("previous", it.getString(2)).put("signature", it.getString(3))) }
        db.rawQuery("SELECT snapshot,approved_at,grand_total FROM sales_ledger ORDER BY approved_at,order_id", null).use { while (it.moveToNext()) sales.put(JSONObject().put("sale", JSONObject(it.getString(0))).put("approvedAt", it.getLong(1)).put("grandTotal", it.getLong(2))) }
        state().put("journal", journal).put("sales", sales)
    }
    fun printRecord(type: String, id: Long): JSONObject = transaction {
        verify()
        val document = when (type) {
            "report" -> saved(id)
            else -> fail("Unknown print document")
        }
        var copies = 0
        db.rawQuery("SELECT body FROM journal", null).use { while (it.moveToNext()) {
            val event = JSONObject(it.getString(0)); val data = event.getJSONObject("data")
            if (event.getString("event") == "PRINT_REQUESTED" && data.optString("type") == type && data.optLong("id") == id) copies++
        } }
        append("PRINT_REQUESTED", JSONObject().put("type", type).put("id", id).put("attempt", copies + 1).put("reprint", copies > 0).put("documentHash", digest(canonical(document))))
        document.put("printAttempt", copies + 1).put("printedAt", System.currentTimeMillis())
    }
}
