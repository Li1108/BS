/**
 * 文件管理 API
 */
import { get, del } from '@/utils/request'

/**
 * 获取文件列表
 * @param {Object} params - 查询参数 { page, pageSize }
 */
export function getFileList(params) {
  return get('/admin/file/list', params)
}

/**
 * 删除文件
 * @param {number} id - 文件ID
 */
export function deleteFile(id) {
  return del(`/admin/file/delete/${id}`)
}
