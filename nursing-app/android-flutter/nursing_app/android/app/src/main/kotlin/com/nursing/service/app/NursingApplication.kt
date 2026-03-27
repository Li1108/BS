package com.nursing.service.app

import android.app.Application
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * 护理服务APP Application
 *
 * 初始化阿里云移动推送SDK
 * 配置厂商通道（华为、小米、OPPO、vivo等）
 */
class NursingApplication : Application() {

    companion object {
        private const val TAG = "NursingApplication"
        
        // 阿里云推送配置（从后端sys_config加载或配置文件读取）
        // TODO: 替换为真实的AppKey和AppSecret
        const val ALIYUN_PUSH_APP_KEY = "your_aliyun_push_app_key"
        const val ALIYUN_PUSH_APP_SECRET = "your_aliyun_push_app_secret"
    }

    override fun onCreate() {
        super.onCreate()
        
        // 初始化阿里云移动推送
        initAliyunPush()
        
        // 初始化厂商通道
        initVendorChannels()
    }

    /**
     * 初始化阿里云移动推送SDK
     *
     * 注意：实际集成时需要：
     * 1. 在build.gradle中添加阿里云推送SDK依赖
     * 2. 在阿里云EMAS控制台创建应用获取AppKey和AppSecret
     * 3. 配置AndroidManifest.xml中的权限和组件
     */
    private fun initAliyunPush() {
        try {
            // TODO: 添加阿里云推送SDK后取消注释
            /*
            // 初始化推送SDK
            val pushService = PushServiceFactory.getCloudPushService()
            pushService.register(applicationContext, object : CommonCallback {
                override fun onSuccess(response: String?) {
                    Log.i(TAG, "阿里云推送初始化成功: $response")
                }
                override fun onFailed(errorCode: String?, errorMessage: String?) {
                    Log.e(TAG, "阿里云推送初始化失败: $errorCode - $errorMessage")
                }
            })
            */
            Log.i(TAG, "阿里云推送SDK尚未集成，跳过初始化")
        } catch (e: Exception) {
            Log.e(TAG, "阿里云推送初始化异常", e)
        }
    }

    /**
     * 初始化厂商辅助通道
     */
    private fun initVendorChannels() {
        // TODO: 初始化小米、华为、OPPO、vivo等厂商通道
    }
}
