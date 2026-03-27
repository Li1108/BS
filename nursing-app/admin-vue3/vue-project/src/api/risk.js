import { get } from '@/utils/request'

export function getInServiceRiskList(params) {
  return get('/admin/order/risk/in-service', params)
}

export function getInServiceRiskStats(params) {
  return get('/admin/order/risk/in-service/stats', params)
}
