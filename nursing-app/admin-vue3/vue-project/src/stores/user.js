/**
 * 用户状态管理 Store
 * 管理用户登录状态、JWT Token、用户信息
 * 基于项目文档：token 存储 localStorage，校验ADMIN角色权限
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { post, get } from '@/utils/request'

// JWT Token 存储键名
const TOKEN_KEY = 'token'
const USER_INFO_KEY = 'userInfo'
const TOKEN_EXPIRES_KEY = 'tokenExpires'

export const useUserStore = defineStore('user', () => {
  function normalizeUserInfo(info = {}) {
    return {
      ...info,
      id: info.id ?? info.userId ?? null,
      userId: info.userId ?? info.id ?? null,
      username: info.username || info.nickname || '',
      avatar: info.avatar || info.avatarUrl || ''
    }
  }

  // ==================== 状态定义 ====================
  
  // JWT Token
  const token = ref(localStorage.getItem(TOKEN_KEY) || '')
  
  // 用户信息
  const userInfo = ref(JSON.parse(localStorage.getItem(USER_INFO_KEY) || 'null'))
  
  // Token过期时间
  const tokenExpires = ref(localStorage.getItem(TOKEN_EXPIRES_KEY) || '')

  // ==================== 计算属性 ====================
  
  // 是否已登录
  const isLoggedIn = computed(() => !!token.value && !isTokenExpired())
  
  // 是否是管理员（角色为 ADMIN_SUPER）
  const isAdmin = computed(() => userInfo.value?.role === 'ADMIN_SUPER')
  
  // 用户名
  const username = computed(() => userInfo.value?.username || '')
  
  // 用户头像
  const avatar = computed(() => userInfo.value?.avatar || '')
  
  // 用户手机号
  const phone = computed(() => userInfo.value?.phone || '')
  
  // 用户ID
  const userId = computed(() => userInfo.value?.id || null)

  // ==================== 私有方法 ====================
  
  /**
   * 检查Token是否过期
   */
  function isTokenExpired() {
    if (!tokenExpires.value) return false
    return new Date().getTime() > parseInt(tokenExpires.value)
  }
  
  /**
   * 解析JWT Token获取过期时间
   */
  function parseTokenExpires(jwtToken) {
    try {
      const payload = JSON.parse(atob(jwtToken.split('.')[1]))
      return payload.exp ? payload.exp * 1000 : null
    } catch {
      return null
    }
  }

  // ==================== 公共方法 ====================

  /**
   * 登录（管理员账号密码）
   * @param {Object} loginForm - 登录表单 { phone, password }
   * @returns {Promise} 登录结果
   */
  async function login(loginForm) {
    const res = await post('/admin/auth/login', {
      phone: loginForm.phone,
      password: loginForm.password
    })
    const { token: jwtToken, userId: loginUserId, role: loginRole } = res.data
    
    // 校验是否是管理员角色（ADMIN_SUPER）
    if (loginRole !== 'ADMIN_SUPER') {
      throw new Error('此账号无管理后台访问权限，仅限超级管理员登录')
    }
    
    // 保存JWT Token到localStorage
    setToken(jwtToken)
    
    // 保存基础用户信息，后续通过 fetchUserInfo 获取完整信息
    setUserInfo({ id: loginUserId, role: loginRole, phone: loginForm.phone })
    
    // 获取完整用户信息
    try {
      await fetchUserInfo()
    } catch (e) {
      // 即使获取详情失败，基础信息已保存，不影响登录
      console.warn('获取用户详情失败:', e)
    }
    
    return res
  }

  /**
   * 设置JWT Token
   * @param {string} jwtToken - JWT Token字符串
   */
  function setToken(jwtToken) {
    token.value = jwtToken
    localStorage.setItem(TOKEN_KEY, jwtToken)
    
    // 解析并存储过期时间
    const expires = parseTokenExpires(jwtToken)
    if (expires) {
      tokenExpires.value = expires.toString()
      localStorage.setItem(TOKEN_EXPIRES_KEY, expires.toString())
    }
  }

  /**
   * 设置用户信息
   * @param {Object} info - 用户信息对象
   */
  function setUserInfo(info) {
    const normalized = normalizeUserInfo(info)
    userInfo.value = normalized
    localStorage.setItem(USER_INFO_KEY, JSON.stringify(normalized))
  }

  /**
   * 获取用户信息（从后端刷新）
   * @returns {Promise} 用户信息
   */
  async function fetchUserInfo() {
    try {
      const res = await get('/auth/me')
      const normalized = normalizeUserInfo(res.data || {})
      setUserInfo(normalized)
      return normalized
    } catch (error) {
      // 获取失败，清除登录状态
      logout()
      throw error
    }
  }

  /**
   * 退出登录
   * 清除所有登录状态和localStorage中的数据
   */
  function logout() {
    // 清除状态
    token.value = ''
    userInfo.value = null
    tokenExpires.value = ''
    
    // 清除localStorage
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(USER_INFO_KEY)
    localStorage.removeItem(TOKEN_EXPIRES_KEY)
  }

  /**
   * 校验Token是否有效
   * @returns {Promise<boolean>} 是否有效
   */
  async function checkToken() {
    // 没有token
    if (!token.value) {
      return false
    }
    
    // token已过期
    if (isTokenExpired()) {
      logout()
      return false
    }
    
    // 尝试获取用户信息验证token有效性
    try {
      await fetchUserInfo()
      return isAdmin.value // 必须是管理员
    } catch {
      return false
    }
  }

  /**
   * 刷新Token（如果后端支持）
   * @returns {Promise} 刷新结果
   */
  async function refreshToken() {
    try {
      const res = await post('/auth/refresh')
      setToken(res.data.token)
      return res
    } catch (error) {
      logout()
      throw error
    }
  }

  return {
    // 状态
    token,
    userInfo,
    tokenExpires,
    // 计算属性
    isLoggedIn,
    isAdmin,
    username,
    avatar,
    phone,
    userId,
    // 方法
    login,
    logout,
    setToken,
    setUserInfo,
    fetchUserInfo,
    checkToken,
    refreshToken
  }
})
