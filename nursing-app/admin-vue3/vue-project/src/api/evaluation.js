/**
 * 评价管理 API
 */
import { get, del } from '@/utils/request'
import { getUserList } from './user'
import { getNurseList } from './nurse'
import { getOrderList } from './order'

/**
 * 获取评价列表
 * @param {Object} params - 查询参数 { page, pageSize, rating, nurseId, startDate, endDate }
 */
export async function getEvaluationList(params) {
  const query = { ...(params || {}) }
  if (query.nurseId && !query.nurseUserId) {
    query.nurseUserId = query.nurseId
  }
  delete query.nurseId

  const [res, userRes, nurseRes, orderRes] = await Promise.all([
    get('/admin/evaluation/list', query),
    getUserList({ pageNo: 1, pageSize: 1000 }),
    getNurseList({ pageNo: 1, pageSize: 1000 }),
    getOrderList({ pageNo: 1, pageSize: 1000 })
  ])
  const userMap = new Map((userRes?.data?.records || []).map(item => [item.id, item.username || item.phone]))
  const nurseMap = new Map((nurseRes?.data?.records || []).map(item => [item.userId, item.realName || item.phone]))
  const orderMap = new Map((orderRes?.data?.records || []).map(item => [item.orderNo, item]))

  const page = res?.data || {}
  const records = (page.records || []).map(item => {
    const order = orderMap.get(item.orderNo) || {}
    return {
      ...item,
      userName: userMap.get(item.userId) || `用户#${item.userId || '-'}`,
      nurseName: nurseMap.get(item.nurseUserId) || `护士#${item.nurseUserId || '-'}`,
      serviceName: order.serviceName || '',
      comment: item.comment || item.content || '',
      createdAt: item.createdAt || item.createTime
    }
  })

  return {
    ...res,
    data: {
      ...page,
      records
    }
  }
}

/**
 * 删除评价
 * @param {number} id - 评价ID
 */
export function deleteEvaluation(id) {
  return del(`/admin/evaluation/delete/${id}`)
}

/**
 * 获取评价详情（兼容旧页面）
 */
export async function getEvaluationDetail(id) {
  const res = await get(`/admin/evaluation/detail/${id}`)
  const item = res?.data || null
  if (!item) {
    return { code: 0, message: 'success', data: null }
  }
  const listRes = await getEvaluationList({ pageNo: 1, pageSize: 1000 })
  const record = (listRes?.data?.records || []).find(row => row.id === id) || {
    ...item,
    comment: item.comment || item.content || '',
    createdAt: item.createdAt || item.createTime
  }
  return { code: 0, message: 'success', data: record }
}

/**
 * 获取评价统计（兼容旧页面）
 */
export async function getEvaluationStats() {
  const res = await getEvaluationList({ pageNo: 1, pageSize: 1000 })
  const records = res?.data?.records || []
  const totalCount = records.length
  const avgRating = totalCount
    ? Number((records.reduce((sum, item) => sum + (Number(item.rating) || 0), 0) / totalCount).toFixed(1))
    : 0
  const fiveStarCount = records.filter(item => Number(item.rating) === 5).length
  const lowRatingCount = records.filter(item => Number(item.rating) <= 2).length
  const fiveStarRate = totalCount ? Number(((fiveStarCount / totalCount) * 100).toFixed(1)) : 0
  return {
    code: 0,
    message: 'success',
    data: { totalCount, avgRating, fiveStarCount, fiveStarRate, lowRatingCount }
  }
}
