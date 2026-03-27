<script setup>
/**
 * 登录页面组件
 * 功能：手机号/密码登录，JWT存储，跳转仪表盘
 * 基于项目文档：管理后台使用 Vue Router + Pinia 状态管理，token 存储 localStorage，路由守卫校验ADMIN角色权限
 */
import { ref, reactive, onMounted, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { ElMessage, ElNotification } from 'element-plus'
import { useUserStore } from '@/stores/user'
const isDev = import.meta.env.DEV
const router = useRouter()
const route = useRoute()
const userStore = useUserStore()

// ==================== 状态定义 ====================

// 表单数据
const loginForm = reactive({
  phone: '',
  password: '',
  rememberMe: false
})

// 表单引用
const formRef = ref(null)

// 加载状态
const loading = ref(false)

const canSubmit = computed(() => {
  return /^1[3-9]\d{9}$/.test(loginForm.phone) && loginForm.password.length >= 6
})

// ==================== 表单验证规则 ====================

const loginRules = computed(() => ({
  phone: [
    { required: true, message: '请输入手机号', trigger: 'blur' },
    { pattern: /^1[3-9]\d{9}$/, message: '请输入正确的11位手机号', trigger: 'blur' }
  ],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 6, message: '密码长度不能少于6位', trigger: 'blur' }
  ]
}))

// ==================== 方法定义 ====================

/**
 * 提交登录
 * 校验ADMIN角色，JWT存储到localStorage，跳转仪表盘
 */
const handleLogin = async () => {
  if (!formRef.value || loading.value) return
  
  try {
    // 表单验证
    await formRef.value.validate()
    
    loading.value = true
    
    // 构建登录请求数据
    const loginData = {
      phone: loginForm.phone.trim(),
      password: loginForm.password
    }
    
    // 调用登录接口（store中会校验ADMIN角色并存储JWT）
    await userStore.login(loginData)
    
    // 记住手机号（可选）
    if (loginForm.rememberMe) {
      localStorage.setItem('rememberedPhone', loginForm.phone)
    } else {
      localStorage.removeItem('rememberedPhone')
    }
    
    // 登录成功提示
    ElNotification({
      title: '登录成功',
      message: `欢迎回来，${userStore.username || '管理员'}！`,
      type: 'success',
      duration: 3000
    })
    
    // 跳转到目标页面或仪表盘
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/dashboard'
    router.push(redirect)
    
  } catch (error) {
    // 显示错误信息
    if (!error?.__handled) {
      ElMessage.error(error?.message || '登录失败，请检查账号密码')
    }
  } finally {
    loading.value = false
  }
}

/**
 * 重置表单
 */
const resetForm = () => {
  formRef.value?.resetFields()
  loginForm.phone = ''
  loginForm.password = ''
}

const normalizePhone = (value) => {
  loginForm.phone = String(value || '').replace(/\D/g, '').slice(0, 11)
}

// ==================== 生命周期 ====================

onMounted(() => {
  // 如果已登录且是管理员，直接跳转仪表盘
  if (userStore.isLoggedIn && userStore.isAdmin) {
    router.replace('/dashboard')
    return
  }
  
  // 恢复记住的手机号
  const rememberedPhone = localStorage.getItem('rememberedPhone')
  if (rememberedPhone) {
    loginForm.phone = rememberedPhone
    loginForm.rememberMe = true
  }
})

</script>

<template>
  <div class="login-container">
    <div class="bg-shape bg-shape-left" aria-hidden="true"></div>
    <div class="bg-shape bg-shape-right" aria-hidden="true"></div>

    <div class="login-card">
      <!-- Logo和标题 -->
      <div class="login-header">
        <div class="logo-wrap">
          <el-icon :size="44" color="#ffffff">
            <FirstAidKit />
          </el-icon>
        </div>
        <div class="brand-badge">ADMIN</div>
        <h1 class="login-title">护理服务管理后台</h1>
        <p class="login-subtitle">互联网+护理服务APP管理系统</p>
      </div>
      
      <!-- 登录表单 -->
      <el-form
        ref="formRef"
        :model="loginForm"
        :rules="loginRules"
        class="login-form"
        size="large"
        @submit.prevent="handleLogin"
      >
        <!-- 手机号 -->
        <el-form-item prop="phone">
          <el-input
            v-model="loginForm.phone"
            class="login-input"
            placeholder="请输入手机号"
            prefix-icon="Iphone"
            maxlength="11"
            clearable
            autocomplete="tel"
            @input="normalizePhone"
            @keyup.enter="handleLogin"
          />
        </el-form-item>
        
        <!-- 密码登录 -->
        <el-form-item prop="password">
          <el-input
            v-model="loginForm.password"
            class="login-input"
            placeholder="请输入密码"
            prefix-icon="Lock"
            show-password
            clearable
            autocomplete="current-password"
            @keyup.enter="handleLogin"
          />
        </el-form-item>
        
        <!-- 记住我 & 切换登录方式 -->
        <div class="login-options">
          <el-checkbox v-model="loginForm.rememberMe">
            记住手机号
          </el-checkbox>
        </div>
        
        <!-- 登录按钮 -->
        <el-form-item>
          <el-button
            type="primary"
            class="login-btn"
            :loading="loading"
            :disabled="!canSubmit || loading"
            @click="handleLogin"
          >
            <el-icon v-if="!loading" class="btn-icon"><Unlock /></el-icon>
            {{ loading ? '登录中...' : '登 录' }}
          </el-button>
        </el-form-item>
      </el-form>
      
      <!-- 提示信息 -->
      <div class="login-tips">
        <el-alert
          title="提示：仅超级管理员账号（ADMIN_SUPER角色）可登录此系统"
          type="info"
          :closable="false"
          show-icon
        />
      </div>
      
      <!-- 测试账号提示（开发环境） -->
      <div v-if="isDev" class="dev-tips">
        <el-divider>开发测试</el-divider>
        <p>测试账号：18800000001</p>
        <p>测试密码：123456（如未初始化请执行种子SQL）</p>
      </div>
    </div>
    
    <!-- 版权信息 -->
    <div class="login-footer">
      <p>© 2026 互联网+护理服务APP </p>
      <p class="tech-stack">Vue3 + Element Plus + Spring Boot</p>
    </div>
  </div>
