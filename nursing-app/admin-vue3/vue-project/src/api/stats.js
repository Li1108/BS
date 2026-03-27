/**
 * 统计数据 API
 */
import { get } from '@/utils/request'

function formatDate(date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

/**
 * 获取控制台统计数据（Dashboard）
 */
export async function getDashboardStats() {
  const today = formatDate(new Date())
  const [dashboardRes, incomeRes, todayIncomeRes, pendingWithdrawRes] = await Promise.all([
    get('/admin/stat/dashboard'),
    get('/admin/stat/incomeSummary'),
    get('/admin/stat/incomeSummary', { startDate: today, endDate: today }),
    get('/admin/withdraw/list', { status: 0, pageNo: 1, pageSize: 1 })
  ])
  const dashboard = dashboardRes?.data || {}
  const income = incomeRes?.data || {}
  const todayIncomeFromApi = Number(todayIncomeRes?.data?.totalIncome || 0)
  const pendingWithdrawTotal = pendingWithdrawRes?.data?.total || 0

  const resolvedTodayIncome = Number.isFinite(todayIncomeFromApi)
    ? todayIncomeFromApi
    : Number(income.todayIncome || income.todayAmount || 0)

  return {
    code: 0,
    message: 'success',
    data: {
      todayOrders: Number(dashboard.todayOrders || 0),
      totalOrders: Number(dashboard.totalOrders || 0),
      totalUsers: Number(dashboard.totalUsers || 0),
      totalNurses: Number(dashboard.totalNurses || 0),
      pendingAudit: Number(dashboard.pendingNurses || 0),
      pendingWithdrawals: Number(pendingWithdrawTotal),
      todayIncome: resolvedTodayIncome,
      totalIncome: Number(income.totalIncome || 0)
    }
  }
}

/**
 * 获取各状态订单数量统计
 */
export function getOrderCountByStatus() {
  return get('/admin/stat/orderCountByStatus')
}

/**
 * 获取收入汇总统计
 * @param {Object} params - 查询参数 { startDate, endDate }
 */
export function getIncomeSummary(params) {
  return get('/admin/stat/incomeSummary', params)
}

export function getRealtimeOverview() {
  return get('/admin/stat/overviewRealtime')
}

export function getOrderFunnel(params) {
  return get('/admin/stat/orderFunnel', params)
}

export function getNursePerformance(params) {
  return get('/admin/stat/nursePerformance', params)
}

export function getOrderHeatmap(params) {
  return get('/admin/stat/orderHeatmap', params)
}

/**
 * 获取数据看板统计
 */
export async function getDataDashboardStats() {
  const today = formatDate(new Date())
  const [
    dashboardRes,
    orderCountRes,
    totalIncomeRes,
    todayIncomeRes,
    activeNurseRes,
    evaluationRes
  ] = await Promise.all([
    get('/admin/stat/dashboard'),
    get('/admin/stat/orderCountByStatus'),
    get('/admin/stat/incomeSummary'),
    get('/admin/stat/incomeSummary', { startDate: today, endDate: today }),
    get('/admin/nurse/list', { pageNo: 1, pageSize: 1, auditStatus: 1, acceptEnabled: 1 }),
    get('/admin/evaluation/list', { pageNo: 1, pageSize: 1000 })
  ])

  const dashboard = dashboardRes?.data || {}
  const statusMap = orderCountRes?.data || {}
  const totalIncomeData = totalIncomeRes?.data || {}
  const todayIncomeData = todayIncomeRes?.data || {}
  const activeNurses = Number(activeNurseRes?.data?.total || 0)
  const evaluationRecords = evaluationRes?.data?.records || []

  const avgRating = evaluationRecords.length
    ? Number(
      (
        evaluationRecords.reduce((sum, item) => sum + (Number(item.rating) || 0), 0)
        / evaluationRecords.length
      ).toFixed(1)
    )
    : 0

  const orderStatusList = Object.entries(statusMap).map(([name, count]) => ({
    name,
    count: Number(count || 0)
  }))

  const todayIncome = Number(todayIncomeData.totalIncome || 0)
  const totalIncome = Number(totalIncomeData.totalIncome || 0)

  return {
    code: 0,
    message: 'success',
    data: {
      todayOrders: Number(dashboard.todayOrders || 0),
      totalOrders: Number(dashboard.totalOrders || 0),
      pendingOrders: Number(dashboard.pendingOrders || 0),
      totalUsers: Number(dashboard.totalUsers || 0),
      totalNurses: Number(dashboard.totalNurses || 0),
      pendingNurses: Number(dashboard.pendingNurses || 0),
      activeNurses,
      todayIncome,
      totalIncome,
      avgRating,
      orderStatusList
    }
  }
}
