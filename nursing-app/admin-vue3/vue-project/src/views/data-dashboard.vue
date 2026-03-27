<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import * as echarts from 'echarts'
import { getDataDashboardStats, getOrderFunnel, getNursePerformance } from '@/api/stats'

const loading = ref(false)
const autoRefresh = ref(true)
const refreshSeconds = ref(15)
const countdown = ref(refreshSeconds.value)
const lastUpdated = ref('')

const dashboard = ref({
  todayOrders: 0,
  totalOrders: 0,
  pendingOrders: 0,
  totalUsers: 0,
  totalNurses: 0,
  pendingNurses: 0,
  activeNurses: 0,
  todayIncome: 0,
  totalIncome: 0,
  avgRating: 0,
  orderStatusList: []
})

const orderTrend = ref([])
const incomeTrend = ref([])
const activeNurseTrend = ref([])
const timeTrend = ref([])
const funnel = ref({
  placed: 0,
  dispatched: 0,
  accepted: 0,
  completed: 0,
  placedToDispatchedRate: 0,
  dispatchedToAcceptedRate: 0,
  acceptedToCompletedRate: 0,
  overallRate: 0
})
const nurseRanking = ref([])

const orderTrendRef = ref(null)
const statusPieRef = ref(null)
let orderTrendChart = null
let statusPieChart = null
let refreshTimer = null
let countdownTimer = null

const sortedStatusList = computed(() => {
  const list = Array.isArray(dashboard.value.orderStatusList)
    ? dashboard.value.orderStatusList
    : []
  return [...list].sort((a, b) => Number(b.count || 0) - Number(a.count || 0))
})

const totalStatusCount = computed(() =>
  sortedStatusList.value.reduce((sum, item) => sum + Number(item.count || 0), 0)
)

const statusTableData = computed(() =>
  sortedStatusList.value.map((item, index) => {
    const count = Number(item.count || 0)
    const total = totalStatusCount.value
    return {
      rank: index + 1,
      name: item.name,
      count,
      percent: total > 0 ? `${((count / total) * 100).toFixed(1)}%` : '0.0%'
    }
  })
)

const activeNurseRate = computed(() => {
  const total = Number(dashboard.value.totalNurses || 0)
  const active = Number(dashboard.value.activeNurses || 0)
  if (total <= 0) return '0.0%'
  return `${((active / total) * 100).toFixed(1)}%`
})

const pendingOrderRate = computed(() => {
  const total = Number(dashboard.value.totalOrders || 0)
  const pending = Number(dashboard.value.pendingOrders || 0)
  if (total <= 0) return '0.0%'
  return `${((pending / total) * 100).toFixed(1)}%`
})

function formatMoney(value) {
  return Number(value || 0).toFixed(2)
}

function updateTrendSeries(data) {
  const nowLabel = new Date().toLocaleTimeString()
  const maxPoints = 20

  timeTrend.value = [...timeTrend.value, nowLabel].slice(-maxPoints)
  orderTrend.value = [...orderTrend.value, Number(data.todayOrders || 0)].slice(-maxPoints)
  incomeTrend.value = [...incomeTrend.value, Number(data.todayIncome || 0)].slice(-maxPoints)
  activeNurseTrend.value = [...activeNurseTrend.value, Number(data.activeNurses || 0)].slice(-maxPoints)
}

function renderOrderTrendChart() {
  if (!orderTrendChart) return
  const chartWidth = orderTrendRef.value?.clientWidth || 0
  const compact = chartWidth > 0 && chartWidth < 560

  orderTrendChart.setOption({
    tooltip: { trigger: 'axis' },
    legend: {
      data: ['今日订单', '今日收入(元)', '在岗护士'],
      top: compact ? 8 : 10,
      itemWidth: compact ? 10 : 14,
      itemHeight: compact ? 8 : 10,
      textStyle: {
        fontSize: compact ? 11 : 12
      }
    },
    grid: {
      left: compact ? 8 : 24,
      right: compact ? 8 : 20,
      top: compact ? 60 : 50,
      bottom: compact ? 28 : 24,
      containLabel: true
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: timeTrend.value,
      axisLabel: {
        fontSize: compact ? 10 : 12,
        hideOverlap: true
      }
    },
    yAxis: [
      {
        type: 'value',
        name: compact ? '' : '订单/护士',
        axisLabel: {
          fontSize: compact ? 10 : 12
        }
      },
      {
        type: 'value',
        name: compact ? '' : '收入(元)',
        axisLabel: {
          fontSize: compact ? 10 : 12
        }
      }
    ],
    series: [
      {
        name: '今日订单',
        type: 'line',
        smooth: true,
        data: orderTrend.value
      },
      {
        name: '今日收入(元)',
        type: 'line',
        smooth: true,
        yAxisIndex: 1,
        data: incomeTrend.value
      },
      {
        name: '在岗护士',
        type: 'line',
        smooth: true,
        data: activeNurseTrend.value
      }
    ]
  })
}

