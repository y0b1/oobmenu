package dev.luminatech.oob_pos

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.security.SecureRandom

class ApiError(val code: Int, override val message: String) : RuntimeException(message)
fun fail(message: String): Nothing = throw ApiError(400, message)
fun token(): String = ByteArray(32).also { SecureRandom().nextBytes(it) }.joinToString("") { "%02x".format(it) }
fun digest(value: String): String = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }

class OrderStore(context: Context, signer: (String) -> String = JournalSigner()::sign) : SQLiteOpenHelper(context, "orders.db", null, 3) {
    val catalog = JSONObject(context.assets.open("catalog.json").bufferedReader().use { it.readText() })
    val reports = Reports(this, signer)
    init { reports.initialize() }
    override fun onConfigure(db: SQLiteDatabase) {
        db.setForeignKeyConstraintsEnabled(true)
        db.execSQL("PRAGMA synchronous=FULL")
    }
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE devices (id TEXT PRIMARY KEY, secret TEXT UNIQUE NOT NULL)")
        db.execSQL("CREATE TABLE orders (id INTEGER PRIMARY KEY AUTOINCREMENT, device TEXT NOT NULL REFERENCES devices(id), request TEXT NOT NULL, body TEXT NOT NULL, snapshot TEXT NOT NULL, UNIQUE(device,request))")
        db.execSQL("CREATE TABLE payments (order_id INTEGER PRIMARY KEY REFERENCES orders(id), operator TEXT NOT NULL, approved_at INTEGER NOT NULL, reference TEXT)")
        createShiftTables(db)
        createReportTables(db)
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) createShiftTables(db)
        if (oldVersion < 3) createReportTables(db)
    }
    @Synchronized fun pair(): JSONObject {
        val id = token(); val secret = token()
        writableDatabase.execSQL("INSERT INTO devices(id,secret) VALUES(?,?)", arrayOf(id, digest(secret)))
        return JSONObject().put("device", id).put("credential", secret)
    }
    @Synchronized fun authenticate(secret: String): String {
        readableDatabase.rawQuery("SELECT id FROM devices WHERE secret=?", arrayOf(digest(secret))).use {
            if (it.moveToFirst()) return it.getString(0)
        }
        throw ApiError(401, "Pair this menu tablet again")
    }
    @Synchronized fun revoke() { writableDatabase.execSQL("UPDATE devices SET secret=lower(hex(randomblob(32)))") }
    @Synchronized fun get(id: Long, device: String? = null): JSONObject {
        readableDatabase.rawQuery("SELECT device,snapshot FROM orders WHERE id=?", arrayOf(id.toString())).use {
            if (!it.moveToFirst() || (device != null && it.getString(0) != device)) throw ApiError(404, "Order not found")
            return JSONObject(it.getString(1))
        }
    }
    @Synchronized fun history(): JSONArray {
        val result = JSONArray()
        readableDatabase.rawQuery("SELECT snapshot FROM orders ORDER BY id ASC", null).use {
            while (it.moveToNext()) result.put(JSONObject(it.getString(0)))
        }
        return result
    }
    @Synchronized fun submit(device: String, request: JSONObject): JSONObject {
        val requestId = request.optString("requestId")
        if (!Regex("[a-zA-Z0-9-]{20,80}").matches(requestId)) fail("Invalid request ID")
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.rawQuery("SELECT body,snapshot FROM orders WHERE device=? AND request=?", arrayOf(device,requestId)).use {
                if (it.moveToFirst()) {
                    if (!JSONObject(it.getString(0)).similarTo(request)) throw ApiError(409, "Request ID already used with different contents")
                    return JSONObject(it.getString(1)).also { db.setTransactionSuccessful() }
                }
            }
            val accepted = OrderRules.accept(catalog, request)
            val created = System.currentTimeMillis()
            accepted.put("state", "awaiting_payment").put("submittedAt",created).put("requestId",requestId)
            db.execSQL("INSERT INTO orders(device,request,body,snapshot) VALUES(?,?,?,?)", arrayOf(device,requestId,request.toString(),accepted.toString()))
            val id = db.rawQuery("SELECT last_insert_rowid()", null).use { it.moveToFirst(); it.getLong(0) }
            accepted.put("id", id).put("number", "OOB-" + id.toString().padStart(6,'0'))
            db.execSQL("UPDATE orders SET snapshot=? WHERE id=?", arrayOf<Any>(accepted.toString(),id))
            reports.append("ORDER_ACCEPTED", accepted)
            db.setTransactionSuccessful()
            return accepted
        } finally { db.endTransaction() }
    }
    @Synchronized fun cancelFromMenu(id: Long, device: String): JSONObject = reports.transaction {
        val order=get(id,device)
        if(order.getString("state")=="cancelled") return@transaction order
        if(order.getString("state")!="awaiting_payment") throw ApiError(409,"Payment is already confirmed. Ask the cashier for help")
        val now=System.currentTimeMillis()
        reports.assertOpen(now)
        order.put("state","cancelled").put("decisionAt",now).put("operator","Menu customer")
            .put("reason","Customer cancelled an incorrect order").put("cancelledBy","customer")
        writableDatabase.execSQL("UPDATE orders SET snapshot=? WHERE id=?",arrayOf<Any>(order.toString(),id))
        reports.append("CUSTOMER_CANCELLED_ORDER",order)
        order
    }
    // Kept as an explicit rejection so old local UI builds cannot bypass shift/PIN rules.
    @Synchronized fun decide(id: Long, paid: Boolean, operator: String, reason: String, reference: String): JSONObject {
        throw ApiError(403, "Update the POS interface to use cashier shifts")
    }
    val operations by lazy { CashierOperations(this) }

}

