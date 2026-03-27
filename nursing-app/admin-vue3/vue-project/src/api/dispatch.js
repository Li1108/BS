/**
 * 派单管理 API
 */
import { get, post } from '@/utils/request'

/**
 * 获取派单日志列表
 * @param {Object} params - 查询参数 { page, pageSize, orderNo }
 */
export function getDispatchLogList(params) {
  return get('/admin/dispatch/log/list', params)
}

/**
 * 手动派单
 * @param {Object} data - { orderNo, nurseUserId }
 */
export function manualAssign(data) {
  return post('/admin/dispatch/manualAssign', data)
}
