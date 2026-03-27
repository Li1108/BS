<script setup>
/**
 * 主布局组件 - 包含侧边栏、顶栏和内容区
 * 集成VueUse实现响应式设计和移动端适配
 */
import { computed, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { useAppStore } from '@/stores/app'
import { ElMessageBox, ElMessage } from 'element-plus'
import { useBreakpoints, breakpointsTailwind } from '@vueuse/core'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()
const appStore = useAppStore()

// VueUse响应式断点
const breakpoints = useBreakpoints(breakpointsTailwind)
const isMobile = breakpoints.smaller('md') // < 768px
const isTablet = breakpoints.between('md', 'lg') // 768px - 1024px
const isDesktop = breakpoints.greater('lg') // > 1024px

// 监听移动端变化，自动调整侧边栏
watch(isMobile, (mobile) => {
  if (mobile) {
    appStore.setMobileDrawer(false)
  }
})

// 处理移动端遮罩点击
const handleMaskClick = () => {
  appStore.setMobileDrawer(false)
}

// 菜单列表
const menuList = computed(() => {
  const routes = router.options.routes.find(r => r.path === '/')?.children || []
  return routes.filter(r => r.meta?.title && !r.path.includes(':'))
})

// 当前激活菜单
const activeMenu = computed(() => {
  return route.path
})

// 退出登录
const handleLogout = async () => {
  try {
    await ElMessageBox.confirm('确定要退出登录吗？', '提示', {
      confirmButtonText: '确定',
      cancelButtonText: '取消',
      type: 'warning'
    })
    userStore.logout()
    router.push('/login')
    ElMessage.success('已退出登录')
  } catch {
    // 取消操作
  }
}

// 处理菜单选择
const handleMenuSelect = (index) => {
  router.push(index)
}
</script>

<template>
  <el-container class="main-layout">
    <!-- 移动端遮罩 -->
    <transition name="fade">
      <div 
        v-if="isMobile && appStore.mobileDrawerVisible" 
        class="mobile-mask"
        @click="handleMaskClick"
      ></div>
    </transition>
    
    <!-- 侧边栏 -->
    <el-aside 
      :width="appStore.sidebarWidth" 
      :class="['sidebar', { 
        'mobile-drawer': isMobile,
        'mobile-drawer-open': isMobile && appStore.mobileDrawerVisible 
      }]"
    >
      <!-- Logo区域 -->
      <div class="logo-container">
        <el-icon :size="28" color="#409eff">
          <FirstAidKit />
        </el-icon>
        <span v-show="!appStore.sidebarCollapsed" class="logo-title">护理服务管理</span>
      </div>
      
      <!-- 导航菜单 -->
      <el-menu
        :default-active="activeMenu"
        :collapse="appStore.sidebarCollapsed"
        :unique-opened="true"
        :collapse-transition="false"
        background-color="#304156"
        text-color="#bfcbd9"
        active-text-color="#409eff"
        router
        @select="handleMenuSelect"
      >
        <template v-for="item in menuList" :key="item.path">
          <!-- 有子菜单 -->
          <el-sub-menu v-if="item.children && item.children.length > 0" :index="`/${item.path}`">
            <template #title>
              <el-icon v-if="item.meta?.icon">
                <component :is="item.meta.icon" />
              </el-icon>
              <span>{{ item.meta?.title }}</span>
            </template>
            <el-menu-item
              v-for="child in item.children"
              :key="child.path"
              :index="`/${item.path}/${child.path}`"
            >
              <span>{{ child.meta?.title }}</span>
            </el-menu-item>
          </el-sub-menu>
          
          <!-- 无子菜单 -->
          <el-menu-item v-else :index="`/${item.path}`">
            <el-icon v-if="item.meta?.icon">
              <component :is="item.meta.icon" />
            </el-icon>
            <template #title>
              <span>{{ item.meta?.title }}</span>
            </template>
          </el-menu-item>
        </template>
      </el-menu>
    </el-aside>
    
    <!-- 右侧主区域 -->
    <el-container class="main-container">
      <!-- 顶栏 -->
      <el-header class="header">
        <div class="header-left">
          <!-- 移动端菜单按钮 -->
          <el-icon 
            v-if="isMobile"
            class="collapse-btn mobile-menu-btn"
            :size="24"
            @click="appStore.setMobileDrawer(!appStore.mobileDrawerVisible)"
          >
            <Menu />
          </el-icon>
          
          <!-- 桌面端折叠按钮 -->
          <el-icon 
            v-else
            class="collapse-btn"
            :size="20"
            @click="appStore.toggleSidebar"
          >
            <component :is="appStore.sidebarCollapsed ? 'Expand' : 'Fold'" />
          </el-icon>
          
          <!-- 面包屑 -->
          <el-breadcrumb separator="/">
            <el-breadcrumb-item :to="{ path: '/' }">首页</el-breadcrumb-item>
            <el-breadcrumb-item v-if="route.meta?.title">
              {{ route.meta.title }}
            </el-breadcrumb-item>
          </el-breadcrumb>
        </div>
        
        <div class="header-right">
          <!-- 用户信息 -->
          <el-dropdown trigger="click" @command="handleLogout">
            <div class="user-info">
              <el-avatar :size="isMobile ? 28 : 32" :src="userStore.avatar || undefined">
                <el-icon><UserFilled /></el-icon>
              </el-avatar>
              <span v-if="!isMobile" class="username">{{ userStore.username || '管理员' }}</span>
              <el-icon v-if="!isMobile"><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item disabled>
                  <el-icon><User /></el-icon>
                  {{ userStore.userInfo?.phone }}
                </el-dropdown-item>
                <el-dropdown-item divided command="logout">
                  <el-icon><SwitchButton /></el-icon>
                  退出登录
                </el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>
      
      <!-- 内容区 -->
      <el-main class="main-content">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.main-layout {
  height: 100vh;
  width: 100%;
  overflow: hidden;
  max-width: 100vw;
}

