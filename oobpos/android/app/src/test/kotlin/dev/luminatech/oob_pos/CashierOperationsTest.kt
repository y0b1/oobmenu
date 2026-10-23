package dev.luminatech.oob_pos

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28])
class CashierOperationsTest {
    private lateinit var context: Context
    private lateinit var store: OrderStore
    private lateinit var device: String
    private lateinit var session: String
    private var requestId=0
    private fun json(vararg pairs: Pair<String,Any>) = JSONObject().also { o -> pairs.forEach { o.put(it.first,it.second) } }
    private fun op(name: String,args: JSONObject=JSONObject()) = store.operations.execute(name,args)
    private fun owner(vararg pairs: Pair<String,Any>) = json("session" to session).also { o -> pairs.forEach { o.put(it.first,it.second) } }
    private fun rejected(code: Int,block:()->Unit) { try { block(); org.junit.Assert.fail("Expected rejection") } catch(e:ApiError) {assertEquals(e.message,code,e.code)} }
    @Before fun setup() {
        context=RuntimeEnvironment.getApplication();context.deleteDatabase("orders.db");store=OrderStore(context) { digest("test-key:" + it) }
        store.writableDatabase.execSQL("UPDATE pos_settings SET value=? WHERE id='autoCutoff'",arrayOf(json("enabled" to false,"time" to "20:30","nextDay" to "2026-09-01").toString()))
        device=store.pair().getString("device")
        session=op("ownerSetup",json("password" to "owner-password")).getString("session")
        op("saveCashier",owner("id" to "a","name" to "Alex","pin" to "1234"))
        op("saveCashier",owner("id" to "b","name" to "Bea","pin" to "5678"))
    }
    @After fun cleanup(){store.close()}
    private fun start(opening:Long=100000):String = op("startShift",json("cashierId" to "a","pin" to "1234","opening" to opening)).getString("id")
    private fun order():Long = store.submit(device,json("requestId" to "request-${(++requestId).toString().padStart(24,'0')}","items" to JSONArray().put(json("id" to "spanish-latte","quantity" to 1,"modifiers" to JSONArray(),"expectedUnitPrice" to 17000)))).getLong("id")
    private fun args(id:Long,shift:String,beeper:String="1",method:String="cash")=json("id" to id,"shiftId" to shift,"pin" to "1234","beeper" to beeper,"methodId" to method,"tendered" to 20000,"verified" to true)
    private fun review(id:Long,shift:String){op("review",json("id" to id,"shiftId" to shift,"confirmed" to true))}
    @Test fun requiresShiftReviewVerificationAndActiveCashierPin() {
        val id=order()
        rejected(409){op("approve",args(id,"none"))}
        val shift=start()
        rejected(400){op("approve",args(id,shift))}
        review(id,shift)
        rejected(400){op("approve",args(id,shift).put("verified",false))}
        rejected(403){op("approve",args(id,shift).put("pin","5678"))}
        rejected(400){op("approve",args(id,shift).put("tendered",100))}
        rejected(403){store.decide(id,true,"forged","","")}
        assertEquals("awaiting_payment",store.get(id).getString("state"))
        val paid=op("approve",args(id,shift))
        assertEquals("queued",paid.getString("fulfillment"));assertEquals(3000,paid.getInt("change"));assertEquals("Alex",paid.getString("operator"))
    }
    @Test fun cashTransfersCustomMethodsAndClosingShortageAreAccurateAndDurable() {
        op("saveMethod",owner("id" to "bpi","name" to "Monique BPI","cash" to false))
        val shift=start()
        for((index,method) in listOf("cash","gcash","bpi").withIndex()) {val id=order();review(id,shift);op("approve",args(id,shift,(index+1).toString(),method))}
        op("saveMethod",owner("id" to "bpi","name" to "New bank name","cash" to true,"enabled" to false))
        val current=store.operations.state().getJSONObject("activeShift")
        assertEquals(117000,current.getInt("expected"));assertEquals(17000,current.getInt("cashSales"))
        assertTrue(current.getJSONArray("methods").toString().contains("Monique BPI"))
        val closed=op("closeShift",json("shiftId" to shift,"pin" to "1234","closing" to 116500))
        assertEquals(-500,closed.getInt("difference"))
        store.close();store=OrderStore(context) { digest("test-key:" + it) }
        assertTrue(store.operations.state().isNull("activeShift"))
        assertEquals(closed.toString(),store.operations.state().getJSONArray("shifts").getJSONObject(0).toString())
        assertEquals(3,store.history().length())
    }
    @Test fun ownerOnlyToggleOptionalTransactionPinAndMandatoryShiftPin() {
        rejected(403){op("setPinRequired",json("enabled" to false))}
        rejected(403){op("saveMethod",json("name" to "Forged","cash" to true))}
        rejected(403){op("saveCashier",json("name" to "Forged","pin" to "0000"))}
        op("setPinRequired",owner("enabled" to false))
        rejected(400){op("startShift",json("cashierId" to "a","opening" to 0))}
        val shift=start();val id=order();review(id,shift)
        op("approve",args(id,shift).put("pin",""))
        rejected(400){op("closeShift",json("shiftId" to shift,"closing" to 117000))}
        op("closeShift",json("shiftId" to shift,"pin" to "1234","closing" to 118000)).also{assertEquals(1000,it.getInt("difference"))}
    }
    @Test fun pinLockoutPersistsAcrossRestartAndSettingsDoNotExportSecrets() {
        val shift=start();val id=order();review(id,shift)
        repeat(5){rejected(403){op("approve",args(id,shift).put("pin","9999"))}}
        store.close();store=OrderStore(context) { digest("test-key:" + it) }
        rejected(429){op("approve",args(id,shift))}
        val exported=store.operations.state().toString()
        assertFalse(exported.contains("1234"));assertFalse(exported.contains("hash"));assertFalse(exported.contains(session))
    }
    @Test fun beeperCollisionRollsBackPaymentAndCompletionReleasesIt() {
        val shift=start();val first=order();val second=order();review(first,shift);review(second,shift)
        val paid=op("approve",args(first,shift))
        assertEquals(paid.toString(),op("approve",args(first,shift)).toString())
        rejected(409){op("approve",args(second,shift))}
        assertEquals("awaiting_payment",store.get(second).getString("state"))
        store.readableDatabase.rawQuery("SELECT count(*) FROM payments",null).use{it.moveToFirst();assertEquals(1,it.getInt(0))}
        op("complete",json("id" to first));op("complete",json("id" to first))
        op("approve",args(second,shift))
        assertEquals("1",store.get(first).getString("beeper"));assertEquals("completed",store.get(first).getString("fulfillment"))
    }
    @Test fun handoverRequiresClosingAndNewCashierRechecksUnpaidOrders() {
        val shift=start();val id=order();review(id,shift)
        rejected(409){op("startShift",json("cashierId" to "b","pin" to "5678","opening" to 100000))}
        rejected(409){op("saveCashier",owner("id" to "a","name" to "Renamed","pin" to "9876"))}
        op("closeShift",json("shiftId" to shift,"pin" to "1234","closing" to 100000))
        val next=op("startShift",json("cashierId" to "b","pin" to "5678","opening" to 100000)).getString("id")
        rejected(409){op("approve",args(id,shift))}
        rejected(400){op("approve",args(id,next).put("pin","5678"))}
        review(id,next);op("approve",args(id,next).put("pin","5678"))
        assertEquals("Bea",store.get(id).getString("operator"))
    }
    @Test fun cashierTrackingCanBeTemporarilyDisabledWithoutAnActiveShift() {
        rejected(403){op("setCashierTracking",json("enabled" to false))}
        op("setCashierTracking",owner("enabled" to false))
        val state=store.operations.state()
        assertFalse(state.getBoolean("requirePin"));assertFalse(state.getBoolean("cashierTracking"))
        val operator=state.getJSONObject("transactionOperator").getString("id")
        val id=order();review(id,operator)
        val paid=op("approve",args(id,operator).put("pin",""))
        assertEquals("POS operator",paid.getString("operator"));assertFalse(paid.getBoolean("pinRequired"))
        assertEquals(0,store.operations.state().getJSONArray("shifts").length())
        op("setCashierTracking",owner("enabled" to true))
        rejected(409){op("approve",args(order(),operator).put("pin",""))}
    }
    @Test fun unassignedCashPaymentsStillBalanceAnAlreadyOpenLockboxShift() {
        val shift=start()
        op("setCashierTracking",owner("enabled" to false))
        val operator=store.operations.state().getJSONObject("transactionOperator").getString("id")
        val id=order();review(id,operator);op("approve",args(id,operator).put("pin",""))
        assertEquals(shift,store.get(id).getString("shiftId"))
        assertEquals(117000,store.operations.state().getJSONObject("activeShift").getInt("expected"))
        store.close();store=OrderStore(context) { digest("test-key:" + it) }
        assertFalse(store.operations.state().getBoolean("cashierTracking"))
        val closed=op("closeShift",json("shiftId" to shift,"pin" to "1234","closing" to 117000))
        assertEquals(0,closed.getInt("difference"))
    }
    @Test fun versionOneMigrationPreservesPaidHistoryWithoutInventingShift() {
        store.close();context.deleteDatabase("orders.db")
        val legacy=SQLiteDatabase.openOrCreateDatabase(context.getDatabasePath("orders.db"),null)
        legacy.execSQL("CREATE TABLE devices (id TEXT PRIMARY KEY,secret TEXT UNIQUE NOT NULL)")
        legacy.execSQL("CREATE TABLE orders (id INTEGER PRIMARY KEY AUTOINCREMENT,device TEXT NOT NULL,request TEXT NOT NULL,body TEXT NOT NULL,snapshot TEXT NOT NULL,UNIQUE(device,request))")
        legacy.execSQL("CREATE TABLE payments (order_id INTEGER PRIMARY KEY,operator TEXT NOT NULL,approved_at INTEGER NOT NULL,reference TEXT)")
        val snapshot=json("id" to 7,"number" to "OOB-000007","state" to "paid","total" to 17000,"operator" to "Old cashier")
        legacy.execSQL("INSERT INTO devices VALUES('old','secret')")
        legacy.execSQL("INSERT INTO orders VALUES(7,'old','old-request','{}',?)",arrayOf(snapshot.toString()))
        legacy.execSQL("INSERT INTO payments VALUES(7,'Old cashier',1,'old-reference')")
        legacy.version=1;legacy.close();store=OrderStore(context) { digest("test-key:" + it) }
        assertEquals(snapshot.toString(),store.get(7).toString())
        assertEquals(0,store.operations.state().getJSONArray("shifts").length())
        assertFalse(store.operations.state().getBoolean("ownerConfigured"))
        store.readableDatabase.rawQuery("SELECT reference FROM payments WHERE order_id=7",null).use{it.moveToFirst();assertEquals("old-reference",it.getString(0))}
    }
}