</template>

<style scoped>
.login-container {
  position: relative;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  background: linear-gradient(135deg, #5b8ff9 0%, #7265e6 48%, #8b5cf6 100%);
  padding: 20px;
}

.bg-shape {
  position: absolute;
  border-radius: 50%;
  filter: blur(2px);
  opacity: 0.25;
  pointer-events: none;
}

.bg-shape-left {
  width: 380px;
  height: 380px;
  background: #c7d2fe;
  top: -120px;
  left: -80px;
}

.bg-shape-right {
  width: 320px;
  height: 320px;
  background: #ddd6fe;
  right: -80px;
  bottom: -90px;
}

.login-card {
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 440px;
  background: rgba(255, 255, 255, 0.96);
  border: 1px solid rgba(255, 255, 255, 0.8);
  backdrop-filter: blur(6px);
  border-radius: 20px;
  padding: 36px 34px 30px;
  box-shadow: 0 18px 50px rgba(31, 41, 55, 0.2);
}

.login-header {
  text-align: center;
  margin-bottom: 28px;
}

.logo-wrap {
  margin: 0 auto;
  width: 72px;
  height: 72px;
  border-radius: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(140deg, #409eff 0%, #6366f1 100%);
  box-shadow: 0 10px 24px rgba(64, 158, 255, 0.35);
}

.brand-badge {
  margin: 12px auto 0;
  width: fit-content;
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
  color: #4f46e5;
  background: #eef2ff;
}

.login-title {
  font-size: 25px;
  color: #303133;
  margin: 14px 0 8px;
  font-weight: 700;
}

.login-subtitle {
  font-size: 14px;
  color: #6b7280;
}

.login-form {
  margin-top: 16px;
}

.login-form :deep(.el-form-item) {
  margin-bottom: 18px;
}

.login-input :deep(.el-input__wrapper) {
  border-radius: 12px;
  min-height: 46px;
  box-shadow: 0 0 0 1px #e5e7eb inset;
  transition: box-shadow 0.2s ease;
}

.login-input :deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 1px #409eff inset;
}

.login-options {
  display: flex;
  justify-content: flex-start;
  align-items: center;
  margin: -2px 0 18px;
}

.login-btn {
  width: 100%;
  height: 48px;
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 2px;
  border-radius: 12px;
  box-shadow: 0 10px 24px rgba(64, 158, 255, 0.3);
}

.btn-icon {
  margin-right: 6px;
}

.login-tips {
  margin-top: 20px;
}

.dev-tips {
  margin-top: 16px;
  padding: 12px;
  background-color: #fdf6ec;
  border-radius: 8px;
  font-size: 12px;
  color: #e6a23c;
  text-align: center;
}

.dev-tips p {
  margin: 4px 0;
}

.dev-tips :deep(.el-divider__text) {
  font-size: 12px;
  color: #e6a23c;
}

.login-footer {
  position: relative;
  z-index: 1;
  margin-top: 24px;
  text-align: center;
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
}

.login-footer .tech-stack {
  font-size: 12px;
  margin-top: 4px;
  opacity: 0.8;
}

/* 响应式适配 */
@media (max-width: 768px) {
  .login-container {
    padding: 16px;
  }

  .bg-shape-left {
    width: 260px;
    height: 260px;
    top: -80px;
  }

  .bg-shape-right {
    width: 220px;
    height: 220px;
    bottom: -70px;
  }
  
  .login-card {
    padding: 28px 22px 24px;
    max-width: 100%;
  }
  
  .login-header {
    margin-bottom: 24px;
  }
  
  .login-title {
    font-size: 22px;
  }
  
  .login-btn {
    height: 44px;
    font-size: 15px;
  }
  
  .login-footer {
    font-size: 12px;
  }
}

@media (max-width: 480px) {
  .login-card {
    padding: 24px 18px 20px;
    margin: 0 16px;
    border-radius: 16px;
  }
  
  .login-title {
    font-size: 20px;
  }
  
  .login-btn {
    height: 42px;
    letter-spacing: 1px;
  }
}
</style>
