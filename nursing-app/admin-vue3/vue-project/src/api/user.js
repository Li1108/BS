/**
 * 用户管理 API
 */
import { get, post } from '@/utils/request'
import { getNurseList } from './nurse'

const resolveAvatarUrl = (avatar) => {
  const value = (avatar || '').toString().trim()
  if (!value) return ''
  if (/^https?:\/\//i.test(value)) return value
  if (!value.startsWith('/')) return value
  if (value.startsWith('/api/')) return value

  const apiBase = (import.meta.env.VITE_API_BASE_URL || '').trim()
  const normalizedValue = value.startsWith('/uploads/') ? value : value
  if (!apiBase) return normalizedValue
  if (apiBase.startsWith('/')) {
    return `${apiBase.replace(/\/$/, '')}${normalizedValue}`
  }

  try {
    const url = new URL(apiBase)
    const basePath = url.pathname.replace(/\/$/, '')
    return `${url.origin}${basePath}${normalizedValue}`
  } catch {
    return normalizedValue
  }
}

const normalizeUser = (item = {}) => ({
  ...item,
  avatar: resolveAvatarUrl(item.avatar || item.avatarUrl || ''),
  username: item.username || item.nickname || item.phone || '',
  createdAt: item.createdAt || item.createTime,
  role: item.role || 'USER'
})

/**
 * 获取用户列表
 * @param {Object} params - 查询参数 { page, pageSize, keyword, status }
 */
export async function getUserList(params) {
  const [res, nurseRes] = await Promise.all([
    get('/admin/user/list', params),
    getNurseList({ pageNo: 1, pageSize: 1000 })
  ])
  const nurseUserIds = new Set((nurseRes?.data?.records || []).map(item => item.userId))
  const page = res?.data || {}
  return {
    ...res,
    data: {
      ...page,
      records: (page.records || []).map(item => {
        const normalized = normalizeUser(item)
        if (normalized.role !== 'ADMIN_SUPER') {
          normalized.role = nurseUserIds.has(normalized.id) ? 'NURSE' : 'USER'
        }
        return normalized
      })
    }
  }
}

/**
 * 禁用用户
 * @param {number} userId - 用户ID
 */
export function disableUser(userId) {
  return post(`/admin/user/disable/${userId}`)
}

/**
 * 启用用户
 * @param {number} userId - 用户ID
 */
export function enableUser(userId) {
  return post(`/admin/user/enable/${userId}`)
}

/**
 * 获取用户详情
 * @param {number} userId - 用户ID
 */
export function getUserDetail(userId) {
  return get(`/admin/user/${userId}`).then((res) => {
    const normalized = normalizeUser(res?.data || {})
    return {
      ...res,
      data: {
        ...(res?.data || {}),
        ...normalized,
        avatarUrl: normalized.avatar
      }
    }
  })
}

/**
 * 更新用户状态（兼容旧页面）
 * status: 1 启用，0 禁用
 */
export function updateUserStatus(userId, status) {
  const normalizedStatus = Number(typeof status === 'object' ? status?.status : status)
  if (normalizedStatus === 1) {
    return enableUser(userId)
  }
  return disableUser(userId)
}
