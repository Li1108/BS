<script setup>
import { onMounted, reactive, ref } from 'vue'
import { getInServiceRiskList, getInServiceRiskStats } from '@/api/risk'
import { useResponsive } from '@/composables/useResponsive'

const { tableConfig, searchFormInline, buttonSize } = useResponsive()

const queryParams = reactive({
  thresholdMinutes: 120,
  pageNo: 1,
  pageSize: 10
})

const loading = ref(false)
const tableData = ref([])
const total = ref(0)
const stats = ref({ thresholdMinutes: 120, totalInService: 0, abnormalCount: 0, safeCount: 0 })

const riskTagType = (level) => {
  if (level === 'HIGH') return 'danger'
  if (level === 'MEDIUM') return 'warning'
  return 'info'
}

const formatDuration = (minutes) => {
  const m = Number(minutes || 0)
  const h = Math.floor(m / 60)
  const r = m % 60
  return `${h}小时${r}分钟`
}

const loadData = async () => {
  loading.value = true
  try {
    const [listRes, statsRes] = await Promise.all([
      getInServiceRiskList(queryParams),
      getInServiceRiskStats({ thresholdMinutes: queryParams.thresholdMinutes })
    ])
    const page = listRes?.data || {}
    tableData.value = page.records || []
    total.value = page.total || 0
    stats.value = statsRes?.data || stats.value
  } finally {
    loading.value = false
  }
}

const handleSearch = () => {
  queryParams.pageNo = 1
  loadData()
}

const handleReset = () => {
  Object.assign(queryParams, {
    thresholdMinutes: 120,
    pageNo: 1,
    pageSize: 10
  })
  loadData()
}

const handlePageChange = (page) => {
  queryParams.pageNo = page
  loadData()
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="risk-orders-container">
    <el-card shadow="never">
      <template #header>
        <span>异常订单检测（服务中超时）</span>
      </template>

      <div class="summary-row">
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">阈值（分钟）</div>
          <div class="summary-value">{{ stats.thresholdMinutes }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">服务中总数</div>
          <div class="summary-value">{{ stats.totalInService }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">异常订单数</div>
          <div class="summary-value danger">{{ stats.abnormalCount }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">安全订单数</div>
          <div class="summary-value success">{{ stats.safeCount }}</div>
        </el-card>
      </div>

      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="超时阈值">
          <el-input-number v-model="queryParams.thresholdMinutes" :min="30" :max="1440" :step="30" />
        </el-form-item>
        <el-form-item>
          <el-button :size="buttonSize" type="primary" @click="handleSearch">刷新</el-button>
          <el-button :size="buttonSize" @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>

      <el-table :data="tableData" v-loading="loading" stripe :border="tableConfig.border">
        <el-table-column prop="orderNo" label="订单号" width="180" />
        <el-table-column prop="userPhone" label="用户手机号" width="140" />
        <el-table-column prop="nursePhone" label="护士手机号" width="140" />
        <el-table-column prop="startTime" label="开始服务时间" width="180" />
        <el-table-column label="服务中时长" width="140">
          <template #default="{ row }">{{ formatDuration(row.inServiceMinutes) }}</template>
        </el-table-column>
        <el-table-column label="风险等级" width="100">
          <template #default="{ row }">
            <el-tag :type="riskTagType(row.riskLevel)">{{ row.riskLevel || '-' }}</el-tag>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-container">
        <el-pagination
          v-model:current-page="queryParams.pageNo"
          :page-size="queryParams.pageSize"
          :page-sizes="tableConfig.pageSizes"
          :total="total"
          :layout="tableConfig.paginationLayout"
          @size-change="(size) => { queryParams.pageSize = size; queryParams.pageNo = 1; loadData() }"
          @current-change="handlePageChange"
        />
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.summary-row {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}
.summary-card { min-height: 88px; }
.summary-title { color: var(--el-text-color-secondary); font-size: 13px; }
.summary-value { margin-top: 10px; font-size: 24px; font-weight: 700; }
.summary-value.danger { color: var(--el-color-danger); }
.summary-value.success { color: var(--el-color-success); }
.search-form { margin-bottom: 16px; }
.pagination-container { margin-top: 16px; display: flex; justify-content: flex-end; }

@media (max-width: 768px) {
  .summary-row { grid-template-columns: 1fr 1fr; }
}
</style>
