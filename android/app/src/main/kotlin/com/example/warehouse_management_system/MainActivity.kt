package com.example.warehouse_management_system

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val scannerAction = "com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED"
    private val scannerChannel = "com.mywms/scanner/events"
    private var scannerReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, scannerChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerScannerReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterScannerReceiver()
                    eventSink = null
                }
            })
    }

    private fun registerScannerReceiver() {
        if (scannerReceiver != null) return

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != scannerAction) return

                val barcode = intent.getStringExtra("data")?.trim().orEmpty()
                if (barcode.isEmpty()) return

                val rawBytes = intent.getByteArrayExtra("source_byte")
                    ?.map { byte -> byte.toInt() and 0xFF }

                eventSink?.success(
                    mapOf(
                        "barcode" to barcode,
                        "rawBytes" to rawBytes
                    )
                )
            }
        }

        val filter = IntentFilter(scannerAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        scannerReceiver = receiver
    }

    private fun unregisterScannerReceiver() {
        scannerReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
                // Receiver was already unregistered by Android.
            }
        }
        scannerReceiver = null
    }

    override fun onDestroy() {
        unregisterScannerReceiver()
        super.onDestroy()
    }
}
