/**
 * 订单管理 API
 */
import { get, post } from '@/utils/request'

/**
 * 获取订单列表
 * @param {Object} params - 查询参数 { page, pageSize, status, orderNo, phone, startDate, endDate }
 */
export function getOrderList(params) {
  const query = { ...(params || {}) }
  if (query.status !== undefined && query.orderStatus === undefined) {
    query.orderStatus = query.status
  }
  if (query.phone && !query.userPhone) {
    query.userPhone = query.phone
  }
  delete query.status
  delete query.phone
  return get('/admin/order/list', query)
}

/**
 * 获取订单详情
 * @param {string} orderNo - 订单编号
 */
export function getOrderDetail(orderNo) {
  return get(`/admin/order/detail/${orderNo}`)
}

/**
 * 获取订单全链路详情（状态流/派单/支付退款/SOS）
 * @param {string} orderNo - 订单编号
 */
export function getOrderFlow(orderNo) {
  return get(`/admin/order/flow/${orderNo}`)
}

/**
 * 取消订单
 * @param {string} orderNo - 订单编号
 * @param {Object} data - { reason }
 */
export function cancelOrder(orderNo, data) {
  return post(`/admin/order/cancel/${orderNo}`, data)
}

/**
 * 订单退款
 * @param {string} orderNo - 订单编号
 * @param {Object} data - { reason }
 */
export function refundOrder(orderNo, data) {
  return post(`/admin/order/refund/${orderNo}`, data)
}

/**
 * 获取自动取消订单列表
 * @param {Object} params - 查询参数
 */
export function getAutoCancelList(params) {
  return get('/admin/order/autoCancel/list', params)
}

/**
 * 更新订单状态（兼容旧页面调用）
 * 后端未提供通用状态更新接口，当前仅保留占位实现
 */
export function updateOrderStatus(payload) {
  return post('/admin/order/cancel/' + payload?.orderNo, { reason: payload?.reason || '管理员操作' })
}

/**
 * 导出订单（兼容旧页面调用）
 * 优先走后端导出接口；若后端未实现，该请求会返回业务错误
 */
export function exportOrders(params) {
  return get('/admin/order/export', params, { responseType: 'blob' })
}

/**
 * 订单统计（兼容旧页面调用）
 */
export async function getOrderStats() {
  const [statusRes, dashboardRes] = await Promise.all([
    get('/admin/stat/orderCountByStatus'),
    get('/admin/stat/dashboard')
  ])
  return {
    code: 0,
    message: 'success',
    data: {
      ...(statusRes?.data || {}),
      todayCount: Number(dashboardRes?.data?.todayOrders || 0)
    }
  }
}
