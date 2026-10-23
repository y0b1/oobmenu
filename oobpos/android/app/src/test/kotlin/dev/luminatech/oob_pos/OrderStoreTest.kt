package dev.luminatech.oob_pos

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import org.junit.*
import org.junit.Assert.*
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class OrderStoreTest {
    private lateinit var context: Context
    private lateinit var store: OrderStore
    private lateinit var device: String
    @Before fun setup() {
        context = RuntimeEnvironment.getApplication()
        context.deleteDatabase("orders.db")
        context.getSharedPreferences("setup",Context.MODE_PRIVATE).edit().clear().commit()
        store = OrderStore(context) { digest("test-key:" + it) }
        store.writableDatabase.execSQL("UPDATE pos_settings SET value=? WHERE id='autoCutoff'",arrayOf(JSONObject().put("enabled",false).put("time","20:30").put("nextDay","2026-09-01").toString()))
        val pair = store.pair()
        device = store.authenticate(pair.getString("credential"))
    }
    @After fun cleanup() { store.close() }
    private fun request() = JSONObject().put("requestId","request-00000000000000000001").put("items",JSONArray().put(JSONObject().put("id","spanish-latte").put("quantity",2).put("expectedUnitPrice",22000).put("modifiers",JSONArray().put("extra-shot")).put("notes","Less ice")))
    private fun rejected(code: Int, block: () -> Unit) {
        try { block(); fail("Expected rejection") } catch (e: ApiError) { assertEquals(code,e.code) }
    }
    @Test fun customerPaymentChoiceIsValidatedSavedAndIdempotent() {
        val request=request().put("paymentChoice","qr")
        val order=store.submit(device,request)
        assertEquals("qr",order.getString("paymentChoice"))
        assertEquals("awaiting_payment",order.getString("state"))
        store.close(); store=OrderStore(context) { digest("test-key:" + it) }
        assertEquals("qr",store.get(order.getLong("id"),device).getString("paymentChoice"))
        assertEquals(order.getLong("id"),store.submit(device,request).getLong("id"))
        rejected(409) {store.submit(device,JSONObject(request.toString()).put("paymentChoice","cash"))}
        rejected(400) {store.submit(device,request().put("requestId","request-00000000000000000002").put("paymentChoice","paid"))}
        val cash=store.submit(device,request().put("requestId","request-00000000000000000003").put("paymentChoice","cash"))
        assertEquals("cash",cash.getString("paymentChoice"))
    }
    @Test fun retryReturnsSameSavedOrderAndSnapshot() {
        val first = store.submit(device,request())
        val retry = store.submit(device,JSONObject(request().toString()))
        assertEquals(first.toString(),retry.toString())
        assertEquals(1,store.history().length())
        assertEquals(44000,first.getInt("total"))
        assertEquals("Spanish Latte",first.getJSONArray("items").getJSONObject(0).getString("name"))
        assertEquals("Less ice",first.getJSONArray("items").getJSONObject(0).getString("notes"))
    }
    @Test fun changedBodyCannotReuseRequestId() {
        store.submit(device,request())
        val altered = request(); altered.getJSONArray("items").getJSONObject(0).put("quantity",3)
        rejected(409) { store.submit(device,altered) }
        assertEquals(1,store.history().length())
    }
    private fun setupShift(): String {
        val ops=store.operations
        val session=ops.execute("ownerSetup",JSONObject().put("password","owner-password")).getString("session")
        ops.execute("saveCashier",JSONObject().put("session",session).put("id","cashier-a").put("name","Cashier A").put("pin","1234"))
        return ops.execute("startShift",JSONObject().put("cashierId","cashier-a").put("pin","1234").put("opening",10000)).getString("id")
    }
    private fun payment(id: Long,shift: String): JSONObject = JSONObject().put("id",id).put("shiftId",shift).put("pin","1234").put("methodId","gcash").put("beeper","1").put("verified",true).put("reference","ref-1")
    @Test fun approvalSurvivesRestartAndRepeatedApprovalIsIdempotent() {
        val order = store.submit(device,request())
        val id = order.getLong("id")
        val shift=setupShift()
        store.operations.execute("review",JSONObject().put("id",id).put("shiftId",shift).put("confirmed",true))
        val paid = store.operations.execute("approve",payment(id,shift))
        val again = store.operations.execute("approve",payment(id,shift).put("reference","ref-2"))
        assertEquals(paid.toString(),again.toString())
        store.close(); store = OrderStore(context) { digest("test-key:" + it) }
        assertEquals("paid",store.get(id,device).getString("state"))
        assertEquals("Cashier A",store.get(id,device).getString("operator"))
        store.readableDatabase.rawQuery("SELECT count(*) FROM payments",null).use { it.moveToFirst(); assertEquals(1,it.getInt(0)) }
        // A lost original acknowledgement resolves to the current paid state.
        assertEquals("paid",store.submit(device,request()).getString("state"))
    }
    @Test fun ordersAreDeviceScopedAndCredentialsCanBeRevoked() {
        val id = store.submit(device,request()).getLong("id")
        val another = store.pair()
        val otherDevice = store.authenticate(another.getString("credential"))
        rejected(404) { store.get(id,otherDevice) }
        rejected(401) { store.authenticate("fake-secret") }
        store.revoke()
        rejected(401) { store.authenticate(another.getString("credential")) }
    }
    @Test fun cancellationCannotBeApprovedAndPaidCannotBeCancelled() {
        val id = store.submit(device,request()).getLong("id")
        val shift=setupShift()
        store.operations.execute("cancel",payment(id,shift).put("reason","Customer changed mind"))
        rejected(409) { store.operations.execute("approve",payment(id,shift)) }
        assertEquals("cancelled",store.get(id).getString("state"))
    }
    @Test fun rejectsUnknownProductsBadQuantitiesPricesAndModifiers() {
        fun invalid(change: (JSONObject) -> Unit, code: Int = 400) {
            val request = request(); change(request.getJSONArray("items").getJSONObject(0))
            rejected(code) { store.submit(device,request) }
            assertEquals(0,store.history().length())
        }
        invalid({ it.put("id","invented") })
        invalid({ it.put("quantity",0) })
        invalid({ it.put("quantity",1.5) })
        invalid({ it.put("quantity",100) })
        invalid({ it.put("expectedUnitPrice",1) },409)
        invalid({ it.put("modifiers",JSONArray().put("free-drink")) })
        invalid({ it.put("modifiers",JSONArray().put("extra-shot").put("extra-shot")) })
        invalid({ it.put("notes","x".repeat(501)) })
    }
    @Test fun concurrentDuplicateSubmissionsProduceOneOrder() {
        val pool = java.util.concurrent.Executors.newFixedThreadPool(6)
        try {
            val futures = (1..12).map { pool.submit<Long> { store.submit(device,request()).getLong("id") } }
            assertEquals(1,futures.map { it.get() }.distinct().size)
            assertEquals(1,store.history().length())
        } finally { pool.shutdownNow() }
    }
    private fun service(): OrderService {
        val service = org.robolectric.Robolectric.buildService(OrderService::class.java).get()
        OrderService::class.java.getDeclaredField("store").apply { isAccessible = true }.set(service,store)
        return service
    }
    private fun route(service: OrderService, method: String, path: String, credential: String, body: JSONObject = JSONObject()): JSONObject {
        val route = OrderService::class.java.getDeclaredMethod("route",String::class.java,String::class.java,String::class.java,JSONObject::class.java).apply { isAccessible = true }
        try { return route.invoke(service,method,path,"Bearer $credential",body) as JSONObject }
        catch (e: java.lang.reflect.InvocationTargetException) { throw e.cause!! }
    }
    @Test fun networkClientsCannotApproveOrReadHistory() {
        val service = service()
        val credential = store.pair().getString("credential")
        for (path in listOf("/v1/approve","/v1/decide","/v1/history","/v1/orders/1/approve","/v1/cashier","/v1/ownerSetup","/v1/setPinRequired","/v1/startShift","/v1/operations")) {
            rejected(403) { route(service,"POST",path,credential) }
        }
        rejected(403) { route(service,"GET","/v1/orders",credential) }
        assertEquals(0,store.history().length())
    }
    @Test fun customerCancellationIsOwnedDurableAndIdempotent() {
        val credential = store.pair().getString("credential")
        val owner = store.authenticate(credential)
        val id = store.submit(owner,request()).getLong("id")
        rejected(404) { store.cancelFromMenu(id,device) }
        val cancelled = route(service(),"POST","/v1/orders/$id/cancel",credential)
        assertEquals("cancelled",cancelled.getString("state"))
        assertEquals(cancelled.toString(),store.cancelFromMenu(id,owner).toString())
        store.close(); store=OrderStore(context) { digest("test-key:" + it) }
        assertEquals("cancelled",store.get(id,owner).getString("state"))
        assertEquals(1,store.history().length())
    }
    @Test fun customerCannotCancelAnApprovedPayment() {
        val id=store.submit(device,request()).getLong("id")
        val shift=setupShift()
        store.operations.execute("review",JSONObject().put("id",id).put("shiftId",shift).put("confirmed",true))
        store.operations.execute("approve",payment(id,shift))
        rejected(409) { store.cancelFromMenu(id,device) }
        assertEquals("paid",store.get(id,device).getString("state"))
    }
    @Test fun pairingCodeIsSingleUseExpiresAndRateLimitSurvivesRestart() {
        val service = service()
        val code = service.newCode().getString("code")
        val paired = route(service,"POST","/v1/pair","",JSONObject().put("code",code))
        assertTrue(paired.getString("credential").length >= 64)
        rejected(403) { route(service,"POST","/v1/pair","",JSONObject().put("code",code)) }
        service.newCode()
        OrderService::class.java.getDeclaredField("codeUntil").apply { isAccessible = true }.setLong(service,0)
        rejected(403) { route(service,"POST","/v1/pair","",JSONObject().put("code",code)) }
        repeat(3) { rejected(403) { route(service,"POST","/v1/pair","",JSONObject().put("code","invalid")) } }
        rejected(429) { service().newCode() }
    }

}
