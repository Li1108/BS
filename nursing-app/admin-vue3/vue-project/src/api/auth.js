/**
 * 认证相关 API
 */
import { post, get } from '@/utils/request'

/**
 * 管理员登录（后台专用）
 * @param {Object} data - { username, password } 或 { phone, code }
 */
export function adminLogin(data) {
  return post('/admin/auth/login', data)
}

/**
 * 用户端验证码登录
 * @param {Object} data - { phone, code }
 */
export function loginByCode(data) {
  return post('/auth/login', data)
}

/**
 * 发送验证码
 * @param {string} phone - 手机号
 */
export function sendVerifyCode(phone) {
  return post('/auth/sendCode', { phone })
}

/**
 * 获取当前用户信息
 */
export function getUserInfo() {
  return get('/auth/me')
}

/**
 * 退出登录
 */
export function logout() {
  return post('/auth/logout')
}
