<script setup>
/**
 * 操作日志页面
 * 功能：ElTable展示系统操作日志，支持按操作类型、操作人、时间范围筛选
 * 基于数据库设计：operation_logs表 (user_id, action_type, description, ip_address, user_agent, created_at)
 * 集成VueUse实现响应式设计
 */
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getOperationLogs } from '@/api/system'
import { useResponsive } from '@/composables/useResponsive'

// 响应式设计
const { isMobile, tableConfig, dialogWidth, gutter, cardColSpan, searchFormInline } = useResponsive()

// ==================== 常量定义 ====================

// 操作类型配置
const ACTION_TYPES = [
  { label: '取消订单', value: 'CANCEL_ORDER', color: '#409eff', icon: 'Document' },
  { label: '订单退款', value: 'REFUND_ORDER', color: '#67c23a', icon: 'DocumentChecked' },
  { label: '护士审核通过', value: 'AUDIT_NURSE_PASS', color: '#67c23a', icon: 'UserFilled' },
  { label: '护士审核拒绝', value: 'AUDIT_NURSE_REJECT', color: '#f56c6c', icon: 'UserFilled' },
  { label: '提现审核通过', value: 'APPROVE_WITHDRAWAL', color: '#409eff', icon: 'Wallet' },
  { label: '提现审核拒绝', value: 'REJECT_WITHDRAWAL', color: '#e6a23c', icon: 'Wallet' },
  { label: '确认打款', value: 'PAY_WITHDRAWAL', color: '#67c23a', icon: 'Wallet' },
  { label: '服务管理', value: 'ADD_SERVICE_ITEM', color: '#52c41a', icon: 'Box' },
  { label: '配置更新', value: 'UPDATE_CONFIG', color: '#909399', icon: 'Setting' },
  { label: '发送通知', value: 'SEND_NOTIFICATION', color: '#606266', icon: 'Bell' }
]

// ==================== 状态定义 ====================

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 20,
  actionType: '',
  userId: '',
  keyword: '',
  startDate: '',
  endDate: ''
})

// 日期范围
const dateRange = ref([])

// 数据
const tableData = ref([])
const total = ref(0)
const loading = ref(false)

// 统计数据
const statsData = ref({
  todayCount: 0,
  weekCount: 0,
  monthCount: 0,
  topActions: []
})

// 详情弹窗
const detailDialogVisible = ref(false)
const currentLog = ref(null)

// 高级搜索展开
const advancedSearchVisible = ref(false)

// ==================== 计算属性 ====================

// 操作类型选项
const actionTypeOptions = computed(() => ACTION_TYPES)

// 获取操作类型配置
const getActionTypeConfig = (type) => {
  return ACTION_TYPES.find(item => item.value === type) || {
    label: type,
    color: '#909399',
    icon: 'Document'
  }
}

// ==================== 方法定义 ====================

/**
 * 加载日志列表
 */
const loadData = async () => {
  loading.value = true
  try {
    const res = await getOperationLogs(queryParams)
    tableData.value = res.data.records || []
    total.value = res.data.total || 0
    
    // 加载统计数据
    if (res.data.stats) {
      statsData.value = res.data.stats
    }
  } catch (error) {
    console.error('加载日志失败:', error)
    ElMessage.error('加载日志失败')
  } finally {
    loading.value = false
  }
}

/**
 * 搜索
 */
const handleSearch = () => {
  queryParams.page = 1
  loadData()
}

/**
 * 重置查询条件
 */
const handleReset = () => {
  Object.assign(queryParams, {
    page: 1,
    pageSize: 20,
    actionType: '',
    userId: '',
    keyword: '',
    startDate: '',
    endDate: ''
  })
  dateRange.value = []
  loadData()
}

/**
 * 日期范围变化
 */
const handleDateRangeChange = (val) => {
  if (val && val.length === 2) {
    queryParams.startDate = val[0]
    queryParams.endDate = val[1]
  } else {
    queryParams.startDate = ''
    queryParams.endDate = ''
  }
}

/**
 * 分页-页码变化
 */
const handlePageChange = (page) => {
  queryParams.page = page
  loadData()
}

/**
 * 分页-每页条数变化
 */
const handleSizeChange = (size) => {
  queryParams.pageSize = size
  queryParams.page = 1
  loadData()
}

/**
 * 查看详情
 */
const handleViewDetail = (row) => {
  currentLog.value = row
  detailDialogVisible.value = true
}

/**
 * 快速筛选-今天
 */
const handleQuickFilterToday = () => {
  const today = new Date().toISOString().split('T')[0]
  dateRange.value = [today, today]
  handleDateRangeChange(dateRange.value)
  queryParams.page = 1
  loadData()
}

/**
 * 快速筛选-本周
 */
const handleQuickFilterWeek = () => {
  const today = new Date()
  const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000)
  dateRange.value = [
    weekAgo.toISOString().split('T')[0],
    today.toISOString().split('T')[0]
  ]
  handleDateRangeChange(dateRange.value)
  queryParams.page = 1
  loadData()
}

