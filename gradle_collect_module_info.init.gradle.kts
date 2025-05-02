import groovy.json.JsonOutput
import java.io.File

// ---------- 1. 結果格納用 ----------
val result = mutableMapOf<String, Any>(
    "rootDir" to "",                             // 必要なら絶対パスへ
    "modules" to mutableListOf<Map<String, Any>>()
)

// ---------- 2. プラグイン種別判定 ----------
fun org.gradle.api.Project.detectModuleType(): String = when {
    plugins.hasPlugin("com.android.application") -> "android-application"
    plugins.hasPlugin("com.android.library")     -> "android-library"
    plugins.hasPlugin("com.android.test")        -> "android-test"
    listOf("org.jetbrains.kotlin.jvm", "java", "java-library")
        .any { plugins.hasPlugin(it) }           -> "jvm"
    else                                         -> "other"
}

// ---------- 3. 各プロジェクトを走査 ----------
gradle.allprojects {
    val proj = this
    proj.afterEvaluate {
        val type = proj.detectModuleType()

        val module = mutableMapOf<String, Any>(
            "path" to proj.path,
            "type" to type
        )

        // ----- (A) Android モジュール専用の収集 ----- //
        if (type.startsWith("android")) {
            val androidExt = proj.extensions.findByName("android") ?: return@afterEvaluate

            // 1) buildTypes / productFlavors --------------------------------
            fun names(iter: Iterable<*>) = iter.mapNotNull {
                it?.javaClass?.getMethod("getName")?.invoke(it) as? String
            }.sorted()

            runCatching {
                val bt = androidExt.javaClass.getMethod("getBuildTypes").invoke(androidExt) as Iterable<*>
                if (bt.any()) module["buildTypes"] = names(bt)
            }

            runCatching {
                val pf = androidExt.javaClass.getMethod("getProductFlavors").invoke(androidExt) as Iterable<*>
                if (pf.any()) module["productFlavors"] = names(pf)
            }

            // 2) variants（enabled フラグ付き）----------------------------- ✨ NEW
            val variants = mutableListOf<Map<String, Any>>()
            listOf("applicationVariants", "libraryVariants").forEach { prop ->
                runCatching {
                    androidExt.javaClass.methods
                        .firstOrNull { it.name == prop }
                        ?.invoke(androidExt)
                        ?.let { it as Iterable<*> }
                        ?.forEach { v ->
                            val name    = v?.javaClass?.getMethod("getName")   ?.invoke(v) as? String ?: return@forEach
                            val enabled = (runCatching {
                                v.javaClass.getMethod("getEnabled")
                                    .invoke(v) as? Boolean
                            }.getOrNull()) ?: true                              // `getEnabled` が無ければ true

                            variants += mapOf("name" to name, "enabled" to enabled)
                        }
                }
            }
            if (variants.isNotEmpty()) module["variants"] = variants.sortedBy { it["name"] as String }

            // 3) minSdkVersion / compileSdkVersion / namespace -------------- ✨ NEW
            runCatching {
                val dc = androidExt.javaClass.getMethod("getDefaultConfig").invoke(androidExt)
                val minSdkObj = dc.javaClass.methods
                    .firstOrNull { it.name in listOf("getMinSdk", "getMinSdkVersion") }
                    ?.invoke(dc)

                val minSdk = when (minSdkObj) {
                    is Int   -> minSdkObj
                    null     -> null
                    else     -> runCatching {
                        minSdkObj.javaClass.getMethod("getApiLevel")
                            .invoke(minSdkObj) as? Int
                    }.getOrNull()
                }
                minSdk?.let { module["minSdkVersion"] = it }
            }

            runCatching {
                val compileSdk = androidExt.javaClass.methods
                    .firstOrNull { it.name in listOf("getCompileSdkVersion", "getCompileSdk") }
                    ?.invoke(androidExt)

                when (compileSdk) {
                    is Int    -> module["compileSdkVersion"] = compileSdk
                    is String -> module["compileSdkVersion"] = compileSdk   // preview など
                }
            }

            runCatching {
                val ns = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as? String
                ns?.let { module["namespace"] = it }
            }

            // 4) Java version & Kotlin JVM target --------------------------- ✨ NEW
            runCatching {
                val co = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                val srcVer = co?.javaClass?.getMethod("getSourceCompatibility")?.invoke(co)
                srcVer?.toString()?.let { module["javaVersion"] = it }
            }

            runCatching {
                val jvmTargets = proj.tasks
                    .matching { it.javaClass.name.endsWith("KotlinCompile") }
                    .mapNotNull { task ->
                        task.javaClass
                            .methods.firstOrNull { m -> m.name == "getKotlinOptions" }
                            ?.invoke(task)
                            ?.javaClass?.methods?.firstOrNull { m -> m.name == "getJvmTarget" }
                            ?.invoke(
                                task.javaClass
                                    .getMethod("getKotlinOptions")
                                    .invoke(task)
                            ) as? String
                    }.toSet()
                if (jvmTargets.isNotEmpty())
                    module["jvmTarget"] = if (jvmTargets.size == 1) jvmTargets.first() else jvmTargets.sorted()
            }
        }

        // ----- (B) JVM モジュールでも jvmTarget を取れるなら追加 ---------- ✨ OPTIONAL
        if (type == "jvm") {
            runCatching {
                val jvmTargets = proj.tasks
                    .matching { it.javaClass.name.endsWith("KotlinCompile") }
                    .mapNotNull { task ->
                        task.javaClass
                            .methods.firstOrNull { it.name == "getKotlinOptions" }
                            ?.invoke(task)
                            ?.javaClass?.methods?.firstOrNull { it.name == "getJvmTarget" }
                            ?.invoke(
                                task.javaClass
                                    .getMethod("getKotlinOptions")
                                    .invoke(task)
                            ) as? String
                    }.toSet()
                if (jvmTargets.isNotEmpty())
                    module["jvmTarget"] = if (jvmTargets.size == 1) jvmTargets.first() else jvmTargets.sorted()
            }
        }

        // 結果に追加
        @Suppress("UNCHECKED_CAST")
        (result["modules"] as MutableList<Map<String, Any>>).add(module)
    }
}

// ---------- 4. JSON 書き出し ----------
gradle.buildFinished {
    val outPath = System.getenv("JSON_OUTPUT_PATH")
        ?: TODO("JSON_OUTPUT_PATH not defined") // FIXME "${gradle.rootProject.buildDir}/module-info.json"
    File(outPath).apply {
        parentFile.mkdirs()
        writeText(JsonOutput.prettyPrint(JsonOutput.toJson(result)))
    }
    println("\u001B[36m[collect-info] Wrote module info to $outPath\u001B[0m")
}
