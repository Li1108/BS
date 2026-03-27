/**
 * 应用状态管理 Store
 * 管理侧边栏、主题等全局状态
 * 集成VueUse支持响应式设计
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAppStore = defineStore('app', () => {
  // 侧边栏折叠状态
  const sidebarCollapsed = ref(localStorage.getItem('sidebarCollapsed') === 'true')
  
  // 移动端抽屉状态
  const mobileDrawerVisible = ref(false)
  
  // 主题模式
  const theme = ref(localStorage.getItem('theme') || 'light')
  
  // 面包屑导航
  const breadcrumbs = ref([])

  // 计算属性
  const sidebarWidth = computed(() => sidebarCollapsed.value ? '64px' : '220px')

  /**
   * 切换侧边栏折叠状态
   */
  function toggleSidebar() {
    sidebarCollapsed.value = !sidebarCollapsed.value
    localStorage.setItem('sidebarCollapsed', sidebarCollapsed.value)
  }

  /**
   * 设置移动端抽屉状态
   */
  function setMobileDrawer(visible) {
    mobileDrawerVisible.value = visible
  }

  /**
   * 设置主题
   */
  function setTheme(newTheme) {
    theme.value = newTheme
    localStorage.setItem('theme', newTheme)
    document.documentElement.setAttribute('data-theme', newTheme)
  }

  /**
   * 设置面包屑
   */
  function setBreadcrumbs(items) {
    breadcrumbs.value = items
  }

  return {
    // 状态
    sidebarCollapsed,
    mobileDrawerVisible,
    theme,
    breadcrumbs,
    // 计算属性
    sidebarWidth,
    // 方法
    toggleSidebar,
    setMobileDrawer,
    setTheme,
    setBreadcrumbs
  }
})
