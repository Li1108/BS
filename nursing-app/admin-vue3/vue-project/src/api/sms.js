import { get } from '@/utils/request'

export function getSmsRecordList(params) {
  return get('/admin/sms/list', params)
}

export function getSmsStats() {
  return get('/admin/sms/stats')
}