function renderStatusPieChart() {
  if (!statusPieChart) return
  const chartWidth = statusPieRef.value?.clientWidth || 0
  const compact = chartWidth > 0 && chartWidth < 520

  statusPieChart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)'
    },
    legend: {
      type: 'scroll',
      orient: compact ? 'horizontal' : 'vertical',
      right: compact ? 'center' : 12,
      left: compact ? 'center' : 'auto',
      top: compact ? 'bottom' : 16,
      bottom: compact ? 0 : 16,
      textStyle: {
        fontSize: compact ? 11 : 12
      }
    },
    series: [
      {
        name: '订单状态',
        type: 'pie',
        radius: compact ? ['42%', '66%'] : ['40%', '68%'],
        center: compact ? ['50%', '42%'] : ['34%', '50%'],
        avoidLabelOverlap: true,
        label: {
          show: false
        },
        labelLine: {
          show: false
        },
        data: sortedStatusList.value.map(item => ({
          name: item.name,
          value: Number(item.count || 0)
        }))
      }
    ]
  })
}

function initCharts() {
  if (orderTrendRef.value && !orderTrendChart) {
    orderTrendChart = echarts.init(orderTrendRef.value)
  }
  if (statusPieRef.value && !statusPieChart) {
    statusPieChart = echarts.init(statusPieRef.value)
  }
  renderOrderTrendChart()
  renderStatusPieChart()
}

async function loadDashboardData() {
  loading.value = true
  try {
    const [res, funnelRes, rankRes] = await Promise.all([
      getDataDashboardStats(),
      getOrderFunnel(),
      getNursePerformance({ topN: 8 })
    ])
    const data = res?.data || {}
    dashboard.value = {
      todayOrders: Number(data.todayOrders || 0),
      totalOrders: Number(data.totalOrders || 0),
      pendingOrders: Number(data.pendingOrders || 0),
      totalUsers: Number(data.totalUsers || 0),
      totalNurses: Number(data.totalNurses || 0),
      pendingNurses: Number(data.pendingNurses || 0),
      activeNurses: Number(data.activeNurses || 0),
      todayIncome: Number(data.todayIncome || 0),
      totalIncome: Number(data.totalIncome || 0),
      avgRating: Number(data.avgRating || 0),
      orderStatusList: Array.isArray(data.orderStatusList) ? data.orderStatusList : []
    }
    updateTrendSeries(dashboard.value)
    funnel.value = funnelRes?.data || funnel.value
    nurseRanking.value = rankRes?.data || []
    lastUpdated.value = new Date().toLocaleString()

    await nextTick()
    initCharts()
    renderOrderTrendChart()
    renderStatusPieChart()
  } catch (error) {
    console.error('加载数据看板失败:', error)
  } finally {
    loading.value = false
  }
}

function clearTimers() {
  if (refreshTimer) {
    clearInterval(refreshTimer)
    refreshTimer = null
  }
  if (countdownTimer) {
    clearInterval(countdownTimer)
    countdownTimer = null
  }
}

function startRealtimeRefresh() {
  clearTimers()
  countdown.value = refreshSeconds.value

  refreshTimer = setInterval(async () => {
    if (!autoRefresh.value) return
    await loadDashboardData()
    countdown.value = refreshSeconds.value
  }, refreshSeconds.value * 1000)

  countdownTimer = setInterval(() => {
    if (!autoRefresh.value) return
    if (countdown.value <= 1) {
      countdown.value = refreshSeconds.value
    } else {
      countdown.value -= 1
    }
  }, 1000)
}

function toggleAutoRefresh() {
  if (autoRefresh.value) {
    startRealtimeRefresh()
  } else {
    clearTimers()
  }
}

function resizeCharts() {
  orderTrendChart?.resize()
  statusPieChart?.resize()
}

onMounted(async () => {
  await loadDashboardData()
  startRealtimeRefresh()
  window.addEventListener('resize', resizeCharts)
})

onBeforeUnmount(() => {
  clearTimers()
  window.removeEventListener('resize', resizeCharts)
  orderTrendChart?.dispose()
  statusPieChart?.dispose()
  orderTrendChart = null
  statusPieChart = null
})
</script>

