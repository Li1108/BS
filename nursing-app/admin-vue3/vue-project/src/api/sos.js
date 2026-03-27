import { get, post } from '@/utils/request'

export function getSosList(params) {
  return get('/admin/sos/list', params)
}

export function handleSos(id, data) {
  return post(`/admin/sos/handle/${id}`, data || {})
}

export function getSosStats() {
  return get('/admin/sos/stats')
}