/**
 * 快速筛选-按类型
 */
const handleQuickFilterType = (type) => {
  queryParams.actionType = type
  queryParams.page = 1
  loadData()
}

/**
 * 导出日志
 */
const handleExport = async () => {
  try {
    await ElMessageBox.confirm(
      '确定导出当前筛选条件下的所有日志吗？',
      '导出确认',
      {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )
    
    const headers = ['日志ID', '操作人', '操作类型', '操作描述', 'IP地址', '请求路径', '请求方法', '操作时间']
    const rows = tableData.value.map(item => [
      item.id,
      item.userName || '',
      item.actionType || '',
      item.description || '',
      item.ipAddress || '',
      item.requestPath || '',
      item.requestMethod || '',
      formatTime(item.createdAt)
    ])
    const csvContent = [headers, ...rows]
      .map(row => row.map(col => `"${String(col ?? '').replace(/"/g, '""')}"`).join(','))
      .join('\n')
    const blob = new Blob([`\uFEFF${csvContent}`], { type: 'text/csv;charset=utf-8;' })
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `操作日志_${new Date().toISOString().slice(0, 10)}.csv`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    ElMessage.success('导出成功')
  } catch {
    // 取消操作
  }
}

/**
 * 格式化时间
 */
const formatTime = (time) => {
  if (!time) return '-'
  return new Date(time).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })
}

/**
 * 获取浏览器信息
 */
const getBrowserInfo = (userAgent) => {
  if (!userAgent) return '未知'
  
  if (userAgent.includes('Chrome')) return 'Chrome'
  if (userAgent.includes('Firefox')) return 'Firefox'
  if (userAgent.includes('Safari')) return 'Safari'
  if (userAgent.includes('Edge')) return 'Edge'
  if (userAgent.includes('IE')) return 'IE'
  
  return '其他'
}

/**
 * 复制内容
 */
const copyToClipboard = async (text) => {
  try {
    await navigator.clipboard.writeText(text)
    ElMessage.success('已复制到剪贴板')
  } catch {
    ElMessage.error('复制失败')
  }
}

