/**
 * 支付管理 API
 */
import { get } from '@/utils/request'

/**
 * 获取支付记录列表
 * @param {Object} params - 查询参数 { page, pageSize, orderNo, status }
 */
export function getPaymentList(params) {
  return get('/admin/payment/list', params)
}

/**
 * 获取支付详情
 * @param {string} orderNo - 订单编号
 */
export function getPaymentDetail(orderNo) {
  return get(`/admin/payment/detail/${orderNo}`)
}

export function getPaymentReconcile(params) {
  return get('/admin/payment/reconcile', params)
}
