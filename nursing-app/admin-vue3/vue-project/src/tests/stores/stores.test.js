/**
 * Store单元测试
 * 测试 Pinia stores
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { setActivePinia, createPinia } from 'pinia'
import { useUserStore } from '@/stores/user'
import { useAppStore } from '@/stores/app'

describe('User Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
  })

  it('应该正确初始化默认状态', () => {
    const userStore = useUserStore()

    expect(userStore.token).toBe('')
    expect(userStore.userInfo).toBeNull()
    expect(userStore.isLoggedIn).toBe(false)
  })

  it('应该正确设置用户信息', () => {
    const userStore = useUserStore()
    const mockUserInfo = {
      id: 1,
      username: 'Admin',
      phone: '13800000000',
      role: 'ADMIN'
    }

    userStore.setUserInfo(mockUserInfo)

    expect(userStore.userInfo).toEqual({
      ...mockUserInfo,
      userId: 1,
      avatar: ''
    })
    expect(userStore.username).toBe('Admin')
  })

  it('应该正确设置token', () => {
    const userStore = useUserStore()
    const mockToken = 'test-token-123'

    userStore.setToken(mockToken)

    expect(userStore.token).toBe(mockToken)
    expect(userStore.isLoggedIn).toBe(true)
    expect(localStorage.getItem('token')).toBe(mockToken)
  })

  it('应该正确登出', () => {
    const userStore = useUserStore()
    
    // 先设置用户信息
    userStore.setToken('test-token')
    userStore.setUserInfo({ username: 'Test' })

    // 登出
    userStore.logout()

    expect(userStore.token).toBe('')
    expect(userStore.userInfo).toBeNull()
    expect(userStore.isLoggedIn).toBe(false)
    expect(localStorage.getItem('token')).toBeNull()
  })
})

describe('App Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorage.clear()
  })

  it('应该正确初始化默认状态', () => {
    const appStore = useAppStore()

    expect(appStore.sidebarCollapsed).toBe(false)
    expect(appStore.mobileDrawerVisible).toBe(false)
    expect(appStore.theme).toBe('light')
  })

  it('应该正确切换侧边栏状态', () => {
    const appStore = useAppStore()

    expect(appStore.sidebarCollapsed).toBe(false)
    
    appStore.toggleSidebar()
    expect(appStore.sidebarCollapsed).toBe(true)
    
    appStore.toggleSidebar()
    expect(appStore.sidebarCollapsed).toBe(false)
  })

  it('应该正确计算侧边栏宽度', () => {
    const appStore = useAppStore()

    expect(appStore.sidebarWidth).toBe('220px')
    
    appStore.toggleSidebar()
    expect(appStore.sidebarWidth).toBe('64px')
  })

  it('应该正确设置移动端抽屉状态', () => {
    const appStore = useAppStore()

    appStore.setMobileDrawer(true)
    expect(appStore.mobileDrawerVisible).toBe(true)

    appStore.setMobileDrawer(false)
    expect(appStore.mobileDrawerVisible).toBe(false)
  })

  it('应该正确设置主题', () => {
    const appStore = useAppStore()

    appStore.setTheme('dark')
    expect(appStore.theme).toBe('dark')
    expect(localStorage.getItem('theme')).toBe('dark')
  })
})
