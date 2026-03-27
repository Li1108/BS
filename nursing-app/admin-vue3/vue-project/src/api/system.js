/**
 * 系统配置 API
 */
import { get, post, del } from '@/utils/request'
import { getUserList } from './user'

/**
 * 获取系统配置列表
 * @param {Object} params - 查询参数
 */
export function getConfigList(params) {
  return get('/admin/config/list', params)
}

/**
 * 获取配置详情
 * @param {string} configKey - 配置键
 */
export function getConfigDetail(configKey) {
  return get(`/admin/config/detail/${configKey}`)
}

/**
 * 新增系统配置
 * @param {Object} data - { configKey, configValue, remark }
 */
export function addConfig(data) {
  return post('/admin/config/add', data)
}

/**
 * 更新系统配置
 * @param {Object} data - { configKey, configValue, remark }
 */
export function updateConfig(data) {
  return post('/admin/config/update', data)
}

/**
 * 删除系统配置
 * @param {string} configKey - 配置键
 */
export function deleteConfig(configKey) {
  return del(`/admin/config/delete/${configKey}`)
}

/**
 * 系统健康检查
 */
export function ping() {
  return get('/system/ping')
}

/**
 * 批量保存配置（upsert，不存在时自动创建）
 */
export function batchUpdateConfig(configs) {
  const items = Array.isArray(configs) ? configs : []
  const validItems = items
    .filter(item => item?.configKey)
    .map(item => ({
      configKey: item.configKey,
      configValue: item.configValue ?? '',
      remark: item.remark ?? item.description ?? ''
    }))
  if (validItems.length === 0) {
    return Promise.resolve({ code: 0, message: 'success', data: true })
  }
  return post('/admin/config/batch-update', validItems)
}

/**
 * 获取阿里云短信/推送健康状态（管理员）
 */
export function getAliyunHealth() {
  return get('/admin/config/aliyun-health')
}

const NOTIFY_TEMPLATE_CONFIG_KEY = 'notify_quick_templates'

/**
 * 获取通知模板配置
 */
export async function getNotifyTemplateConfig() {
  try {
    const listRes = await getConfigList()
    const configs = Array.isArray(listRes?.data) ? listRes.data : []
    const matched = configs.find(item => item?.configKey === NOTIFY_TEMPLATE_CONFIG_KEY)
    return {
      ...(listRes || {}),
      data: {
        configKey: NOTIFY_TEMPLATE_CONFIG_KEY,
        configValue: matched?.configValue || '[]',
        remark: matched?.remark || '通知管理快速模板(JSON)'
      }
    }
  } catch {
    return {
      code: 0,
      message: 'success',
      data: {
        configKey: NOTIFY_TEMPLATE_CONFIG_KEY,
        configValue: '[]',
        remark: '通知管理快速模板(JSON)'
      }
    }
  }
}

/**
 * 保存通知模板配置
 */
export function saveNotifyTemplateConfig(templates) {
  const normalized = Array.isArray(templates) ? templates : []
  return batchUpdateConfig([
    {
      configKey: NOTIFY_TEMPLATE_CONFIG_KEY,
      configValue: JSON.stringify(normalized),
      remark: '通知管理快速模板(JSON)'
    }
  ])
}

/**
 * 通知列表（兼容旧页面）
 */
export function getNotificationList(params) {
  const query = { ...(params || {}) }
  const typeFilter = query.type === '' || query.type === undefined ? null : Number(query.type)
  delete query.type
  return get('/admin/notification/list', query).then(res => {
    const page = res?.data || {}
    const normalizedRecords = (page.records || []).map(item => ({
      ...item,
      type: item.bizType === 'ORDER' ? 1 : item.bizType === 'AUDIT' ? 2 : 3,
      createdAt: item.createdAt || item.createTime
    }))
    const filtered = typeFilter == null ? normalizedRecords : normalizedRecords.filter(item => Number(item.type) === typeFilter)
    return {
      ...res,
      data: {
        ...page,
        total: typeFilter == null ? page.total : filtered.length,
        records: filtered
      }
    }
  })
}

/**
 * 发送通知（兼容旧页面）
 */
export function sendNotification(data) {
  const payload = data || {}
  const title = payload.title || '系统通知'
  const content = payload.content || ''
  const userIds = Array.isArray(payload.userIds) ? payload.userIds : []
  if (userIds.length === 0) {
    return post('/admin/notification/send', {
      receiverType: 'ALL_USER',
      title,
      content
    })
  }
  return Promise.all(
    userIds.map(id =>
      post('/admin/notification/send', {
        receiverType: 'SINGLE_USER',
        receiverUserId: id,
        title,
        content
      })
    )
  ).then(() => ({ code: 0, message: 'success', data: true }))
}

/**
 * 操作日志（兼容旧页面）
 */
export async function getOperationLogs(params) {
  const query = { ...(params || {}) }
  if (query.userId && !query.adminUserId) {
    query.adminUserId = query.userId
  }
  const [res, usersRes] = await Promise.all([
    get('/admin/log/list', query),
    getUserList({ pageNo: 1, pageSize: 1000 })
  ])
  const userMap = new Map((usersRes?.data?.records || []).map(item => [item.id, item.username || item.phone]))
  const page = res?.data || {}
  return {
    ...res,
    data: {
      ...page,
      records: (page.records || []).map(item => ({
        ...item,
        userId: item.adminUserId,
        userName: userMap.get(item.adminUserId) || `管理员#${item.adminUserId || '-'}`,
        description: item.description || item.actionDesc || '',
        ipAddress: item.ipAddress || item.ip || '',
        createdAt: item.createdAt || item.createTime,
        userAgent: item.userAgent || ''
      }))
    }
  }
}