<template>
  <div class="dashboard-page" v-loading="loading">
    <div class="page-header card-surface">
      <div>
        <h3 class="title">数据看板</h3>
        <p class="subtitle">实时监控订单、收入与护士服务状态</p>
      </div>
      <div class="header-right">
        <el-switch v-model="autoRefresh" active-text="实时刷新" @change="toggleAutoRefresh" />
        <el-tag v-if="autoRefresh" type="success">{{ countdown }}s 后自动刷新</el-tag>
        <el-button type="primary" @click="loadDashboardData">立即刷新</el-button>
      </div>
    </div>

    <div class="overview-grid">
      <div class="hero-panel card-surface">
        <div class="hero-title">运营总览</div>
        <div class="hero-subtitle">最近刷新：{{ lastUpdated || '未刷新' }}</div>
        <div class="hero-main">
          <div class="hero-value">¥{{ formatMoney(dashboard.todayIncome) }}</div>
          <div class="hero-label">今日收入</div>
        </div>
        <div class="hero-foot">
          <span>总收入：¥{{ formatMoney(dashboard.totalIncome) }}</span>
          <span>今日订单：{{ dashboard.todayOrders }}</span>
        </div>
      </div>

      <div class="snapshot-grid">
        <el-card shadow="never" class="snapshot-card">
          <div class="snapshot-title">订单池</div>
          <div class="snapshot-value">{{ dashboard.totalOrders }}</div>
          <div class="snapshot-desc">待处理占比 {{ pendingOrderRate }}</div>
        </el-card>
        <el-card shadow="never" class="snapshot-card">
          <div class="snapshot-title">护士资源</div>
          <div class="snapshot-value">{{ dashboard.totalNurses }}</div>
          <div class="snapshot-desc">在岗占比 {{ activeNurseRate }}</div>
        </el-card>
        <el-card shadow="never" class="snapshot-card">
          <div class="snapshot-title">用户规模</div>
          <div class="snapshot-value">{{ dashboard.totalUsers }}</div>
          <div class="snapshot-desc">平台服务用户总量</div>
        </el-card>
        <el-card shadow="never" class="snapshot-card">
          <div class="snapshot-title">服务评分</div>
          <div class="snapshot-value">{{ dashboard.avgRating.toFixed(1) }}</div>
          <div class="snapshot-desc">综合满意度</div>
        </el-card>
      </div>
    </div>

    <div class="section-title">核心指标</div>
    <div class="kpi-grid">
      <el-card shadow="never" class="kpi-card"><div class="kpi-title">今日订单</div><div class="kpi-value">{{ dashboard.todayOrders }}</div></el-card>
      <el-card shadow="never" class="kpi-card"><div class="kpi-title">待处理订单</div><div class="kpi-value">{{ dashboard.pendingOrders }}</div></el-card>
      <el-card shadow="never" class="kpi-card"><div class="kpi-title">今日收入(元)</div><div class="kpi-value">{{ formatMoney(dashboard.todayIncome) }}</div></el-card>
      <el-card shadow="never" class="kpi-card"><div class="kpi-title">总收入(元)</div><div class="kpi-value">{{ formatMoney(dashboard.totalIncome) }}</div></el-card>
      <el-card shadow="never" class="kpi-card"><div class="kpi-title">在岗护士</div><div class="kpi-value">{{ dashboard.activeNurses }}</div></el-card>
      <el-card shadow="never" class="kpi-card"><div class="kpi-title">待审核护士</div><div class="kpi-value">{{ dashboard.pendingNurses }}</div></el-card>
    </div>

    <div class="section-title">趋势与状态明细</div>
    <div class="chart-grid">
      <el-card shadow="never" class="chart-card trend-card">
        <template #header><span>实时趋势</span></template>
        <div ref="orderTrendRef" class="chart-box" />
      </el-card>
      <el-card shadow="never" class="chart-card status-card">
        <template #header><span>订单状态分布</span></template>
        <div class="status-layout">
          <div ref="statusPieRef" class="chart-box status-pie" />
          <el-table
            :data="statusTableData"
            class="status-table"
            stripe
            size="small"
            height="360"
          >
            <el-table-column prop="rank" label="#" width="56" align="center" class-name="rank-col" />
            <el-table-column prop="name" label="状态" min-width="120" />
            <el-table-column prop="count" label="数量" width="90" align="right" />
            <el-table-column prop="percent" label="占比" width="90" align="right" />
          </el-table>
        </div>
      </el-card>
    </div>

    <div class="section-title">订单漏斗与护士绩效</div>
    <div class="chart-grid">
      <el-card shadow="never" class="chart-card">
        <template #header><span>订单漏斗</span></template>
        <el-descriptions :column="2" border>
          <el-descriptions-item label="下单">{{ funnel.placed }}</el-descriptions-item>
          <el-descriptions-item label="派单">{{ funnel.dispatched }}</el-descriptions-item>
          <el-descriptions-item label="接单">{{ funnel.accepted }}</el-descriptions-item>
          <el-descriptions-item label="完成">{{ funnel.completed }}</el-descriptions-item>
          <el-descriptions-item label="下单→派单">{{ (Number(funnel.placedToDispatchedRate || 0) * 100).toFixed(1) }}%</el-descriptions-item>
          <el-descriptions-item label="派单→接单">{{ (Number(funnel.dispatchedToAcceptedRate || 0) * 100).toFixed(1) }}%</el-descriptions-item>
          <el-descriptions-item label="接单→完成">{{ (Number(funnel.acceptedToCompletedRate || 0) * 100).toFixed(1) }}%</el-descriptions-item>
          <el-descriptions-item label="总体转化">{{ (Number(funnel.overallRate || 0) * 100).toFixed(1) }}%</el-descriptions-item>
        </el-descriptions>
      </el-card>

      <el-card shadow="never" class="chart-card">
        <template #header><span>护士绩效排行榜</span></template>
        <el-table :data="nurseRanking" stripe size="small" height="300">
          <el-table-column label="#" type="index" width="56" />
          <el-table-column prop="nurseName" label="护士" min-width="120" />
          <el-table-column prop="hospital" label="医院" min-width="160" show-overflow-tooltip />
          <el-table-column prop="acceptedCount" label="接单量" width="90" align="right" />
          <el-table-column label="评分" width="90" align="right">
            <template #default="{ row }">{{ Number(row.avgRating || 0).toFixed(2) }}</template>
          </el-table-column>
          <el-table-column label="综合分" width="90" align="right">
            <template #default="{ row }">{{ Number(row.compositeScore || 0).toFixed(2) }}</template>
          </el-table-column>
        </el-table>
      </el-card>
    </div>
  </div>
