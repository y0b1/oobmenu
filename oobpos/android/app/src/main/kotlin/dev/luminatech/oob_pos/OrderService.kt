package dev.luminatech.oob_pos

import android.app.*
import android.content.*
import android.os.*
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.json.JSONObject
import java.math.BigInteger
import java.net.*
import java.security.*
import java.security.cert.X509Certificate
import java.util.Date
import java.util.concurrent.*
import javax.net.ssl.*
import javax.security.auth.x500.X500Principal

class OrderService : Service() {
    companion object {
        @Volatile var running: OrderService? = null
        @Volatile var lastError = ""
        const val PORT = 8443
    }
    private var socket: SSLServerSocket? = null
    private var workers: ThreadPoolExecutor? = null
    private lateinit var store: OrderStore
    private var cutoffTimer: ScheduledExecutorService? = null
    private var wake: PowerManager.WakeLock? = null
    @Volatile var lastSeen = 0L
    @Volatile var fingerprint = ""
    private var code = ""
    private var codeUntil = 0L
    private val setup by lazy { getSharedPreferences("setup", MODE_PRIVATE) }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel("orders", "Local order service", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this,0,Intent(this,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this,"orders") else Notification.Builder(this)
        startForeground(10,builder.setSmallIcon(android.R.drawable.stat_notify_sync).setContentTitle("OOB POS service").setContentText("Accepting orders over the local hotspot").setContentIntent(open).setOngoing(true).build())
        store = OrderStore(this)
        store.reports.transaction { store.reports.append("LOCAL_SERVICE_STARTED") }
        try {
            val tls = createTls()
            socket = (tls.serverSocketFactory.createServerSocket(PORT,16,InetAddress.getByName("0.0.0.0")) as SSLServerSocket).apply {
                enabledProtocols = supportedProtocols.filter { it == "TLSv1.2" || it == "TLSv1.3" }.toTypedArray()
            }
            workers = ThreadPoolExecutor(4,4,0,TimeUnit.SECONDS,ArrayBlockingQueue(16))
            wake = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,"OOB:orders").apply { acquire() }
            running = this; lastError = ""
            cutoffTimer=Executors.newSingleThreadScheduledExecutor()
            cutoffTimer!!.scheduleWithFixedDelay({
                try { synchronized(store) { store.reports.runCutoff() } }
                catch(e: Exception) { lastError="Automatic cutoff failed: " + e.message; android.util.Log.e("OobPos",lastError,e) }
            },0,15,TimeUnit.SECONDS)
            Thread({
                while (socket?.isClosed == false) {
                    try {
                        val peer = socket!!.accept() as SSLSocket
                        peer.soTimeout = 8000
                        try { workers!!.execute { handle(peer) } } catch (_: RejectedExecutionException) { peer.close() }
                    } catch (_: Exception) { break }
                }
            },"oob-listener").start()
        } catch (e: Exception) { lastError = e.message ?: "Unable to start HTTPS"; stopSelf() }
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY
    override fun onDestroy() {
        running = null
        cutoffTimer?.shutdownNow()
        socket?.close(); workers?.shutdownNow()
        if (wake?.isHeld == true) wake?.release()
        // Workers may still be unwinding; SQLiteOpenHelper lives until process teardown.
        super.onDestroy()
    }
    @Synchronized fun newCode(): JSONObject {
        val now = System.currentTimeMillis()
        val lock = setup.getLong("lockUntil",0)
        if (lock > now) throw ApiError(429,"Pairing locked until " + Date(lock))
        code = (100000 + SecureRandom().nextInt(900000)).toString()
        codeUntil = now + 300000
        return status()
    }
    @Synchronized private fun pair(body: JSONObject): JSONObject {
        val now = System.currentTimeMillis()
        if (setup.getLong("lockUntil",0) > now) throw ApiError(429,"Pairing temporarily locked")
        val attempts = setup.getInt("attempts",0) + 1
        if (code.isEmpty() || now > codeUntil || body.optString("code") != code) {
            setup.edit().putInt("attempts",attempts).apply {
                if (attempts >= 5) { putLong("lockUntil",now+300000); putInt("attempts",0) }
            }.commit()
            throw ApiError(403,"Invalid or expired pairing code")
        }
        val paired = store.pair()
        code = ""; codeUntil = 0
        setup.edit().putInt("attempts",0).commit()
        return paired
    }
    @Synchronized fun status(): JSONObject {
        val addresses = org.json.JSONArray()
        NetworkInterface.getNetworkInterfaces()?.toList()?.filter { it.isUp && !it.isLoopback }?.forEach { iface ->
            iface.inetAddresses.toList().filterIsInstance<Inet4Address>().filter { !it.isLoopbackAddress && !it.isLinkLocalAddress }.forEach {
                addresses.put(JSONObject().put("interface",iface.name).put("address",it.hostAddress))
            }
        }
        return JSONObject().put("running",true).put("addresses",addresses).put("port",PORT).put("fingerprint",fingerprint)
            .put("code",if (System.currentTimeMillis() < codeUntil) code else "").put("codeUntil",codeUntil)
            .put("connected",System.currentTimeMillis()-lastSeen < 10000).put("error",lastError)
    }
    private fun createTls(): SSLContext {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "oob-pos-tls-ec-v1"
        if (!ks.containsAlias(alias)) {
            val gen = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC,"AndroidKeyStore")
            gen.initialize(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(java.security.spec.ECGenParameterSpec("secp256r1"))
                // Conscrypt passes a pre-hashed handshake to NONEwithECDSA.
                // SHA-256 also permits a valid self-signed certificate at creation.
                .setDigests(KeyProperties.DIGEST_NONE,KeyProperties.DIGEST_SHA256)
                .setCertificateSubject(X500Principal("CN=OOB POS"))
                .setCertificateSerialNumber(BigInteger(128,SecureRandom()))
                .setCertificateNotBefore(Date(System.currentTimeMillis()-86400000))
                .setCertificateNotAfter(Date(System.currentTimeMillis()+10L*365*86400000)).build())
            gen.generateKeyPair()
        }
        val cert = ks.getCertificate(alias) as X509Certificate
        fingerprint = MessageDigest.getInstance("SHA-256").digest(cert.encoded).joinToString("") { "%02x".format(it) }
        val manager = object : X509ExtendedKeyManager() {
            override fun getClientAliases(a: String?, b: Array<out Principal>?) = null
            override fun chooseClientAlias(a: Array<out String>?, b: Array<out Principal>?, c: Socket?) = null
            override fun getServerAliases(a: String?, b: Array<out Principal>?) = if (a == "EC") arrayOf(alias) else null
            override fun chooseServerAlias(a: String?, b: Array<out Principal>?, c: Socket?) = if (a == "EC") alias else null
            override fun getCertificateChain(a: String?) = arrayOf(cert)
            override fun getPrivateKey(a: String?) = ks.getKey(alias,null) as PrivateKey
        }
        return SSLContext.getInstance("TLS").apply { init(arrayOf(manager),null,SecureRandom()) }
    }
    private fun handle(peer: SSLSocket) {
        peer.use {
            try {
                peer.startHandshake()
                val input = peer.inputStream.buffered()
                fun line(): String {
                    val bytes = java.io.ByteArrayOutputStream()
                    while (true) {
                        val b = input.read()
                        if (b == -1) throw ApiError(400,"Incomplete request")
                        if (b == 10) break
                        if (bytes.size() >= 4096) throw ApiError(413,"Header too long")
                        if (b != 13) bytes.write(b)
                    }
                    return bytes.toString("US-ASCII")
                }
                val start = line().split(" ")
                if (start.size != 3) throw ApiError(400,"Invalid HTTP request")
                val headers = mutableMapOf<String,String>()
                var bytes = 0
                while (true) {
                    val h = line(); if (h.isEmpty()) break
                    bytes += h.length
                    if (bytes > 16384) throw ApiError(413,"Headers too large")
                    val colon = h.indexOf(':'); if (colon <= 0) throw ApiError(400,"Invalid header")
                    val key = h.substring(0,colon).lowercase()
                    if (headers.containsKey(key)) throw ApiError(400,"Repeated header")
                    headers[key] = h.substring(colon+1).trim()
                }
                if (headers.containsKey("transfer-encoding")) throw ApiError(400,"Use Content-Length")
                val size = headers["content-length"]?.toIntOrNull() ?: 0
                if (size !in 0..65536) throw ApiError(413,"Request too large")
                val data = ByteArray(size); var read = 0
                while (read < size) { val n = input.read(data,read,size-read); if (n < 0) throw ApiError(400,"Incomplete body"); read += n }
                val body = if (size > 0) JSONObject(String(data,Charsets.UTF_8)) else JSONObject()
                val response = route(start[0],start[1],headers["authorization"] ?: "",body)
                send(peer,200,response)
            } catch (e: ApiError) { runCatching { send(peer,e.code,JSONObject().put("error",e.message)) } }
            catch (_: org.json.JSONException) { runCatching { send(peer,400,JSONObject().put("error","Invalid JSON")) } }
            catch (e: Exception) {
                android.util.Log.w("OobPos", "HTTPS connection failed", e)
                runCatching { send(peer,500,JSONObject().put("error","Local service error; retry the same request")) }
            }
        }
    }
    private fun route(method: String, path: String, auth: String, body: JSONObject): JSONObject {
        if (method == "POST" && path == "/v1/pair") return pair(body)
        val device = store.authenticate(auth.removePrefix("Bearer "))
        lastSeen = System.currentTimeMillis()
        if (method == "GET" && path == "/v1/catalog") return store.catalog
        if (method == "POST" && path == "/v1/orders") return store.submit(device,body)
        if (method == "POST" && Regex("/v1/orders/[0-9]+/cancel").matches(path)) return store.cancelFromMenu(path.split("/")[3].toLong(),device)
        if (method == "GET" && Regex("/v1/orders/[0-9]+").matches(path)) return store.get(path.substringAfterLast('/').toLong(),device)
        throw ApiError(403,"This client has no permission for this operation")
    }
    private fun send(peer: SSLSocket, status: Int, body: JSONObject) {
        val data = body.toString().toByteArray(Charsets.UTF_8)
        val out = peer.outputStream
        out.write("HTTP/1.1 $status Result\r\nContent-Type: application/json\r\nContent-Length: ${data.size}\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n".toByteArray(Charsets.US_ASCII))
        out.write(data); out.flush()
    }
}
