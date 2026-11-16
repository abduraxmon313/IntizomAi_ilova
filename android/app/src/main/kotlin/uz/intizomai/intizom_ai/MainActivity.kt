package uz.intizomai.intizom_ai

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Eslatmalar ilova yopiq bo'lsa va telefon qayta yoqilganda ham kelishi uchun
 * kerakli tizim sozlamalarini ochadi (Dart: lib/services/device_settings.dart).
 *
 *  - Batareya optimizatsiyasidan ozod qilish (tizim oynasi).
 *  - Ishlab chiqaruvchi "Autostart" sahifasi (Xiaomi, Oppo, Vivo, Huawei,
 *    Tecno/Infinix, Samsung...). Usiz bunday telefonlar qayta yoqilganda
 *    ilovaga BOOT_COMPLETED yubormaydi va eslatmalar tiklanmaydi.
 *  - Xiaomi "Batareya tejash" (MIUI/HyperOS'ning o'z cheklovi).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "manufacturer" -> result.success(Build.MANUFACTURER.lowercase())
                "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBattery())
                "requestIgnoreBatteryOptimizations" -> result.success(requestIgnoreBattery())
                "openAutostart" -> result.success(openFirst(autostartIntents()))
                "openOemBattery" -> result.success(openFirst(oemBatteryIntents()))
                "openAppSettings" -> result.success(openFirst(listOf(appDetails())))
                else -> result.notImplemented()
            }
        }
    }

    private fun isIgnoringBattery(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /** Tizim oynasi: "Ilova fonda doim ishlashiga ruxsat berilsinmi?" */
    private fun requestIgnoreBattery(): String {
        if (isIgnoringBattery()) return "granted"
        return openFirst(
            listOf(
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")),
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                appDetails(),
            ),
        )
    }

    private fun appDetails() =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))

    private fun cmp(pkg: String, cls: String) = Intent().setComponent(ComponentName(pkg, cls))

    private val maker get() = Build.MANUFACTURER.lowercase()

    private fun isXiaomi() = maker.contains("xiaomi") || maker.contains("redmi") || maker.contains("poco")

    private fun autostartIntents(): List<Intent> {
        val m = maker
        val list = mutableListOf<Intent>()
        when {
            isXiaomi() -> {
                list += cmp("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                list += Intent("miui.intent.action.OP_AUTO_START").addCategory(Intent.CATEGORY_DEFAULT)
            }
            m.contains("huawei") || m.contains("honor") -> {
                list += cmp("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                list += cmp("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")
                list += cmp("com.hihonor.systemmanager", "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
            }
            m.contains("oppo") || m.contains("realme") || m.contains("oneplus") -> {
                list += cmp("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                list += cmp("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")
                list += cmp("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")
                list += cmp("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")
            }
            m.contains("vivo") || m.contains("iqoo") -> {
                list += cmp("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                list += cmp("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")
                list += cmp("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")
            }
            m.contains("samsung") -> {
                list += cmp("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity")
                list += cmp("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")
            }
            m.contains("asus") -> {
                list += cmp("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity")
            }
            m.contains("tecno") || m.contains("infinix") || m.contains("itel") || m.contains("transsion") -> {
                list += cmp("com.transsion.phonemaster", "com.cyin.himgr.autostart.AutoStartActivity")
            }
        }
        return list
    }

    private fun oemBatteryIntents(): List<Intent> {
        if (!isXiaomi()) return emptyList()
        val label = applicationInfo.loadLabel(packageManager).toString()
        return listOf(
            cmp("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
                .putExtra("package_name", packageName)
                .putExtra("package_label", label),
        )
    }

    /**
     * Ro'yxatdagi birinchi ochiladigan sahifani ochadi.
     * Natija: "oem" — maxsus sahifa ochildi, "app" — ilova sozlamalari
     * ochildi (zaxira), "none" — hech biri ochilmadi.
     * Boshqa ilovalar komponentlari eksport qilinmagan bo'lishi mumkin —
     * shuning uchun har birini try/catch bilan sinaymiz.
     */
    private fun openFirst(intents: List<Intent>): String {
        for (intent in intents) {
            try {
                startActivity(intent)
                return "oem"
            } catch (_: Exception) {
            }
        }
        return try {
            startActivity(appDetails())
            "app"
        } catch (_: Exception) {
            "none"
        }
    }

    companion object {
        private const val CHANNEL = "uz.intizomai/system"
    }
}