</template>

<style scoped>
.dashboard-page {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.card-surface {
  background: var(--el-bg-color-overlay);
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 14px;
  padding: 14px 16px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.title {
  margin: 0;
}

.subtitle {
  margin: 6px 0 0;
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 10px;
}

.overview-grid {
  display: grid;
  grid-template-columns: minmax(260px, 1fr) minmax(420px, 2fr);
  gap: 12px;
}

.hero-panel {
  background: linear-gradient(
    135deg,
    var(--el-color-primary-light-9),
    var(--el-bg-color-overlay)
  );
}

.hero-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.hero-subtitle {
  margin-top: 6px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}

.hero-main {
  margin-top: 14px;
}

.hero-value {
  font-size: clamp(24px, 3vw, 34px);
  font-weight: 700;
  line-height: 1.2;
  color: var(--el-color-primary);
}

.hero-label {
  margin-top: 4px;
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.hero-foot {
  margin-top: 14px;
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.snapshot-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.snapshot-card {
  border-radius: 12px;
}

.snapshot-card :deep(.el-card__body) {
  padding: 14px 16px;
}

.snapshot-title {
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.snapshot-value {
  margin-top: 8px;
  font-size: 26px;
  font-weight: 700;
  line-height: 1.2;
}

.snapshot-desc {
  margin-top: 6px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}

.section-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--el-text-color-primary);
  margin: 2px 0;
}

.kpi-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
  gap: 12px;
}

.kpi-title {
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.kpi-value {
  margin-top: 8px;
  font-size: 24px;
  font-weight: 700;
}

.kpi-card {
  border-radius: 12px;
}

.kpi-card :deep(.el-card__body) {
  padding: 14px 16px;
}

.chart-grid {
  display: grid;
  grid-template-columns: 1.3fr 1fr;
  gap: 12px;
}

.trend-card,
.status-card {
  min-width: 0;
}

.status-layout {
  display: grid;
  grid-template-columns: minmax(300px, 1.1fr) minmax(280px, 0.9fr);
  gap: 12px;
  align-items: stretch;
}

.chart-card {
  border-radius: 12px;
}

.chart-card :deep(.el-card__header) {
  font-weight: 600;
}

.chart-box {
  width: 100%;
  height: 360px;
}

.status-pie {
  min-height: 360px;
}

.status-table {
  width: 100%;
}

.status-table :deep(.el-table__cell) {
  padding: 8px 0;
}

@media (max-width: 1200px) {
  .overview-grid {
    grid-template-columns: 1fr;
  }

  .chart-grid {
    grid-template-columns: 1fr;
  }

  .status-layout {
    grid-template-columns: 1fr;
  }

  .status-table {
    height: auto !important;
  }
}

@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }

  .header-right {
    flex-wrap: wrap;
  }

  .snapshot-grid {
    grid-template-columns: 1fr;
  }

  .chart-box {
    height: 300px;
  }

  .status-pie {
    min-height: 300px;
  }

  .status-table :deep(.el-table__cell) {
    padding: 6px 0;
  }
}

@media (max-width: 480px) {
  :deep(.status-table .rank-col) {
    display: none;
  }

  .kpi-value {
    font-size: 20px;
  }

  .snapshot-value {
    font-size: 22px;
  }
}
</style>
