/**
 * 护士管理 API
 */
import { get, post } from '@/utils/request'
import { getWalletBatchDetail, getWalletDetail } from '@/api/wallet'

const WALLET_BALANCE_CACHE_TTL = 60 * 1000
const walletBalanceCache = new Map()

const resolveAvatarUrl = (avatar) => {
  const value = (avatar || '').toString().trim()
  if (!value) return ''
  if (/^https?:\/\//i.test(value)) return value
  if (value.startsWith('/api/')) return value
  if (!value.startsWith('/')) return value

  const apiBase = (import.meta.env.VITE_API_BASE_URL || '').trim()
  const normalizedValue = value.startsWith('/uploads/') ? value : value
  if (!apiBase) return normalizedValue
  if (apiBase.startsWith('/')) {
    return `${apiBase.replace(/\/$/, '')}${normalizedValue}`
  }

  try {
    const url = new URL(apiBase)
    const basePath = url.pathname.replace(/\/$/, '')
    return `${url.origin}${basePath}${normalizedValue}`
  } catch {
    return normalizedValue
  }
}

const normalizeNurseRecord = (item = {}) => {
  const workMode = Number(item.acceptEnabled ?? item.accept_enabled ?? item.workMode ?? item.work_mode ?? 0)
  const accountStatus = Number(item.userStatus ?? item.status ?? 1)
  return {
    ...item,
    userId: item.userId,
    realName: item.realName || item.nurseName || '',
    phone: item.phone || item.mobile || item.contactPhone || item.userPhone || '',
    idCardPhotoFront: item.idCardPhotoFront || item.idCardFrontUrl || '',
    idCardPhotoBack: item.idCardPhotoBack || item.idCardBackUrl || '',
    certificatePhoto: item.certificatePhoto || item.licenseUrl || '',
    auditReason: item.auditReason || item.auditRemark || '',
    workMode,
    // 账户状态来自 user_account.status，避免误用接单开关
    status: accountStatus,
    rating: Number(item.rating ?? 5),
    balance: Number(item.balance ?? 0),
    serviceArea: item.serviceArea || item.hospital || '',
    pendingHospital: item.pendingHospital || '',
    hospitalChangeStatus:
      item.hospitalChangeStatus === null || item.hospitalChangeStatus === undefined
        ? null
        : Number(item.hospitalChangeStatus),
    hospitalChangeRemark: item.hospitalChangeRemark || '',
    avatar: resolveAvatarUrl(
      item.avatar || item.avatarUrl || item.userAvatarUrl || '',
    ),
    createdAt: item.createdAt || item.createTime
  }
}

const resolveWalletBalance = (walletData, fallback) => {
  const walletBalance = Number(walletData?.balance)
  if (Number.isFinite(walletBalance)) {
    return walletBalance
  }
  const legacyBalance = Number(fallback)
  return Number.isFinite(legacyBalance) ? legacyBalance : 0
}

const readCachedWalletBalance = (userId) => {
  const key = Number(userId)
  if (!Number.isFinite(key) || key <= 0) return null
  const cached = walletBalanceCache.get(key)
  if (!cached) return null
  if ((Date.now() - cached.updatedAt) > WALLET_BALANCE_CACHE_TTL) {
    walletBalanceCache.delete(key)
    return null
  }
  return cached.balance
}

const writeWalletBalanceCache = (walletList = []) => {
  const now = Date.now()
  walletList.forEach((wallet) => {
    const key = Number(wallet?.nurseUserId)
    const balance = Number(wallet?.balance)
    if (!Number.isFinite(key) || key <= 0 || !Number.isFinite(balance)) return
    walletBalanceCache.set(key, {
      balance,
      updatedAt: now
    })
  })
}

const fillWalletBalanceByBatch = async (records = [], useCache = true) => {
  if (!records.length) return records

  const uniqueUserIds = [...new Set(
    records
      .map((item) => Number(item.userId))
      .filter((id) => Number.isFinite(id) && id > 0)
  )]

  const cachedBalanceMap = new Map()
  const missingUserIds = []
  uniqueUserIds.forEach((userId) => {
    const cached = useCache ? readCachedWalletBalance(userId) : null
    if (cached === null) {
      missingUserIds.push(userId)
    } else {
      cachedBalanceMap.set(userId, cached)
    }
  })

  let fetchedWalletMap = new Map()
  if (missingUserIds.length) {
    const walletRes = await getWalletBatchDetail(missingUserIds).catch(() => null)
    const walletList = walletRes?.data || []
    writeWalletBalanceCache(walletList)
    fetchedWalletMap = new Map(
      walletList.map((wallet) => [
        Number(wallet.nurseUserId),
        Number(wallet.balance)
      ])
    )
  }

  return records.map((item) => {
    const userId = Number(item.userId)
    const balanceFromCache = cachedBalanceMap.get(userId)
    const balanceFromBatch = fetchedWalletMap.get(userId)
    const walletBalance = Number.isFinite(balanceFromCache)
      ? balanceFromCache
      : balanceFromBatch
    return {
      ...item,
      balance: resolveWalletBalance(
        Number.isFinite(walletBalance) ? { balance: walletBalance } : null,
        item.balance
      )
    }
  })
}

/**
 * 获取护士列表
 * @param {Object} params - 查询参数 { page, pageSize, auditStatus, keyword }
 */
export async function getNurseList(params, options = {}) {
  const { includeWalletBalance = true, useWalletCache = true } = options
  const query = { ...(params || {}) }

  const [res, userRes] = await Promise.all([
    get('/admin/nurse/list', query),
    get('/admin/user/list', { pageNo: 1, pageSize: 1000 })
  ])
  const userMetaMap = new Map(
    (userRes?.data?.records || []).map((user) => [
      Number(user.id),
      {
        avatarUrl: resolveAvatarUrl(user.avatarUrl || user.avatar || ''),
        status: Number(user.status ?? 1),
        phone: (user.phone || '').toString()
      }
    ])
  )
  const page = res?.data || {}
  const normalizedRecords = (page.records || []).map((item) =>
  {
    const userMeta = userMetaMap.get(Number(item.userId)) || {}
    return normalizeNurseRecord({
      ...item,
      userAvatarUrl: userMeta.avatarUrl || item.userAvatarUrl,
      userStatus: userMeta.status ?? item.userStatus,
      userPhone: userMeta.phone || item.userPhone
    })
  }
  )

  const recordsWithWalletBalance = includeWalletBalance
    ? await fillWalletBalanceByBatch(normalizedRecords, useWalletCache)
    : normalizedRecords

  return {
    ...res,
    data: {
      ...page,
      records: recordsWithWalletBalance
    }
  }
}

/**
 * 获取护士详情
 * @param {number} nurseUserId - 护士用户ID
 */
export async function getNurseDetail(nurseUserId) {
  const [res, walletRes] = await Promise.all([
    get(`/admin/nurse/detail/${nurseUserId}`),
    (async () => {
      const cachedBalance = readCachedWalletBalance(nurseUserId)
      if (cachedBalance !== null) {
        return { data: { balance: cachedBalance } }
      }
      const detailRes = await getWalletDetail(nurseUserId, { silent: true }).catch(() => null)
      if (detailRes?.data) {
        writeWalletBalanceCache([{ nurseUserId, balance: detailRes.data.balance }])
      }
      return detailRes
    })()
  ])
  const nurseData = normalizeNurseRecord(res?.data || {})
  const walletData = walletRes?.data || null
  return {
    ...res,
    data: {
      ...nurseData,
      balance: resolveWalletBalance(walletData, nurseData.balance)
    }
  }
}

/**
 * 审核通过护士
 * @param {number} nurseUserId - 护士用户ID
 */
export function auditPassNurse(nurseUserId) {
  return post(`/admin/nurse/auditPass/${nurseUserId}`)
}

/**
 * 审核驳回护士
 * @param {number} nurseUserId - 护士用户ID
 * @param {Object} data - { rejectReason: '驳回原因' }
 */
export function auditRejectNurse(nurseUserId, data) {
  return post(`/admin/nurse/auditReject/${nurseUserId}`, data)
}

/**
 * 禁止护士接单
 * @param {number} nurseUserId - 护士用户ID
 */
export function disableAcceptNurse(nurseUserId) {
  return post(`/admin/nurse/disableAccept/${nurseUserId}`)
}

/**
 * 允许护士接单
 * @param {number} nurseUserId - 护士用户ID
 */
export function enableAcceptNurse(nurseUserId) {
  return post(`/admin/nurse/enableAccept/${nurseUserId}`)
}

export function approveHospitalChangeNurse(nurseUserId) {
  return post(`/admin/nurse/hospitalChange/approve/${nurseUserId}`)
}

export function rejectHospitalChangeNurse(nurseUserId, data) {
  return post(`/admin/nurse/hospitalChange/reject/${nurseUserId}`, data)
}

/**
 * 获取护士最新位置
 * @param {number} nurseUserId - 护士用户ID
 */
export function getNurseLatestLocation(nurseUserId) {
  return get(`/admin/nurse/location/latest/${nurseUserId}`)
}

/**
 * 获取护士驳回统计
 * @param {number} nurseUserId - 护士用户ID
 */
export function getNurseRejectStat(nurseUserId) {
  return get(`/admin/nurse/reject/stat/${nurseUserId}`)
}

export function updateNurseWorkMode(nurseUserId, workMode) {
  return post(`/admin/nurse/workMode/${nurseUserId}`, { workMode })
}

export function getNurseRejectLogs(params) {
  return get('/admin/nurse/reject/log/list', params)
}

export function getNurseRejectAlerts() {
  return get('/admin/nurse/reject/alert')
}

export function getNurseLocationList() {
  return get('/admin/nurse/location/list')
}

/**
 * 更新护士状态（兼容旧页面调用）
 * status: 1 启用接单，0 禁用接单
 */
export function updateNurseStatus(nurseUserId, statusOrPayload) {
  const status = Number(
    typeof statusOrPayload === 'object' ? statusOrPayload?.status : statusOrPayload
  )
  if (status === 1) {
    return post(`/admin/user/enable/${nurseUserId}`)
  }
  return post(`/admin/user/disable/${nurseUserId}`)
}

/**
 * 待审核护士列表（兼容旧页面）
 */
export function getPendingAuditList(params) {
  return getNurseList({ ...params, auditStatus: 0 })
}

/**
 * 审核护士（兼容旧页面）
 */
export function auditNurse(nurseUserId, data) {
  const approvedByBool = data?.approved === true
  const approvedByStatus = Number(data?.auditStatus) === 1
  if (approvedByBool || approvedByStatus) {
    return auditPassNurse(nurseUserId)
  }
  return auditRejectNurse(nurseUserId, { remark: data?.remark || data?.rejectReason || '' })
}

/**
 * 护士统计（兼容旧页面）
 */
export async function getNurseStats() {
  const [allRes, pendingRes, approvedRes, rejectedRes, disabledRes] = await Promise.all([
    getNurseList({ pageNo: 1, pageSize: 1 }, { includeWalletBalance: false }),
    getNurseList({ pageNo: 1, pageSize: 1, auditStatus: 0 }, { includeWalletBalance: false }),
    getNurseList({ pageNo: 1, pageSize: 1, auditStatus: 1 }, { includeWalletBalance: false }),
    getNurseList({ pageNo: 1, pageSize: 1, auditStatus: 2 }, { includeWalletBalance: false }),
    getNurseList({ pageNo: 1, pageSize: 1, acceptEnabled: 0 }, { includeWalletBalance: false })
  ])
  return {
    code: 0,
    message: 'success',
    data: {
      totalCount: allRes?.data?.total || 0,
      pendingCount: pendingRes?.data?.total || 0,
      approvedCount: approvedRes?.data?.total || 0,
      rejectedCount: rejectedRes?.data?.total || 0,
      disabledCount: disabledRes?.data?.total || 0
    }
  }
}

/**
 * 护士位置列表（兼容旧页面）
 */
export function getNurseLocations(params) {
  return getNurseList(
    { ...params, pageNo: 1, pageSize: 1000, auditStatus: 1 },
    { includeWalletBalance: false }
  )
    .then(async (res) => {
      const records = res?.data?.records || []
      const locationResults = await Promise.allSettled(
        records.map((item) => getNurseLatestLocation(item.userId))
      )
      const data = records.map((item, index) => {
        const locationRes = locationResults[index]
        const location = locationRes?.status === 'fulfilled' ? locationRes.value?.data : null
        const hasLocation = Boolean(location?.longitude && location?.latitude)
        return {
          ...item,
          phone:
            item.phone || item.mobile || item.contactPhone || item.userPhone || '',
          status: hasLocation ? (Number(item.workMode) === 1 ? 1 : 3) : 0,
          locationLng: Number(location?.longitude || 0),
          locationLat: Number(location?.latitude || 0),
          locationUpdateTime: location?.reportTime || null,
          completedOrders: item.completedOrders || 0,
          hospitalName: item.serviceArea || item.hospital || ''
        }
      })
      return { code: 0, message: 'success', data }
    })
}
