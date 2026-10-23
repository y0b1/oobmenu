package dev.luminatech.oob_pos

import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

fun createShiftTables(db: SQLiteDatabase) {
    db.execSQL("CREATE TABLE pos_settings (id TEXT PRIMARY KEY, value TEXT NOT NULL)")
    db.execSQL("CREATE TABLE cashiers (id TEXT PRIMARY KEY, name TEXT NOT NULL, auth TEXT NOT NULL, enabled INTEGER NOT NULL)")
    db.execSQL("CREATE TABLE payment_methods (id TEXT PRIMARY KEY, name TEXT NOT NULL, cash INTEGER NOT NULL, enabled INTEGER NOT NULL)")
    db.execSQL("CREATE TABLE shifts (id TEXT PRIMARY KEY, active INTEGER UNIQUE, snapshot TEXT NOT NULL)")
    db.execSQL("INSERT INTO payment_methods VALUES('cash','Cash',1,1),('gcash','GCash',0,1)")
    db.execSQL("INSERT INTO pos_settings VALUES('requirePin','true')")
}

// SHA-1 PBKDF2 is available on every supported Android version (API 24+).
// Salted, deliberately slow derivation; low-entropy cashier PINs also need lockout.
private fun derive(secret: String, salt: String): ByteArray {
    val spec = PBEKeySpec(secret.toCharArray(), salt.toByteArray(Charsets.UTF_8), 210000, 256)
    return try { SecretKeyFactory.getInstance("PBKDF2WithHmacSHA1").generateSecret(spec).encoded }
    finally { spec.clearPassword() }
}
private fun password(secret: String): String {
    val salt = token()
    return JSONObject().put("salt",salt).put("hash",derive(secret,salt).joinToString("") { "%02x".format(it) }).toString()
}
private fun matches(secret: String, stored: String): Boolean {
    val record = JSONObject(stored)
    val actual = derive(secret,record.getString("salt")).joinToString("") { "%02x".format(it) }
    return MessageDigest.isEqual(actual.toByteArray(),record.getString("hash").toByteArray())
}