/* 侧边栏样式 */
.sidebar {
  background-color: #304156;
  transition: width 0.3s;
  overflow: hidden;
}

/* 移动端抽屉模式 */
.mobile-drawer {
  position: fixed;
  left: -220px;
  top: 0;
  bottom: 0;
  width: 220px !important;
  z-index: 2000;
  transition: left 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}

.mobile-drawer-open {
  left: 0;
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.15);
}

/* 移动端遮罩 */
.mobile-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  z-index: 1999;
}

.logo-container {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 16px;
  background-color: #263445;
  gap: 10px;
}

.logo-title {
  color: #fff;
  font-size: 16px;
  font-weight: bold;
  white-space: nowrap;
}

.el-menu {
  border-right: none;
  height: calc(100vh - 60px);
  overflow-y: auto;
}

/* 主容器 */
.main-container {
  flex-direction: column;
  background-color: #f5f7fa;
  min-width: 0;
  overflow: hidden;
}

/* 顶栏样式 */
.header {
  background-color: #fff;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
  box-shadow: 0 1px 4px rgba(0, 21, 41, 0.08);
  z-index: 10;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}

.collapse-btn {
  cursor: pointer;
  color: #606266;
  transition: color 0.3s;
}

.collapse-btn:hover {
  color: #409eff;
}

.header-right {
  display: flex;
  align-items: center;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  transition: background-color 0.3s;
}

.user-info:hover {
  background-color: #f5f7fa;
}

.username {
  color: #606266;
  font-size: 14px;
}

/* 内容区样式 */
.main-content {
  padding: 20px;
  overflow-y: auto;
  overflow-x: hidden;
  min-width: 0;
  max-width: 100%;
  box-sizing: border-box;
}

/* 移动端菜单按钮 */
.mobile-menu-btn {
  font-size: 24px;
}

/* 响应式布局 */
@media (max-width: 768px) {
  .header {
    padding: 0 12px;
  }
  
  .header-left {
    gap: 8px;
  }
  
  .main-content {
    padding: 12px;
  }
  
  .logo-title {
    font-size: 14px;
  }
  
  .el-breadcrumb {
    font-size: 13px;
  }
}

@media (max-width: 480px) {
  .header {
    padding: 0 8px;
  }
  
  .main-content {
    padding: 8px;
  }
  
  .el-breadcrumb {
    display: none;
  }
}

/* 页面过渡动画 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
