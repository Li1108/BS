/**
 * 钱包管理 API
 */
import { get } from '@/utils/request'
import { post } from '@/utils/request'

/**
 * 获取钱包列表
 * @param {Object} params - 查询参数 { page, pageSize }
 */
export function getWalletList(params) {
  return get('/admin/wallet/list', params)
}

/**
 * 获取护士钱包详情
 * @param {number} nurseUserId - 护士用户ID
 */
export function getWalletDetail(nurseUserId, config = {}) {
  return get(`/admin/wallet/detail/${nurseUserId}`, undefined, config)
}

export function getWalletBatchDetail(nurseUserIds) {
  return post('/admin/wallet/batch/detail', { nurseUserIds })
}

/**
 * 获取钱包流水列表
 * @param {Object} params - 查询参数 { page, pageSize, nurseUserId, type }
 */
export function getWalletLogList(params) {
  return get('/admin/wallet/log/list', params)
}
