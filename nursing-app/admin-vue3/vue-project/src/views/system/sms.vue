<script setup>
import { onMounted, reactive, ref } from 'vue'
import { getSmsRecordList, getSmsStats } from '@/api/sms'
import { useResponsive } from '@/composables/useResponsive'

const { tableConfig, searchFormInline, buttonSize } = useResponsive()

const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  phone: '',
  usedFlag: '',
  startDate: '',
  endDate: ''
})

const dateRange = ref([])
const loading = ref(false)
const tableData = ref([])
const total = ref(0)
const stats = ref({ total: 0, todayTotal: 0, todayUsed: 0, todayUnused: 0, todayUseRate: 0 })

const buildParams = () => {
  const params = { ...queryParams }
  Object.keys(params).forEach((k) => {
    if (params[k] === '' || params[k] == null) {
      delete params[k]
    }
  })
  return params
}

const loadData = async () => {
  loading.value = true
  try {
    const [listRes, statsRes] = await Promise.all([
      getSmsRecordList(buildParams()),
      getSmsStats()
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
    pageNo: 1,
    pageSize: 10,
    phone: '',
    usedFlag: '',
    startDate: '',
    endDate: ''
  })
  dateRange.value = []
  loadData()
}

const handleDateChange = (val) => {
  if (val?.length === 2) {
    queryParams.startDate = val[0]
    queryParams.endDate = val[1]
  } else {
    queryParams.startDate = ''
    queryParams.endDate = ''
  }
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
  <div class="sms-container">
    <el-card shadow="never">
      <template #header>
        <span>短信记录查询</span>
      </template>

      <div class="summary-row">
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">累计发送</div>
          <div class="summary-value">{{ stats.total }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">今日发送</div>
          <div class="summary-value">{{ stats.todayTotal }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">今日已使用</div>
          <div class="summary-value">{{ stats.todayUsed }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">今日使用率</div>
          <div class="summary-value">{{ (Number(stats.todayUseRate || 0) * 100).toFixed(1) }}%</div>
        </el-card>
      </div>

      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="手机号">
          <el-input v-model="queryParams.phone" clearable placeholder="输入手机号" />
        </el-form-item>
        <el-form-item label="使用状态">
          <el-select v-model="queryParams.usedFlag" clearable placeholder="全部">
            <el-option :value="0" label="未使用" />
            <el-option :value="1" label="已使用" />
          </el-select>
        </el-form-item>
        <el-form-item label="发送时间">
          <el-date-picker
            v-model="dateRange"
            type="daterange"
            value-format="YYYY-MM-DD"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            @change="handleDateChange"
          />
        </el-form-item>
        <el-form-item>
          <el-button :size="buttonSize" type="primary" @click="handleSearch">搜索</el-button>
          <el-button :size="buttonSize" @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>

      <el-table :data="tableData" v-loading="loading" stripe :border="tableConfig.border">
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="phone" label="手机号" width="150" />
        <el-table-column prop="code" label="验证码" width="120" />
        <el-table-column label="使用状态" width="110">
          <template #default="{ row }">
            <el-tag :type="Number(row.usedFlag) === 1 ? 'success' : 'info'">
              {{ Number(row.usedFlag) === 1 ? '已使用' : '未使用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="expireTime" label="过期时间" width="180" />
        <el-table-column prop="createTime" label="发送时间" width="180" />
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
.search-form { margin-bottom: 16px; }
.pagination-container { margin-top: 16px; display: flex; justify-content: flex-end; }
@media (max-width: 768px) {
  .summary-row { grid-template-columns: 1fr 1fr; }
}
</style>
