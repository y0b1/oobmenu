package dev.luminatech.oob_pos

import android.content.Context
import android.database.sqlite.SQLiteException
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
class ReportsTest {
    private lateinit var context: Context
    private lateinit var store: OrderStore
    private lateinit var device: String
    private fun json(vararg pairs:Pair<String,Any>)=JSONObject().also{ o->pairs.forEach{o.put(it.first,it.second)} }
    private fun open()=OrderStore(context) { digest("test-key:"+it) }
    @Before fun setup(){context=RuntimeEnvironment.getApplication();context.deleteDatabase("orders.db");store=open();store.writableDatabase.execSQL("UPDATE pos_settings SET value=? WHERE id='autoCutoff'",arrayOf(json("enabled" to false,"time" to "20:30","nextDay" to "2026-09-01").toString()));device=store.pair().getString("device")}
    @After fun cleanup(){store.close()}
    private fun rejected(block:()->Unit){try{block();org.junit.Assert.fail("Expected rejection")}catch(_:ApiError){}}
    private fun paid(at:Long, name:String="Cash",cash:Boolean=true):JSONObject {
        val order=store.submit(device,json("requestId" to token(),"items" to JSONArray().put(json("id" to "spanish-latte","quantity" to 1,"modifiers" to JSONArray(),"expectedUnitPrice" to 17000))))
        order.put("state","paid").put("operator","Alex").put("cashierId","a").put("decisionAt",at).put("tendered",20000).put("change",3000).put("paymentMethod",json("id" to "method","name" to name,"cash" to cash))
        store.reports.transaction {
            store.writableDatabase.execSQL("UPDATE orders SET snapshot=? WHERE id=?",arrayOf<Any>(order.toString(),order.getLong("id")))
            store.writableDatabase.execSQL("INSERT INTO payments VALUES(?,?,?,?)",arrayOf<Any>(order.getLong("id"),"Alex",at,""))
            store.reports.recordSale(order,at)
        }
        return order
    }
    @Test fun defaultOwnerPasswordIsChangeableAndNeverResetsOnRestart() {
        store.operations.initializeOwnerPassword()
        val session=store.operations.execute("ownerLogin",json("password" to "oob12345")).getString("session")
        store.operations.execute("changeOwnerPassword",json("session" to session,"password" to "new-owner-password"))
        store.close();store=open();store.operations.initializeOwnerPassword()
        rejected { store.operations.execute("ownerLogin",json("password" to "oob12345")) }
        assertTrue(store.operations.execute("ownerLogin",json("password" to "new-owner-password")).has("session"))
    }
    @Test fun automaticCutoffDefaultsTo2030AndRequiresOwnerToChange() {
        store.writableDatabase.execSQL("DELETE FROM pos_settings WHERE id='autoCutoff'")
        assertEquals("20:30",store.reports.cutoff().getString("time"))
        assertTrue(store.reports.cutoff().getBoolean("enabled"))
        rejected { store.reports.configureCutoff(json("enabled" to false,"time" to "21:00")) }
        val session=store.operations.execute("ownerSetup",json("password" to "owner-password")).getString("session")
        rejected { store.reports.configureCutoff(json("session" to session,"enabled" to true,"time" to "25:00")) }
        store.reports.configureCutoff(json("session" to session,"enabled" to false,"time" to "21:00"))
        store.close();store=open()
        assertFalse(store.reports.cutoff().getBoolean("enabled"))
        assertEquals("21:00",store.reports.cutoff().getString("time"))
    }
    @Test fun ownerCanPauseSalesDayForTestingWithoutChangingSavedReports() {
        val start=ReportPeriod.bounds("daily","2026-09-01").first
        val z=store.reports.save("Z","2026-09-01",token(),start+1)
        rejected { store.reports.assertOpen(start+2) }
        rejected { store.reports.configureCutoff(json("enabled" to true,"time" to "20:30","enforceSalesDay" to false),start) }
        val session=store.operations.execute("ownerSetup",json("password" to "owner-password")).getString("session")
        val args=json("session" to session,"enabled" to true,"time" to "20:30","enforceSalesDay" to false)
        store.reports.configureCutoff(args,start)
        store.reports.assertOpen(start+2)
        store.reports.runCutoff(start+23*3600000L)
        assertEquals(1,store.reports.list().length())
        assertEquals(z.toString(),store.reports.saved(z.getLong("id")).toString())
        store.reports.configureCutoff(args.put("enforceSalesDay",true),start)
        rejected { store.reports.assertOpen(start+2) }
    }
    @Test fun scheduledCutoffIsExactIdempotentAndCatchesUpAfterRestart() {
        val start=ReportPeriod.bounds("daily","2026-09-01").first
        val deadline=start+(20*60+30)*60000L
        paid(start)
        store.writableDatabase.execSQL("UPDATE pos_settings SET value=? WHERE id='autoCutoff'",arrayOf(json("enabled" to true,"time" to "20:30","nextDay" to "2026-09-01").toString()))
        store.reports.runCutoff(deadline-1)
        assertEquals(0,store.reports.list().length())
        store.reports.assertOpen(deadline-1)
        rejected { store.reports.assertOpen(deadline) }
        store.reports.runCutoff(deadline)
        store.reports.runCutoff(deadline+1)
        assertEquals(1,store.reports.list().length())
        assertEquals(17000,store.reports.list().getJSONObject(0).getInt("total"))
        rejected { store.reports.assertOpen(deadline+1) }
        store.reports.assertOpen(start+86400000L)
        store.close();store=open()
        store.reports.runCutoff(deadline+2*86400000L)
        assertEquals(3,store.reports.list().length())
        assertEquals("2026-09-03",store.reports.lastClosed())
        assertTrue(store.reports.verify().getBoolean("valid"))
        store.reports.runCutoff(deadline+2*86400000L)
        assertEquals(3,store.reports.list().length())
    }
    @Test fun periodsUseManilaMidnightMondayAndCalendarMonth() {
        val day=ReportPeriod.bounds("daily","2026-09-01")
        assertEquals("2026-08-31",ReportPeriod.day(day.first-1));assertEquals("2026-09-01",ReportPeriod.day(day.first))
        val week=ReportPeriod.bounds("weekly","2026-09-06")
        assertEquals("2026-08-31",ReportPeriod.day(week.first));assertEquals("2026-09-06",ReportPeriod.day(week.second-1))
        val month=ReportPeriod.bounds("monthly","2024-02-29")
        assertEquals(29L*86400000,month.second-month.first)
        rejected{ReportPeriod.bounds("daily","2026-02-30")}
    }
    @Test fun summariesCountApprovalsAtBoundariesAndPreserveMethodNames() {
        val (start,end)=ReportPeriod.bounds("daily","2026-09-01")
        paid(start-1);paid(start);paid(start+1,"Monique BPI",false);paid(end,"Renamed bank",false)
        val daily=store.reports.summary("daily","2026-09-01",end+1)
        assertEquals(34000,daily.getInt("total"));assertEquals(2,daily.getInt("count"));assertEquals(17000,daily.getInt("cashSales"))
        assertEquals(17000,daily.getInt("previousGrandTotal"));assertEquals(51000,daily.getInt("periodGrandTotal"));assertEquals(68000,daily.getInt("lifetimeGrandTotal"))
        assertTrue(daily.getJSONArray("methods").toString().contains("Monique BPI"))
        assertEquals(68000,store.reports.summary("weekly","2026-09-01",end+1).getInt("total"))
        assertEquals(51000,store.reports.summary("monthly","2026-09-01",end+1).getInt("total"))
        assertEquals(1,store.reports.summary("daily","2026-09-01",start).getInt("count"))
    }
    @Test fun xIsNonClosingZIsImmutableIdempotentAndSurvivesRestart() {
        val start=ReportPeriod.bounds("daily","2026-09-01").first;paid(start)
        val x=store.reports.save("X","2026-09-01",token(),start+1)
        store.reports.assertOpen(start+2);paid(start+2)
        val request=token();val z=store.reports.save("Z","2026-09-01",request,start+3)
        assertEquals(17000,x.getInt("total"));assertEquals(34000,z.getInt("total"))
        assertEquals(z.getLong("id"),store.reports.save("Z","2026-09-01",request,start+4).getLong("id"))
        assertEquals(z.getLong("id"),store.reports.save("Z","2026-09-01",token(),start+4).getLong("id"))
        rejected{store.reports.assertOpen(start+4)}
        rejected{store.reports.save("Z","2026-08-31",token(),start+4)}
        rejected{store.reports.save("Z","2026-09-02",token(),start+4)}
        store.close();store=open()
        assertEquals(34000L,store.reports.grandTotal());assertEquals(2,store.reports.list().length())
        assertEquals(x.getInt("total"),store.reports.saved(x.getLong("id")).getInt("total"))
        store.reports.assertOpen(ReportPeriod.bounds("daily","2026-09-02").first)
    }
    @Test fun journalAndSalesRejectEditsAndDetectBypassedTriggers() {
        paid(ReportPeriod.bounds("daily","2026-09-01").first)
        try {store.writableDatabase.execSQL("DELETE FROM sales_ledger");org.junit.Assert.fail("Append-only guard missing")} catch(_:SQLiteException) {}
        try {store.writableDatabase.execSQL("UPDATE journal SET body='{}'");org.junit.Assert.fail("Append-only guard missing")} catch(_:SQLiteException) {}
        store.writableDatabase.execSQL("DROP TRIGGER sales_ledger_update")
        store.writableDatabase.execSQL("UPDATE sales_ledger SET amount=1")
        rejected{store.reports.verify()}
    }
    @Test fun journalSignatureCannotBeForged() {
        store.writableDatabase.execSQL("DROP TRIGGER journal_update")
        store.writableDatabase.execSQL("UPDATE journal SET body='{}'")
        rejected{store.reports.verify()}
    }
    @Test fun reportRequestsAndReprintsPreserveOriginalAndTrail() {
        val at=ReportPeriod.bounds("daily","2026-09-01").first;paid(at)
        val report=store.reports.save("monthly","2026-09-01",token(),at+1)
        val first=store.reports.printRecord("report",report.getLong("id"))
        val second=store.reports.printRecord("report",report.getLong("id"))
        assertEquals(1,first.getInt("printAttempt"));assertEquals(2,second.getInt("printAttempt"))
        assertFalse(store.reports.saved(report.getLong("id")).has("printAttempt"))
        assertTrue(ReportPrinter.lines(second).contains("REPRINT REQUEST #2"))
        assertTrue(store.reports.export().getJSONArray("journal").toString().contains("PRINT_REQUESTED"))
        rejected{store.reports.printRecord("payment",1)}
    }
    @Test fun customOrdersStayLocalValidateAndUseNormalPaymentControls() {
        fun op(name:String,args:JSONObject)=store.operations.execute(name,args)
        val session=op("ownerSetup",json("password" to "owner-password")).getString("session")
        op("saveCashier",json("session" to session,"id" to "a","name" to "Alex","pin" to "1234"))
        val shift=op("startShift",json("cashierId" to "a","pin" to "1234","opening" to 0)).getString("id")
        val args=json("requestId" to token(),"shiftId" to shift,"name" to "Private catering item","quantity" to 2,"unitPrice" to 12345,"notes" to "No sugar")
        val custom=op("customOrder",args)
        assertEquals(24690,custom.getInt("total"));assertEquals("pos_custom",custom.getString("source"))
        assertEquals(custom.getLong("id"),op("customOrder",args).getLong("id"))
        rejected{op("customOrder",JSONObject(args.toString()).put("quantity",1))}
        rejected{op("customOrder",JSONObject(args.toString()).put("requestId",token()).put("quantity",0))}
        rejected{store.get(custom.getLong("id"),device)}
        assertFalse(store.catalog.toString().contains("Private catering item"))
        rejected{store.submit(device,json("requestId" to token(),"items" to JSONArray().put(json("id" to "pos-custom","quantity" to 1,"modifiers" to JSONArray(),"expectedUnitPrice" to 12345))))}
        val payment=json("id" to custom.getLong("id"),"shiftId" to shift,"pin" to "1234","beeper" to "1","methodId" to "cash","tendered" to 25000,"verified" to true)
        rejected{op("approve",payment)}
        op("review",json("id" to custom.getLong("id"),"shiftId" to shift,"confirmed" to true))
        val paid=op("approve",payment);op("approve",payment)
        assertEquals(310,paid.getInt("change"));assertEquals(24690L,store.reports.grandTotal())
        assertEquals(1,store.reports.summary("daily",ReportPeriod.day(System.currentTimeMillis())).getInt("count"))
        rejected{store.operations.owner(JSONObject())}
    }
}
