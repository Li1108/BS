/**
 * 提现管理 API
 */
import { get, post } from '@/utils/request'

const normalizeWithdrawalRecord = (item = {}) => ({
  ...item,
  status: Number(item.status ?? 0),
  amount: Number(item.amount ?? item.withdrawAmount ?? 0),
  orderNo: item.orderNo || item.order_no || '',
  alipayAccount: item.alipayAccount || item.bankAccount || '',
  realName: item.realName || item.accountHolder || '',
  nurseName: item.nurseName || item.accountHolder || `护士#${item.nurseUserId || '-'}`,
  nursePhone: item.nursePhone || '',
  rejectReason: item.rejectReason || item.auditRemark || '',
  createdAt: item.createdAt || item.createTime
})

/**
 * 获取提现申请列表
 * @param {Object} params - 查询参数 { page, pageSize, status, nurseId }
 */
export async function getWithdrawalList(params) {
  const query = { ...(params || {}) }
  if (query.keyword) {
    query.nurseName = query.keyword
    delete query.keyword
  }
  const res = await get('/admin/withdraw/list', query)
  const page = res?.data || {}
  return {
    ...res,
    data: {
      ...page,
      records: (page.records || []).map(normalizeWithdrawalRecord)
    }
  }
}

/**
 * 获取提现详情
 * @param {number} id - 提现ID
 */
export async function getWithdrawalDetail(id) {
  const res = await get(`/admin/withdraw/detail/${id}`)
  return {
    ...res,
    data: normalizeWithdrawalRecord(res?.data || {})
  }
}

/**
 * 审核通过提现申请
 * @param {number} id - 提现ID
 */
export function approveWithdrawal(id) {
  return post(`/admin/withdraw/approve/${id}`, {})
}

/**
 * 驳回提现申请
 * @param {number} id - 提现ID
 * @param {Object} data - { rejectReason: '驳回原因' }
 */
export function rejectWithdrawal(id, data) {
  return post(`/admin/withdraw/reject/${id}`, data)
}

/**
 * 确认打款
 * @param {number} id - 提现ID
 * @param {Object} data - { payNo: '打款凭证号', remark: '备注' }
 */
export function payWithdrawal(id, data) {
  return post(`/admin/withdraw/pay/${id}`, data)
}

/**
 * 审核提现（兼容旧页面）
 */
export async function auditWithdrawal(id, data) {
  const targetStatus = Number(data?.status ?? data?.auditStatus)
  if (targetStatus === 3) {
    await approveWithdrawal(id)
    return payWithdrawal(id, {
      payNo: data?.payNo || `MANUAL-${Date.now()}`,
      remark: data?.remark || '线下打款确认'
    })
  }
  if (targetStatus === 1) {
    return approveWithdrawal(id)
  }
  if (targetStatus === 2) {
    return rejectWithdrawal(id, { remark: data?.reason || data?.rejectReason || data?.remark || '' })
  }
  return approveWithdrawal(id)
}

/**
 * 提现统计（兼容旧页面）
 */
export async function getWithdrawalStats() {
  const res = await getWithdrawalList({ pageNo: 1, pageSize: 1000 })
  const records = res?.data?.records || []
  const pendingRecords = records.filter(item => Number(item.status) === 0)
  const rejectedRecords = records.filter(item => Number(item.status) === 2)
  const paidRecords = records.filter(item => Number(item.status) === 3)

  const sumAmount = (list) => list.reduce((sum, item) => sum + Number(item.amount || 0), 0)
  return {
    code: 0,
    message: 'success',
    data: {
      totalCount: records.length,
      pendingCount: pendingRecords.length,
      pendingAmount: sumAmount(pendingRecords),
      approvedCount: paidRecords.length,
      approvedAmount: sumAmount(paidRecords),
      rejectedCount: rejectedRecords.length
    }
  }
}

export function batchAuditWithdrawals(data) {
  return post('/admin/withdraw/batch/audit', data)
}

/**
 * 导出提现报表 PDF
 * @param {Object} params - 查询条件
 */
export function exportWithdrawalPdf(params) {
  const query = { ...(params || {}) }
  if (query.keyword) {
    query.nurseName = query.keyword
    delete query.keyword
  }
  delete query.page
  delete query.pageSize
  return get('/admin/withdraw/export/pdf', query, { responseType: 'blob' })
}
