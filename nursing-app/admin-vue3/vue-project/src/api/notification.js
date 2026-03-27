/**
 * 通知管理 API
 */
import { get, post } from '@/utils/request'
import { getUserList } from './user'

/**
 * 发送系统通知
 * @param {Object} data - { userIds, type, title, content }
 */
export function sendNotification(data) {
  const title = data?.title || '系统通知'
  const content = data?.content || ''
  const userIds = Array.isArray(data?.userIds) ? data.userIds : []

  if (userIds.length === 1) {
    return post('/admin/notification/send', {
      receiverType: 'SINGLE_USER',
      receiverUserId: userIds[0],
      title,
      content
    })
  }

  if (userIds.length > 1) {
    return Promise.all(
      userIds.map((id) =>
        post('/admin/notification/send', {
          receiverType: 'SINGLE_USER',
          receiverUserId: id,
          title,
          content
        })
      )
    ).then(() => ({ code: 0, message: 'success', data: true }))
  }

  return post('/admin/notification/send', {
    receiverType: 'ALL_USER',
    title,
    content
  })
}

/**
 * 获取通知列表
 * @param {Object} params - 查询参数 { page, pageSize }
 */
export async function getNotificationList(params) {
  const query = { ...(params || {}) }
  const typeFilter = query.type === '' || query.type === undefined ? null : Number(query.type)
  delete query.type
  const [res, usersRes] = await Promise.all([
    get('/admin/notification/list', query),
    getUserList({ pageNo: 1, pageSize: 1000 })
  ])
  const userMap = new Map((usersRes?.data?.records || []).map(item => [item.id, item.username || item.phone]))
  const page = res?.data || {}
  const normalizedRecords = (page.records || []).map(item => ({
    ...item,
    userName: userMap.get(item.receiverUserId) || `用户#${item.receiverUserId || '-'}`,
    type: item.bizType === 'ORDER' ? 1 : item.bizType === 'AUDIT' ? 2 : 3,
    isRead: item.isRead ?? item.readFlag ?? 0,
    createdAt: item.createdAt || item.createTime
  }))
  const filtered = typeFilter == null ? normalizedRecords : normalizedRecords.filter(item => Number(item.type) === typeFilter)

  return {
    ...res,
    data: {
      ...page,
      total: typeFilter == null ? page.total : filtered.length,
      records: filtered
    }
  }
}
