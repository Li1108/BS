package com.nursing.service.app

import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 主Activity
 *
 * 配置Flutter与原生Android的通信通道
 * 处理阿里云推送相关的方法调用
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val PUSH_CHANNEL = "com.nursing_app/aliyun_push"
    }

    private var pushMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 设置阿里云推送方法通道
        pushMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PUSH_CHANNEL
        )
        pushMethodChannel?.setMethodCallHandler { call, result ->
            handlePushMethodCall(call, result)
        }
    }

    /**
     * 处理推送相关的方法调用
     */
    private fun handlePushMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> initPush(result)
            "bindAccount" -> {
                val account = call.argument<String>("account")
                bindAccount(account, result)
            }
            "unbindAccount" -> unbindAccount(result)
            "bindTag" -> {
                val tags = call.argument<List<String>>("tags")
                val target = call.argument<Int>("target") ?: 1
                bindTag(tags, target, result)
            }
            "unbindTag" -> {
                val tags = call.argument<List<String>>("tags")
                val target = call.argument<Int>("target") ?: 1
                unbindTag(tags, target, result)
            }
            "addAlias" -> {
                val alias = call.argument<String>("alias")
                addAlias(alias, result)
            }
            "removeAlias" -> {
                val alias = call.argument<String>("alias")
                removeAlias(alias, result)
            }
            "checkPermission" -> checkPermission(result)
            "requestPermission" -> requestPermission(result)
            "clearNotifications" -> clearNotifications(result)
            "setBadgeNumber" -> {
                // Android通常不需要手动设置角标，部分厂商支持
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initPush(result: MethodChannel.Result) {
        // TODO: 调用阿里云推送SDK初始化
        // 模拟成功
        val mockDeviceId = "mock_device_id_" + System.currentTimeMillis()
        val response = mapOf(
            "success" to true,
            "deviceId" to mockDeviceId
        )
        result.success(response)
    }

    private fun bindAccount(account: String?, result: MethodChannel.Result) {
        if (account.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Account cannot be empty", null)
            return
        }
        // TODO: 调用SDK绑定账号
        result.success(mapOf("success" to true))
    }

    private fun unbindAccount(result: MethodChannel.Result) {
        // TODO: 调用SDK解绑账号
        result.success(mapOf("success" to true))
    }

    private fun bindTag(tags: List<String>?, target: Int, result: MethodChannel.Result) {
        if (tags.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Tags cannot be empty", null)
            return
        }
        // TODO: 调用SDK绑定标签
        result.success(mapOf("success" to true))
    }

    private fun unbindTag(tags: List<String>?, target: Int, result: MethodChannel.Result) {
        if (tags.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Tags cannot be empty", null)
            return
        }
        // TODO: 调用SDK解绑标签
        result.success(mapOf("success" to true))
    }

    private fun addAlias(alias: String?, result: MethodChannel.Result) {
        if (alias.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Alias cannot be empty", null)
            return
        }
        // TODO: 调用SDK添加别名
        result.success(mapOf("success" to true))
    }

    private fun removeAlias(alias: String?, result: MethodChannel.Result) {
        if (alias.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "Alias cannot be empty", null)
            return
        }
        // TODO: 调用SDK移除别名
        result.success(mapOf("success" to true))
    }

    private fun checkPermission(result: MethodChannel.Result) {
        // TODO: 检查通知权限
        result.success(true)
    }

    private fun requestPermission(result: MethodChannel.Result) {
        // TODO: 请求通知权限
        result.success(true)
    }

    private fun clearNotifications(result: MethodChannel.Result) {
        // TODO: 清除通知
        result.success(null)
    }
}
