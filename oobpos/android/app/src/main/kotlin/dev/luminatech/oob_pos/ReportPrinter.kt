package dev.luminatech.oob_pos

import android.app.Activity
import android.content.Context
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.*
import org.json.JSONObject
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Locale

object ReportPrinter {
    fun money(value: Long): String = "PHP " + String.format(Locale.US, "%d.%02d", value / 100, value % 100)
    private fun time(value: Long): String = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).apply { timeZone = ReportPeriod.zone }.format(java.util.Date(value))
    fun lines(o: JSONObject): List<String> {
        val rows = mutableListOf<String>()
        val business = o.optJSONObject("business") ?: JSONObject()
        for ((key,label) in listOf("businessName" to "Business", "tin" to "TIN", "address" to "Address", "taxStatus" to "VAT status", "serialNumber" to "Machine serial", "ptuNumber" to "PTU", "posModel" to "POS model", "accreditationNumber" to "Accreditation", "minNumber" to "MIN")) rows.add("$label: ${business.optString(key).ifEmpty { "NOT CONFIGURED" }}")
        rows.add("")
        if (o.optString("documentType") == "payment") {
            rows.add("PAYMENT RECORD ${o.getString("number")}")
            rows.add("NOT A TAX INVOICE")
            rows.add("Paid: ${time(o.getLong("approvedAt"))} Asia/Manila")
            rows.add("Cashier: ${o.optString("operator")}")
            if(o.optString("source")=="pos_custom") rows.add("POS custom order")
            val items = o.optJSONArray("items")
            if(items != null) for(i in 0 until items.length()) {
                val line = items.getJSONObject(i)
                rows.add("${line.getInt("quantity")} x ${line.getString("name")} @ ${money(line.getLong("unitPrice"))} = ${money(line.getLong("total"))}")
                val mods = line.optJSONArray("modifiers")
                if(mods != null) for(m in 0 until mods.length()) rows.add("  + ${mods.getJSONObject(m).optString("name")}")
                if(line.optString("notes").isNotEmpty()) rows.add("Notes: ${line.getString("notes")}")
            }
            rows.add("TOTAL: ${money(o.getLong("total"))}")
            rows.add("Payment: ${o.optJSONObject("paymentMethod")?.optString("name") ?: "Legacy / unspecified"}")
            if(o.has("tendered")) rows.add("Tendered: ${money(o.getLong("tendered"))}   Change: ${money(o.getLong("change"))}")
            if(o.optString("reference").isNotEmpty()) rows.add("Reference: ${o.getString("reference")}")
        } else {
            rows.add("${o.getString("kind").uppercase()} SALES REPORT #${o.getLong("id")}")
            rows.add("${o.getString("start")} through ${o.getString("end")} (Asia/Manila)")
            rows.add("Snapshot generated: ${time(o.getLong("generatedAt"))}")
            rows.add("Paid orders: ${o.getInt("count")}")
            for((key,label) in listOf("total" to "Sales", "cashSales" to "Cash sales", "otherSales" to "Other payments", "cancelledAmount" to "Unpaid cancellations (not deducted from sales)", "previousGrandTotal" to "Grand total before period", "periodGrandTotal" to "Grand total through period", "lifetimeGrandTotal" to "Lifetime grand total at generation")) rows.add("$label: ${money(o.getLong(key))}")
            rows.add("Cancelled unpaid orders: ${o.getInt("cancelledCount")}")
            rows.add("Order range by payment time: ${o.optString("firstOrder")} - ${o.optString("lastOrder")}")
            for(key in listOf("methods", "cashiers", "days")) {
                rows.add(""); rows.add(key.uppercase())
                val group=o.getJSONArray(key)
                for(i in 0 until group.length()) { val row=group.getJSONObject(i);rows.add("${row.getString("name")}: ${row.getInt("count")} orders, ${money(row.getLong("total"))}") }
            }
            rows.add(""); rows.add("Operational report; BIR accreditation and statutory format review pending.")
            rows.add("Tax/discount/refund breakdowns are not implemented in this version.")
        }
        rows.add("")
        rows.add(if(o.getInt("printAttempt")>1) "REPRINT REQUEST #${o.getInt("printAttempt")}" else "ORIGINAL PRINT REQUEST")
        rows.add("Requested: ${time(o.getLong("printedAt"))} Asia/Manila")
        rows.add("OOB POS / Lumina Tech")
        return rows
    }
    fun print(activity: Activity, document: JSONObject) {
        val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize=11f }
        val wrapped=mutableListOf<String>()
        for(line in lines(document)) {
            var rest=line
            if(rest.isEmpty()) wrapped.add("")
            while(rest.isNotEmpty()) {
                val count=paint.breakText(rest,true,499f,null).coerceAtLeast(1)
                wrapped.add(rest.take(count));rest=rest.drop(count)
            }
        }
        val pages=wrapped.chunked(45)
        val manager=activity.getSystemService(Context.PRINT_SERVICE) as PrintManager
        manager.print("OOB-${document.optString("number",document.optString("kind"))}", object: PrintDocumentAdapter() {
            override fun onLayout(old: PrintAttributes?, attributes: PrintAttributes, signal: CancellationSignal, callback: LayoutResultCallback, extras: Bundle?) {
                if(signal.isCanceled) {callback.onLayoutCancelled();return}
                callback.onLayoutFinished(PrintDocumentInfo.Builder("OOB-report.pdf").setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT).setPageCount(pages.size).build(),true)
            }
            override fun onWrite(ranges: Array<out PageRange>, destination: ParcelFileDescriptor, signal: CancellationSignal, callback: WriteResultCallback) {
                val pdf=PdfDocument()
                try {
                    for((index,lines) in pages.withIndex()) {
                        if(signal.isCanceled) {callback.onWriteCancelled();return}
                        if(!ranges.any { index in it.start..it.end }) continue
                        val page=pdf.startPage(PdfDocument.PageInfo.Builder(595,842,index+1).create())
                        lines.forEachIndexed { n,line -> page.canvas.drawText(line,48f,55f+n*16,paint) }
                        page.canvas.drawText("Page ${index+1} / ${pages.size}",48f,805f,paint)
                        pdf.finishPage(page)
                    }
                    FileOutputStream(destination.fileDescriptor).use { pdf.writeTo(it) }
                    callback.onWriteFinished(ranges)
                } catch(e:Exception) {callback.onWriteFailed(e.message)} finally {pdf.close()}
            }
        },PrintAttributes.Builder().setMediaSize(PrintAttributes.MediaSize.ISO_A4).setColorMode(PrintAttributes.COLOR_MODE_MONOCHROME).build())
    }
}