// ==================== 生命周期 ====================

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="logs-container">
    <!-- 统计卡片 -->
    <el-row :gutter="gutter" class="stats-row">
      <el-col :xs="12" :sm="6">
        <el-card shadow="hover" class="stat-card stat-card-clickable" @click="handleQuickFilterToday">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #409eff;">
              <el-icon :size="24"><Calendar /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.todayCount || 0 }}</p>
              <p class="stat-label">今日操作</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="12" :sm="6">
        <el-card shadow="hover" class="stat-card stat-card-clickable" @click="handleQuickFilterWeek">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #67c23a;">
              <el-icon :size="24"><TrendCharts /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.weekCount || 0 }}</p>
              <p class="stat-label">本周操作</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="12" :sm="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #e6a23c;">
              <el-icon :size="24"><DataLine /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.monthCount || 0 }}</p>
              <p class="stat-label">本月操作</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="12" :sm="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #f56c6c;">
              <el-icon :size="24"><Connection /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ total }}</p>
              <p class="stat-label">总记录数</p>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 主卡片 -->
    <el-card shadow="never" class="main-card">
      <template #header>
        <div class="card-header">
          <span class="title">操作日志</span>
          <div class="header-actions">
            <el-button size="small" @click="handleExport">
              <el-icon><Download /></el-icon>导出
            </el-button>
          </div>
        </div>
      </template>
      
      <!-- 快速筛选 -->
      <div class="quick-filters">
        <el-tag
          v-for="item in actionTypeOptions.slice(0, 5)"
          :key="item.value"
          :type="queryParams.actionType === item.value ? 'primary' : 'info'"
          effect="plain"
          class="filter-tag"
          @click="handleQuickFilterType(item.value)"
        >
          {{ item.label }}
        </el-tag>
        <el-tag
          v-if="queryParams.actionType"
          type="info"
          class="filter-tag"
          @click="queryParams.actionType = ''; loadData()"
        >
          清除筛选
        </el-tag>
      </div>
      
      <!-- 搜索栏 -->
      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="关键词">
          <el-input 
            v-model="queryParams.keyword" 
            placeholder="操作描述/IP地址" 
            clearable 
            style="width: 180px;"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="操作类型">
          <el-select 
            v-model="queryParams.actionType" 
            placeholder="全部类型" 
            clearable 
            style="width: 140px;"
          >
            <el-option
              v-for="item in actionTypeOptions"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="时间范围">
          <el-date-picker
            v-model="dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
            style="width: 240px;"
            @change="handleDateRangeChange"
          />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSearch">
            <el-icon><Search /></el-icon>搜索
          </el-button>
          <el-button @click="handleReset">
            <el-icon><Refresh /></el-icon>重置
          </el-button>
        </el-form-item>
      </el-form>
      
      <!-- 数据表格 -->
      <el-table 
        :data="tableData" 
        v-loading="loading" 
        stripe 
        :border="tableConfig.border"
        row-key="id"
      >
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="userName" label="操作人" width="120">
          <template #default="{ row }">
            <div class="user-info">
              <el-avatar :size="28">{{ row.userName?.charAt(0) }}</el-avatar>
              <span>{{ row.userName }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="actionType" label="操作类型" width="120" align="center">
          <template #default="{ row }">
            <el-tag :color="getActionTypeConfig(row.actionType).color" effect="light">
              {{ getActionTypeConfig(row.actionType).label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="操作描述" min-width="250" show-overflow-tooltip />
        <el-table-column prop="ipAddress" label="IP地址" width="140">
          <template #default="{ row }">
            <span>{{ row.ipAddress || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="userAgent" label="浏览器" width="100">
          <template #default="{ row }">
            <el-tag size="small" type="info" effect="plain">
              {{ getBrowserInfo(row.userAgent) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="操作时间" width="170">
          <template #default="{ row }">
            {{ formatTime(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="handleViewDetail(row)">
              <el-icon><View /></el-icon>详情
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      
      <!-- 分页 -->
      <div class="pagination-container">
        <el-pagination
          v-model:current-page="queryParams.page"
          v-model:page-size="queryParams.pageSize"
          :page-sizes="tableConfig.pageSizes"
          :total="total"
          :layout="tableConfig.paginationLayout"
          @size-change="handleSizeChange"
          @current-change="handlePageChange"
        />
      </div>
    </el-card>

    <!-- 详情弹窗 -->
    <el-dialog 
      v-model="detailDialogVisible" 
      title="日志详情" 
      width="600px"
      destroy-on-close
    >
      <template v-if="currentLog">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="日志ID">
            {{ currentLog.id }}
          </el-descriptions-item>
          <el-descriptions-item label="操作人">
            <div class="user-info">
              <el-avatar :size="24">{{ currentLog.userName?.charAt(0) }}</el-avatar>
              <span>{{ currentLog.userName }}</span>
              <span class="text-muted">(ID: {{ currentLog.userId }})</span>
            </div>
          </el-descriptions-item>
          <el-descriptions-item label="操作类型">
            <el-tag :color="getActionTypeConfig(currentLog.actionType).color" effect="light">
              {{ getActionTypeConfig(currentLog.actionType).label }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="操作描述">
            {{ currentLog.description }}
          </el-descriptions-item>
          <el-descriptions-item label="IP地址">
            <span>{{ currentLog.ipAddress || '-' }}</span>
            <el-button 
              v-if="currentLog.ipAddress"
              type="primary" 
              link 
              size="small"
              @click="copyToClipboard(currentLog.ipAddress)"
            >
              <el-icon><CopyDocument /></el-icon>
            </el-button>
          </el-descriptions-item>
          <el-descriptions-item label="User Agent">
            <div style="word-break: break-all; font-size: 12px; color: #606266;">
              {{ currentLog.userAgent || '-' }}
            </div>
          </el-descriptions-item>
          <el-descriptions-item label="浏览器">
            {{ getBrowserInfo(currentLog.userAgent) }}
          </el-descriptions-item>
          <el-descriptions-item label="操作时间">
            {{ formatTime(currentLog.createdAt) }}
          </el-descriptions-item>
        </el-descriptions>
      </template>
      
      <template #footer>
        <el-button @click="detailDialogVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.logs-container {
  padding: 0;
}

/* 统计卡片 */
.stats-row {
  margin-bottom: 16px;
}

.stat-card {
  transition: all 0.3s;
}

.stat-card-clickable {
  cursor: pointer;
}

.stat-card-clickable:hover {
  transform: translateY(-2px);
}

.stat-content {
  display: flex;
  align-items: center;
}

.stat-icon {
  width: 48px;
  height: 48px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  flex-shrink: 0;
}

.stat-info {
  margin-left: 12px;
}

.stat-value {
  font-size: 20px;
  font-weight: bold;
  color: #303133;
  line-height: 1.2;
  margin: 0;
}

.stat-label {
  font-size: 13px;
  color: #909399;
  margin: 4px 0 0;
}

/* 主卡片 */
.main-card {
  margin-top: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-header .title {
  font-size: 16px;
  font-weight: 600;
}

/* 快速筛选 */
.quick-filters {
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #ebeef5;
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.filter-tag {
  cursor: pointer;
  transition: all 0.3s;
}

.filter-tag:hover {
  transform: translateY(-2px);
}

/* 搜索表单 */
.search-form {
  margin-bottom: 16px;
}

/* 用户信息 */
.user-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.text-muted {
  color: #909399;
  font-size: 12px;
}

/* 分页 */
.pagination-container {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}

/* 响应式 */
@media (max-width: 768px) {
  .search-form :deep(.el-form-item) {
    margin-bottom: 12px;
  }
  
  .quick-filters {
    gap: 6px;
  }
}
</style>
