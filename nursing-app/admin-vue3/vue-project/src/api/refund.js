/**
 * 退款管理 API
 */
import { get, post } from '@/utils/request'

/**
 * 获取退款列表
 * @param {Object} params - 查询参数 { page, pageSize, status, orderNo }
 */
export function getRefundList(params) {
  return get('/admin/refund/list', params)
}

/**
 * 获取退款详情
 * @param {string} orderNo - 订单编号
 */
export function getRefundDetail(orderNo) {
  return get(`/admin/refund/detail/${orderNo}`)
}

/**
 * 审核通过退款
 * @param {string} orderNo - 订单编号
 */
export function approveRefund(orderNo) {
  return post(`/admin/refund/approve/${orderNo}`)
}

/**
 * 驳回退款
 * @param {string} orderNo - 订单编号
 * @param {Object} data - { rejectReason: '驳回原因' }
 */
export function rejectRefund(orderNo, data) {
  return post(`/admin/refund/reject/${orderNo}`, data)
}
