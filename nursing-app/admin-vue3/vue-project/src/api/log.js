/**
 * 操作日志 API
 */
import { get, del } from '@/utils/request'

/**
 * 获取操作日志列表
 * @param {Object} params - 查询参数 { page, pageSize, userId, actionType, startDate, endDate }
 */
export function getLogList(params) {
  return get('/admin/log/list', params)
}

/**
 * 获取日志详情
 * @param {number} id - 日志ID
 */
export function getLogDetail(id) {
  return get(`/admin/log/detail/${id}`)
}

/**
 * 删除日志
 * @param {number} id - 日志ID
 */
export function deleteLog(id) {
  return del(`/admin/log/delete/${id}`)
}
