/**
 * 服务项目管理 API
 */
import { get, post, put, del } from '@/utils/request'

// ==================== 服务分类 ====================

/**
 * 获取服务分类列表（公开接口）
 */
export function getCategoryList() {
  return get('/admin/service/category/list')
}

/**
 * 新增服务分类
 * @param {Object} data - 分类信息
 */
export function addCategory(data) {
  return post('/admin/service/category/add', data)
}

/**
 * 更新服务分类
 * @param {number} id - 分类ID
 * @param {Object} data - 分类信息
 */
export function updateCategory(id, data) {
  return put(`/admin/service/category/update/${id}`, data)
}

// ==================== 服务项目 ====================

/**
 * 获取服务项目列表（公开接口）
 * @param {Object} params - 查询参数 { categoryId, status }
 */
export function getServiceItemList(params) {
  return get('/admin/service/item/list', params)
}

/**
 * 新增服务项目
 * @param {Object} data - 服务项目信息
 */
export function addServiceItem(data) {
  return post('/admin/service/item/add', {
    categoryId: data.categoryId,
    serviceName: data.serviceName || data.name,
    serviceDesc: data.serviceDesc || data.description,
    coverImageUrl: data.coverImageUrl || data.iconUrl || null,
    price: data.price,
    durationMinutes: data.durationMinutes || 60,
    status: data.status ?? 1
  })
}

/**
 * 更新服务项目
 * @param {number} id - 服务项目ID
 * @param {Object} data - 服务项目信息
 */
export function updateServiceItem(id, data) {
  return put(`/admin/service/item/update/${id}`, {
    categoryId: data.categoryId,
    serviceName: data.serviceName || data.name,
    serviceDesc: data.serviceDesc || data.description,
    coverImageUrl: data.coverImageUrl || data.iconUrl || null,
    price: data.price,
    durationMinutes: data.durationMinutes || 60,
    status: data.status
  })
}

/**
 * 删除服务项目
 * @param {number} id - 服务项目ID
 */
export function deleteServiceItem(id) {
  return del(`/admin/service/item/delete/${id}`)
}

// ==================== 兼容旧页面命名 ====================

export function getServiceList(params) {
  return getServiceItemList(params)
}

export function createService(data) {
  return addServiceItem(data)
}

export function updateService(id, data) {
  return updateServiceItem(id, data)
}

export function deleteService(id) {
  return deleteServiceItem(id)
}

export function updateServiceStatus(id, status) {
  return post(`/admin/service/item/status/${id}`, {
    status: typeof status === 'object' ? status.status : status
  })
}

export function batchUpdateServiceStatus(ids, status) {
  return post('/admin/service/item/status/batch', { ids, status })
}

export function sortServiceCategories(items) {
  return post('/admin/service/category/sort', items)
}

export function getServiceOptionList(params) {
  return get('/admin/service/option/list', params)
}

export function addServiceOption(data) {
  return post('/admin/service/option/add', data)
}

export function updateServiceOption(id, data) {
  return put(`/admin/service/option/update/${id}`, data)
}

export function deleteServiceOption(id) {
  return del(`/admin/service/option/delete/${id}`)
}
