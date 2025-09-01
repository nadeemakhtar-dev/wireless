package com.nadeemakhtar.wireless

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.ParcelUuid
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val CHANNEL_BOND = "ble/bond"
    private val CHANNEL_PERIPHERAL = "ble_peripheral"
    private val CHANNEL = "com.nadeemakhtar.wireless/control"

    private var advertiser: BluetoothLeAdvertiser? = null
    private var callback: AdvertiseCallback? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = manager.adapter

        advertiser = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            adapter?.bluetoothLeAdvertiser
        } else null



        // -------- Peripheral / Advertising channel --------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_PERIPHERAL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAdvertisingSupported" -> {
                        val supported =
                            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) &&
                                    (adapter?.isEnabled == true) &&
                                    (advertiser != null) &&
                                    (adapter?.isMultipleAdvertisementSupported == true)

                        result.success(supported)
                    }

                    "start" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val ok = checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED
                            if (!ok) {
                                result.error("PERMISSION", "BLUETOOTH_ADVERTISE not granted on Android 12+.", null)
                                return@setMethodCallHandler
                            }
                        }

                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
                            result.error("API", "BLE advertising requires API 21+.", null)
                            return@setMethodCallHandler
                        }

                        val adv = advertiser
                        if (adv == null) {
                            result.error("NO_ADVERTISER", "BLE advertiser not available.", null)
                            return@setMethodCallHandler
                        }

                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as? Map<String, Any?>
                                ?: run { result.error("ARGS", "Invalid arguments", null); return@setMethodCallHandler }

                            val localName = args["localName"] as String?
                            val serviceUuid = (args["serviceUuid"] as String?)?.let { ParcelUuid(UUID.fromString(it)) }
                            val connectable = (args["connectable"] as? Boolean) ?: true
                            val includeName = (args["includeDeviceName"] as? Boolean) ?: true
                            val tx = (args["txPower"] as? Int) ?: 2

                            // Manufacturer data — expect ByteArray from Dart Uint8List
                            val mId = (args["manufacturerId"] as? Number)?.toInt()
                            val mAny = args["manufacturerData"]
                            val mData: ByteArray? = when (mAny) {
                                is ByteArray -> mAny
                                is List<*> -> mAny.filterIsInstance<Number>().map { it.toInt().toByte() }.toByteArray()
                                null -> null
                                else -> null
                            }

                            val settings = AdvertiseSettings.Builder()
                                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                                .setTxPowerLevel(
                                    when (tx) {
                                        0 -> AdvertiseSettings.ADVERTISE_TX_POWER_ULTRA_LOW
                                        1 -> AdvertiseSettings.ADVERTISE_TX_POWER_LOW
                                        2 -> AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM
                                        else -> AdvertiseSettings.ADVERTISE_TX_POWER_HIGH
                                    }
                                )
                                .setConnectable(connectable)
                                .build()

                            // Build primary advertising data (keep it small)
                            val dataBuilder = AdvertiseData.Builder()
                                .setIncludeDeviceName(includeName)

                            if (serviceUuid != null) dataBuilder.addServiceUuid(serviceUuid)
                            val advertiseData = dataBuilder.build()

// Put manufacturer data into the scan response instead
                            val scanResponseBuilder = AdvertiseData.Builder()
                            if (mId != null && mData != null && mData.isNotEmpty()) {
                                scanResponseBuilder.addManufacturerData(mId, mData)
                            }
                            val scanResponse = scanResponseBuilder.build()

// Start
                            callback = object : AdvertiseCallback() {
                                override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) { result.success(true) }
                                override fun onStartFailure(errorCode: Int) { result.error("START_FAIL", "Code: $errorCode", null) }
                            }
                            adv.startAdvertising(settings, advertiseData, scanResponse, callback)

                        } catch (e: Exception) {
                            result.error("START_ERR", e.message, null)
                        }
                    }

                    "stop" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                callback?.let { advertiser?.stopAdvertising(it) }
                                callback = null
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("STOP_ERR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // -------- Bonding channel --------
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_BOND)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBondState" -> {
                        val id = call.argument<String>("deviceId")
                        if (id.isNullOrBlank()) {
                            result.error("ARG", "deviceId required", null)
                            return@setMethodCallHandler
                        }
                        val dev = try { adapter.getRemoteDevice(id) } catch (_: IllegalArgumentException) { null }
                        if (dev == null) {
                            result.error("DEV", "Invalid deviceId", null)
                            return@setMethodCallHandler
                        }
                        result.success(dev.bondState) // 10 (NONE), 11 (BONDING), 12 (BONDED)
                    }

                    "createBond" -> {
                        val id = call.argument<String>("deviceId")
                        if (id.isNullOrBlank()) {
                            result.error("ARG", "deviceId required", null)
                            return@setMethodCallHandler
                        }
                        val dev = try { adapter.getRemoteDevice(id) } catch (_: IllegalArgumentException) { null }
                        if (dev == null) {
                            result.error("DEV", "Invalid deviceId", null)
                            return@setMethodCallHandler
                        }
                        val ok = dev.createBond()
                        result.success(ok)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