// Structural JSON equality ignores object-key ordering but preserves line ordering.
fun JSONObject.similarTo(other: JSONObject): Boolean = canonical(this) == canonical(other)
fun canonical(value: Any?): String = when (value) {
    is JSONObject -> value.keys().asSequence().toList().sorted().joinToString(prefix="{",postfix="}") { JSONObject.quote(it)+":"+canonical(value.get(it)) }
    is JSONArray -> (0 until value.length()).joinToString(prefix="[",postfix="]") { canonical(value.get(it)) }
    is String -> JSONObject.quote(value)
    else -> value.toString()
}

object OrderRules {
    fun accept(catalog: JSONObject, request: JSONObject): JSONObject {
        val paymentChoice = request.opt("paymentChoice")
        if (request.has("paymentChoice") && paymentChoice != "cash" && paymentChoice != "qr") fail("Payment choice must be cash or qr")
        val lines = request.optJSONArray("items") ?: fail("Items are required")
        if (lines.length() !in 1..50) fail("Choose between 1 and 50 order lines")
        val products = catalog.getJSONArray("products")
        val modifiers = catalog.getJSONArray("modifiers")
        val accepted = JSONArray(); var total = 0L
        for (i in 0 until lines.length()) {
            val line = lines.getJSONObject(i)
            val product = (0 until products.length()).map { products.getJSONObject(it) }.firstOrNull { it.getString("id") == line.optString("id") } ?: fail("Unknown product")
            val quantity = line.opt("quantity")
            if (quantity !is Int || quantity !in 1..99) fail("Quantity must be an integer from 1 to 99")
            val notes = line.optString("notes", "")
            if (notes.length > 500) fail("Notes must be at most 500 characters")
            val mods = line.optJSONArray("modifiers") ?: fail("Modifiers must be a list")
            val allowed = product.getJSONArray("modifiers")
            val selected = mutableSetOf<String>(); val snapshotMods = JSONArray()
            var unit = product.getInt("price")
            for (m in 0 until mods.length()) {
                val name = mods.getString(m)
                if (!selected.add(name) || !(0 until allowed.length()).any { allowed.getString(it) == name }) fail("Invalid or repeated modifier")
                val modifier = (0 until modifiers.length()).map { modifiers.getJSONObject(it) }.first { it.getString("id") == name }
                unit += modifier.getInt("price"); snapshotMods.put(JSONObject(modifier.toString()))
            }
            if (selected.containsAll(listOf("cold-whisk","traditional"))) fail("Select only one whisking method")
            if (line.opt("expectedUnitPrice") !is Int || line.getInt("expectedUnitPrice") != unit) throw ApiError(409,"Price changed. Review the current POS catalog before submitting again")
            val lineTotal = unit.toLong() * quantity
            total += lineTotal
            if (total > 100000000) fail("Order exceeds the allowed total")
            accepted.put(JSONObject().put("id",product.getString("id")).put("name",product.getString("name")).put("quantity",quantity).put("notes",notes).put("modifiers",snapshotMods).put("unitPrice",unit).put("total",lineTotal))
        }
        return JSONObject().put("items",accepted).put("total",total).also { if(paymentChoice != null) it.put("paymentChoice",paymentChoice) }
    }
}
