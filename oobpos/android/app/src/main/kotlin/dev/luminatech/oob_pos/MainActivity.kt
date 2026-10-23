package dev.luminatech.oob_pos

import android.app.Activity
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private lateinit var store: OrderStore
    private var exportResult: MethodChannel.Result? = null
    private val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        store = OrderStore(this)
        store.operations.initializeOwnerPassword()
        store.reports.transaction { store.reports.append("POS_INTERFACE_STARTED") }
        MethodChannel(engine.dartExecutor.binaryMessenger,"oob/pos").setMethodCallHandler { call,result ->
            try {
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this,OrderService::class.java)
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        result.success(null)
                    }
                    "stop" -> { stopService(Intent(this,OrderService::class.java)); result.success(null) }
                    "status" -> result.success((OrderService.running?.status() ?: JSONObject().put("running",false).put("error",OrderService.lastError)).toString())
                    "code" -> result.success((OrderService.running?.newCode() ?: throw ApiError(400,"Start the service first")).toString())
                    "history", "decide", "revoke", "operations", "cashier", "reports", "printDocument" -> executor.execute {
                        try {
                            store.reports.runCutoff()
                            val value = when (call.method) {
                                "reports" -> {
                                    val args=JSONObject(call.arguments as String)
                                    val value=when(args.getString("operation")) {
                                        "state" -> store.reports.state()
                                        "summary" -> store.reports.summary(args.getString("kind"),args.getString("day"))
                                        "save" -> {
                                            if(args.getString("kind")=="Z") store.operations.owner(args)
                                            store.reports.save(args.getString("kind"),args.getString("day"),args.getString("requestId"))
                                        }
                                        "cutoff" -> store.reports.configureCutoff(args)
                                        "profile" -> {store.operations.owner(args);store.reports.saveProfile(args)}
                                        else -> fail("Unknown reporting operation")
                                    }
                                    value.toString()
                                }
                                "printDocument" -> {
                                    val args=JSONObject(call.arguments as String)
                                    val document=store.reports.printRecord(args.getString("type"),args.getLong("id"))
                                    runOnUiThread {
                                        try {ReportPrinter.print(this,document);result.success("Print request recorded. Choose a printer or Save as PDF.")}
                                        catch(e:Exception) {result.error("PRINT",e.message,null)}
                                    }
                                    return@execute
                                }
                                "history" -> store.history().toString()
                                "operations" -> store.operations.state().toString()
                                "cashier" -> {
                                    val args = JSONObject(call.arguments as String)
                                    store.operations.execute(args.getString("operation"), args).toString()
                                }
                                "revoke" -> { store.revoke(); null }
                                else -> {
                                    val args = JSONObject(call.arguments as String)
                                    store.decide(args.getLong("id"),args.getBoolean("paid"),args.getString("operator"),args.optString("reason"),args.optString("reference")).toString()
                                }
                            }
                            runOnUiThread { result.success(value) }
                        } catch(e: Exception) { runOnUiThread { result.error("POS",e.message,null) } }
                    }
                    "export" -> {
                        if (exportResult != null) throw ApiError(409,"Export already open")
                        exportResult = result
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE); type="application/json"; putExtra(Intent.EXTRA_TITLE,"oob-orders-${System.currentTimeMillis()}.json")
                        },71)
                    }
                    else -> result.notImplemented()
                }
            } catch(e: Exception) { result.error("POS",e.message,null) }
        }
    }
    @Deprecated("Android activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if (requestCode == 71) {
            val result = exportResult; exportResult = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) { result?.success("Export cancelled"); return }
            val uri = data.data!!
            executor.execute {
                try {
                    val db=store.writableDatabase
                    db.beginTransaction()
                    val snapshot = try {
                        JSONObject().put("schemaVersion",3).put("exportedAt",System.currentTimeMillis()).put("orders",store.history()).put("operations",store.operations.state()).put("reporting",store.reports.export()).also { db.setTransactionSuccessful() }
                    } finally { db.endTransaction() }
                    val stream = contentResolver.openOutputStream(uri,"wt") ?: throw IllegalStateException("Cannot open export file")
                    stream.bufferedWriter().use { it.write(snapshot.toString(2)) }
                    runOnUiThread { result?.success("Order history exported") }
                } catch(e: Exception) { runOnUiThread { result?.error("EXPORT",e.message,null) } }
            }
        }
    }
}
