/**
 * 护理服务管理后台 - 入口文件
 * Vue3 + Element Plus + Pinia + Vue Router
 */
import { createApp } from 'vue'
import ElementPlus from 'element-plus'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'
import zhCn from 'element-plus/dist/locale/zh-cn.mjs'

import App from './App.vue'
import router from './router'
import pinia from './stores'

const amapSecurityJsCode = import.meta.env.VITE_AMAP_SECURITY_JS_CODE
if (amapSecurityJsCode) {
  window._AMapSecurityConfig = { securityJsCode: amapSecurityJsCode }
}

// 样式
import 'element-plus/dist/index.css'
import './assets/main.css'
import './assets/responsive.css' // VueUse响应式样式

// 创建Vue应用
const app = createApp(App)

// 注册Element Plus图标
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component)
}

// 使用插件
app.use(pinia)
app.use(router)
app.use(ElementPlus, {
  locale: zhCn,
  size: 'default'
})

// 挂载应用
app.mount('#app')

// 全局错误处理
app.config.errorHandler = (err, vm, info) => {
  console.error('全局错误:', err, info)
}