class CashierOperations(private val store: OrderStore) {
    private val db get() = store.writableDatabase
    private var ownerSession = ""
    private var ownerUntil = 0L
    private fun setting(key: String): String? = db.rawQuery("SELECT value FROM pos_settings WHERE id=?",arrayOf(key)).use { if(it.moveToFirst()) it.getString(0) else null }
    private fun setting(key: String, value: String) = db.execSQL("INSERT OR REPLACE INTO pos_settings VALUES(?,?)",arrayOf(key,value))
    fun initializeOwnerPassword() = store.reports.transaction {
        if(setting("owner") == null) {
            setting("owner",password("oob12345"))
            store.reports.append("DEFAULT_OWNER_PASSWORD_INITIALIZED")
        }
    }
    private fun text(args: JSONObject, key: String, max: Int = 80): String {
        val value = args.optString(key).trim()
        if (value.isEmpty() || value.length > max) fail("Enter $key (up to $max characters)")
        return value
    }
    private fun amount(args: JSONObject, key: String): Long {
        val value = args.opt(key)
        if (value !is Int && value !is Long) fail("$key must be an amount in whole centavos")
        val n = (value as Number).toLong()
        if(n !in 0..10000000000L) fail("$key is outside the allowed range")
        return n
    }
    private fun pin(args: JSONObject): String = args.optString("pin").also { if(!Regex("[0-9]{4}").matches(it)) fail("Enter a four-digit cashier PIN") }
    private fun verify(key: String, secret: String, hash: String) {
        val lock = JSONObject(setting("lock:$key") ?: "{}")
        if(lock.optLong("until") > System.currentTimeMillis()) throw ApiError(429,"Too many attempts. Try again in 5 minutes")
        if(!matches(secret,hash)) {
            val count = lock.optInt("attempts") + 1
            setting("lock:$key",JSONObject().put("attempts",if(count >= 5) 0 else count).put("until",if(count >= 5) System.currentTimeMillis()+300000 else 0).toString())
            throw ApiError(403,"Incorrect password or PIN")
        }
        setting("lock:$key","{}")
    }
    fun owner(args: JSONObject) {
        if(ownerSession.isEmpty() || args.optString("session") != ownerSession || System.currentTimeMillis() >= ownerUntil) throw ApiError(403,"Unlock owner settings again")
    }
    private fun cashier(id: String): JSONObject = db.rawQuery("SELECT name,auth,enabled FROM cashiers WHERE id=?",arrayOf(id)).use {
        if(!it.moveToFirst() || it.getInt(2) != 1) fail("Select an enabled cashier")
        JSONObject().put("id",id).put("name",it.getString(0)).put("auth",it.getString(1))
    }
    private fun active(): JSONObject? = db.rawQuery("SELECT snapshot FROM shifts WHERE active=1",null).use { if(it.moveToFirst()) JSONObject(it.getString(0)) else null }
    private fun tracking() = setting("cashierTracking") != "false"
    private fun transactionOperator(): JSONObject? {
        val shift=active()
        if(tracking()) return shift
        return JSONObject().put("id","pos-local:"+(shift?.getString("id") ?: "unassigned"))
            .put("cashierId","pos-local").put("cashier","POS operator")
            .put("registerShiftId",shift?.getString("id") ?: "pos-unassigned")
    }
    private fun requireShift(args: JSONObject, alwaysPin: Boolean = false): JSONObject {
        val shift = (if(alwaysPin) active() else transactionOperator()) ?: throw ApiError(409,"Start a cashier shift first")
        if(args.optString("shiftId") != shift.getString("id")) throw ApiError(409,"The active shift changed. Review and try again")
        if(!alwaysPin && !tracking()) return shift
        val c = cashier(shift.getString("cashierId"))
        if(alwaysPin || setting("requirePin") != "false") verify("cashier:${c.getString("id")}",pin(args),c.getString("auth"))
        return shift
    }
    private fun save(order: JSONObject) { db.execSQL("UPDATE orders SET snapshot=? WHERE id=?",arrayOf<Any>(order.toString(),order.getLong("id"))) }
    private fun totals(shift: JSONObject): JSONObject {
        val methods = linkedMapOf<String,JSONObject>(); var cash = 0L
        val orders = store.history()
        for(i in 0 until orders.length()) {
            val order = orders.getJSONObject(i)
            if(order.optString("shiftId") != shift.getString("id") || order.optString("state") != "paid") continue
            val p = order.getJSONObject("paymentMethod")
            // Group by snapshot as well as ID: renaming a method does not rewrite history.
            val key = p.toString()
            val row = methods.getOrPut(key) { JSONObject(p.toString()).put("total",0L).put("count",0) }
            row.put("total",row.getLong("total")+order.getLong("total")).put("count",row.getInt("count")+1)
            if(p.getBoolean("cash")) cash += order.getLong("total")
        }
        return JSONObject(shift.toString()).put("cashSales",cash).put("expected",shift.getLong("opening")+cash).put("methods",JSONArray(methods.values.toList()))
    }
    @Synchronized fun state(): JSONObject {
        val cashiers = JSONArray(); val methods = JSONArray(); val shifts = JSONArray()
        db.rawQuery("SELECT id,name,enabled FROM cashiers ORDER BY name",null).use { while(it.moveToNext()) cashiers.put(JSONObject().put("id",it.getString(0)).put("name",it.getString(1)).put("enabled",it.getInt(2)==1)) }
        db.rawQuery("SELECT id,name,cash,enabled FROM payment_methods ORDER BY rowid",null).use { while(it.moveToNext()) methods.put(JSONObject().put("id",it.getString(0)).put("name",it.getString(1)).put("cash",it.getInt(2)==1).put("enabled",it.getInt(3)==1)) }
        db.rawQuery("SELECT snapshot FROM shifts ORDER BY rowid DESC",null).use { while(it.moveToNext()) { val s=JSONObject(it.getString(0)); shifts.put(if(s.has("closedAt")) s else totals(s)) } }
        return JSONObject().put("ownerConfigured",setting("owner") != null).put("cashierTracking",tracking()).put("transactionOperator",transactionOperator() ?: JSONObject.NULL).put("requirePin",tracking() && setting("requirePin") != "false").put("cashiers",cashiers).put("methods",methods).put("shifts",shifts).put("activeShift",active()?.let { totals(it) } ?: JSONObject.NULL)
    }
    @Synchronized fun execute(method: String, args: JSONObject): JSONObject {
        // Failed credentials are saved outside business transactions, so rollback cannot erase lockout.
        when(method) {
            "ownerSetup" -> {
                if(setting("owner") != null) throw ApiError(409,"Owner already configured")
                val secret = text(args,"password",128)
                if(secret.length < 8) fail("Owner password needs at least eight characters")
                setting("owner",password(secret))
                ownerSession=token(); ownerUntil=System.currentTimeMillis()+300000
                return JSONObject().put("session",ownerSession)
            }
            "ownerLogin" -> {
                verify("owner",args.optString("password"),setting("owner") ?: fail("Set up the owner first"))
                ownerSession=token(); ownerUntil=System.currentTimeMillis()+300000
                return JSONObject().put("session",ownerSession)
            }
            "ownerLock" -> { ownerSession=""; ownerUntil=0; return JSONObject() }
            "saveCashier", "saveMethod", "setPinRequired", "setCashierTracking", "changeOwnerPassword" -> owner(args)
        }
        var authorizedShift: JSONObject? = null
        if(method in listOf("approve","cancel","closeShift")) authorizedShift=requireShift(args,method=="closeShift")
        if(method == "startShift") {
            val c=cashier(text(args,"cashierId"))
            verify("cashier:${c.getString("id")}",pin(args),c.getString("auth"))
        }
        db.beginTransaction()
        try {
            if(authorizedShift != null && (if(method=="closeShift") active() else transactionOperator())?.optString("id") != authorizedShift.getString("id")) throw ApiError(409,"The active shift changed. Review and try again")
            val result = when(method) {
                "customOrder" -> {
                    val s = transactionOperator() ?: throw ApiError(409,"Start a cashier shift first")
                    if (args.optString("shiftId") != s.getString("id")) throw ApiError(409,"The active shift changed")
                    val request = text(args,"requestId",100)
                    if (!Regex("[a-zA-Z0-9-]{20,100}").matches(request)) fail("Invalid request ID")
                    val body = JSONObject().put("name",text(args,"name",120)).put("notes",args.optString("notes").trim()).put("quantity",args.opt("quantity")).put("unitPrice",amount(args,"unitPrice"))
                    if(body.getString("notes").length>500) fail("Notes must be at most 500 characters")
                    val quantity = args.opt("quantity")
                    if(quantity !is Int || quantity !in 1..99) fail("Quantity must be 1 to 99")
                    if(body.getLong("unitPrice") <= 0 || body.getLong("unitPrice") * quantity > 100000000) fail("Enter a positive price, maximum order PHP 1,000,000")
                    val existing = db.rawQuery("SELECT body,snapshot FROM orders WHERE device='pos-local' AND request=?",arrayOf(request)).use {
                        if(it.moveToFirst()) {
                            if(!JSONObject(it.getString(0)).similarTo(body)) throw ApiError(409,"Request ID already used with different contents")
                            JSONObject(it.getString(1))
                        } else null
                    }
                    if(existing != null) existing else {
                        db.execSQL("INSERT OR IGNORE INTO devices VALUES('pos-local',?)",arrayOf(token()))
                        val item=JSONObject(body.toString()).put("id","pos-custom").put("modifiers",JSONArray()).put("total",body.getLong("unitPrice")*quantity)
                        val o=JSONObject().put("source","pos_custom").put("items",JSONArray().put(item)).put("total",item.getLong("total")).put("state","awaiting_payment").put("submittedAt",System.currentTimeMillis()).put("requestId",request).put("createdBy",s.getString("cashier"))
                        db.execSQL("INSERT INTO orders(device,request,body,snapshot) VALUES('pos-local',?,?,?)",arrayOf(request,body.toString(),o.toString()))
                        val id=db.rawQuery("SELECT last_insert_rowid()",null).use{it.moveToFirst();it.getLong(0)}
                        o.put("id",id).put("number","OOB-"+id.toString().padStart(6,'0'));save(o);o
                    }
                }
                "changeOwnerPassword" -> {
                    val secret=text(args,"password",128); if(secret.length<8) fail("Owner password needs at least eight characters")
                    setting("owner",password(secret)); ownerSession=""; JSONObject()
                }
                "setCashierTracking" -> { if(args.opt("enabled") !is Boolean) fail("Choose the cashier setting"); setting("cashierTracking",args.getBoolean("enabled").toString()); JSONObject().put("enabled",args.getBoolean("enabled")) }
                "setPinRequired" -> { if(args.opt("enabled") !is Boolean) fail("Choose the PIN setting"); setting("requirePin",args.getBoolean("enabled").toString()); JSONObject() }
                "saveCashier" -> {
                    val id=args.optString("id").ifEmpty { token() }; val name=text(args,"name")
                    val existing=db.rawQuery("SELECT auth FROM cashiers WHERE id=?",arrayOf(id)).use { if(it.moveToFirst()) it.getString(0) else null }
                    val auth=if(args.optString("pin").isNotEmpty()) password(pin(args)) else existing ?: fail("Enter a four-digit cashier PIN")
                    if(active()?.optString("cashierId")==id) throw ApiError(409,"Close this cashier's shift before editing their account")
                    db.execSQL("INSERT OR REPLACE INTO cashiers VALUES(?,?,?,?)",arrayOf(id,name,auth,if(args.optBoolean("enabled",true)) 1 else 0)); JSONObject()
                }
                "saveMethod" -> {
                    val id=args.optString("id").ifEmpty { token() }; val name=text(args,"name")
                    if(args.opt("cash") !is Boolean) fail("Choose whether this method adds to the lockbox")
                    db.execSQL("INSERT OR REPLACE INTO payment_methods VALUES(?,?,?,?)",arrayOf(id,name,if(args.getBoolean("cash")) 1 else 0,if(args.optBoolean("enabled",true)) 1 else 0)); JSONObject()
                }
                "startShift" -> {
                    if(active()!=null) throw ApiError(409,"Close the active shift before starting another")
                    val c=cashier(args.getString("cashierId"))
                    val s=JSONObject().put("id",token()).put("cashierId",c.getString("id")).put("cashier",c.getString("name")).put("opening",amount(args,"opening")).put("openedAt",System.currentTimeMillis())
                    db.execSQL("INSERT INTO shifts VALUES(?,1,?)",arrayOf(s.getString("id"),s.toString())); s
                }
                "closeShift" -> {
                    val s=totals(authorizedShift!!); val closing=amount(args,"closing")
                    s.put("closing",closing).put("difference",closing-s.getLong("expected")).put("closedAt",System.currentTimeMillis())
                    db.execSQL("UPDATE shifts SET active=NULL,snapshot=? WHERE id=?",arrayOf(s.toString(),s.getString("id"))); s
                }
                "review" -> {
                    val s=transactionOperator() ?: throw ApiError(409,"Start a cashier shift first")
                    if(args.optString("shiftId") != s.getString("id")) throw ApiError(409,"The active shift changed")
                    val o=store.get(args.getLong("id"))
                    if(o.getString("state")!="awaiting_payment") throw ApiError(409,"Order already decided")
                    if(!args.optBoolean("confirmed")) fail("Recheck the items verbally with the customer")
                    o.put("reviewedAt",System.currentTimeMillis()).put("reviewedBy",s.getString("cashier")).put("reviewedShiftId",s.getString("id")); save(o); o
                }
                "approve", "cancel" -> {
                    val s=authorizedShift!!; val o=store.get(args.getLong("id")); val target=if(method=="approve") "paid" else "cancelled"
                    if(o.getString("state")==target) o else {
                        if(o.getString("state")!="awaiting_payment") throw ApiError(409,"Order already decided")
                        val now=System.currentTimeMillis()
                        store.reports.assertOpen(now)
                        if(method=="approve") {
                            if(!o.has("reviewedAt") || o.optString("reviewedShiftId")!=s.getString("id")) fail("Recheck this order verbally before payment")
                            if(!args.optBoolean("verified")) fail("Confirm that payment has been checked")
                            val methodId=text(args,"methodId")
                            val p=db.rawQuery("SELECT name,cash FROM payment_methods WHERE id=? AND enabled=1",arrayOf(methodId)).use {
                                if(!it.moveToFirst()) fail("Select an enabled payment method")
                                JSONObject().put("id",methodId).put("name",it.getString(0)).put("cash",it.getInt(1)==1)
                            }
                            val beeper=text(args,"beeper",4)
                            if(!Regex("[1-9][0-9]{0,3}").matches(beeper)) fail("Beeper number must be 1 to 9999")
                            val history=store.history()
                            for(i in 0 until history.length()) { val other=history.getJSONObject(i); if(other.optString("fulfillment")=="queued" && other.optString("beeper")==beeper) throw ApiError(409,"That beeper is already in the queue") }
                            val tendered=if(p.getBoolean("cash")) amount(args,"tendered") else o.getLong("total")
                            if(tendered < o.getLong("total")) fail("Cash received is less than the total")
                            val reference=args.optString("reference").trim(); if(reference.length>120) fail("Reference is too long")
                            db.execSQL("INSERT INTO payments(order_id,operator,approved_at,reference) VALUES(?,?,?,?)",arrayOf(o.getLong("id"),s.getString("cashier"),now,reference))
                            o.put("paymentMethod",p).put("tendered",tendered).put("change",tendered-o.getLong("total")).put("reference",reference).put("beeper",beeper).put("fulfillment","queued").put("queuedAt",now).put("pinRequired",tracking() && setting("requirePin")!="false").put("cashierTracking",tracking())
                        } else {
                            val reason=args.optString("reason").trim(); if(reason.length>500) fail("Reason is too long"); o.put("reason",reason)
                        }
                        o.put("state",target).put("operator",s.getString("cashier")).put("cashierId",s.getString("cashierId")).put("shiftId",s.optString("registerShiftId",s.getString("id"))).put("decisionAt",now)
                        save(o)
                        if(method=="approve") store.reports.recordSale(o, now) else store.reports.append("ORDER_CANCELLED", o)
                        o
                    }
                }
                "complete" -> {
                    val o=store.get(args.getLong("id"))
                    if(o.getString("state")!="paid") fail("Only paid orders can be completed")
                    if(o.optString("fulfillment")!="completed") { o.put("fulfillment","completed").put("completedAt",System.currentTimeMillis()); save(o) }; o
                }
                else -> fail("Unknown cashier operation")
            }
            if (method !in listOf("approve", "cancel")) {
                val safe = JSONObject(result.toString())
                if (method in listOf("saveCashier", "saveMethod", "setPinRequired")) {
                    for (key in listOf("id", "name", "cash", "enabled")) if(args.has(key)) safe.put(key,args.get(key))
                }
                store.reports.append("CASHIER_" + method.uppercase(), safe)
            }
            db.setTransactionSuccessful(); return result
        } finally { db.endTransaction() }
    }
}
