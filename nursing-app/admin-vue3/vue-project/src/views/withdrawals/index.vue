<script setup>
/**
 * 提现审核页面
 * 功能：ElTable提现申请列表，审核按钮（通过/驳回），支持审核提现申请并记录
 * 基于数据库设计：withdrawals表 (nurse_id, amount, alipay_account, real_name, status, reject_reason, audit_time)
 * 集成VueUse实现响应式设计
 */
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox, ElNotification } from 'element-plus'
import { useRouter } from 'vue-router'
import { getWithdrawalList, getWithdrawalDetail, auditWithdrawal, getWithdrawalStats, batchAuditWithdrawals, exportWithdrawalPdf } from '@/api/withdrawal'
import { useResponsive } from '@/composables/useResponsive'

// 响应式设计
const { isMobile, tableConfig, dialogWidth, gutter, cardColSpan, searchFormInline } = useResponsive()
const router = useRouter()

// ==================== 常量定义 ====================

// 状态映射
const statusMap = {
  0: { label: '待审核', type: 'warning', color: '#e6a23c' },
  1: { label: '已审核', type: 'info', color: '#909399' },
  2: { label: '已驳回', type: 'danger', color: '#f56c6c' },
  3: { label: '已打款', type: 'success', color: '#67c23a' }
}

// ==================== 状态定义 ====================

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 10,
  status: '',
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
  totalAmount: 0,
  pendingCount: 0,
  pendingAmount: 0,
  approvedCount: 0,
  approvedAmount: 0,
  rejectedCount: 0
})

// 详情弹窗
const detailDialogVisible = ref(false)
const currentWithdrawal = ref(null)
const detailLoading = ref(false)

// 审核操作加载
const auditLoading = ref(false)
const exportLoading = ref(false)

// 选中的记录
const selectedRows = ref([])

// ==================== 计算属性 ====================

// 状态选项
const statusOptions = computed(() => {
  return Object.entries(statusMap).map(([value, item]) => ({
    value: Number(value),
    label: item.label
  }))
})

// 是否可批量审核
const canBatchAudit = computed(() => {
  return selectedRows.value.length > 0 && 
         selectedRows.value.every(row => row.status === 0)
})

// ==================== 方法定义 ====================

/**
 * 加载提现列表数据
 */
const loadData = async () => {
  loading.value = true
  try {
    const res = await getWithdrawalList(queryParams)
    tableData.value = res.data.records || []
    total.value = res.data.total || 0
  } catch (error) {
    console.error('加载提现列表失败:', error)
    ElMessage.error('加载数据失败')
  } finally {
    loading.value = false
  }
}

/**
 * 加载统计数据
 */
const loadStats = async () => {
  try {
    const res = await getWithdrawalStats()
    statsData.value = res.data
  } catch (error) {
    console.error('加载统计数据失败:', error)
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
    pageSize: 10,
    status: '',
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
 * 表格选择变化
 */
const handleSelectionChange = (selection) => {
  selectedRows.value = selection
}

/**
 * 查看详情
 */
const handleViewDetail = async (row) => {
  detailLoading.value = true
  detailDialogVisible.value = true
  try {
    const res = await getWithdrawalDetail(row.id)
    currentWithdrawal.value = res.data
  } catch (error) {
    currentWithdrawal.value = row
  } finally {
    detailLoading.value = false
  }
}

/**
 * 审核通过
 */
const handleApprove = async (row) => {
  try {
    await ElMessageBox.confirm(
      `确定已完成线下打款并通过审核吗？\n\n护士：${row.nurseName}\n金额：¥${row.amount?.toFixed(2)}\n支付宝：${row.alipayAccount}`,
      '审核确认',
      {
        confirmButtonText: '确认已打款',
        cancelButtonText: '取消',
        type: 'warning',
        dangerouslyUseHTMLString: false
      }
    )
    
    auditLoading.value = true
    await auditWithdrawal(row.id, { status: 3 })
    
    ElNotification({
      title: '审核成功',
      message: `护士【${row.nurseName}】的提现申请已通过，金额¥${row.amount?.toFixed(2)}`,
      type: 'success',
      duration: 3000
    })
    
    detailDialogVisible.value = false
    loadData()
    loadStats()
  } catch (error) {
    if (error !== 'cancel') {
      if (!error?.__handled) {
        ElMessage.error(error?.message || '审核操作失败')
      }
    }
  } finally {
    auditLoading.value = false
  }
}

/**
 * 审核驳回
 */
const handleReject = async (row) => {
  try {
    const { value } = await ElMessageBox.prompt(
      '请输入驳回原因，该原因将通知给护士',
      '驳回提现申请',
      {
        confirmButtonText: '确定驳回',
        cancelButtonText: '取消',
        inputPlaceholder: '请输入驳回原因...',
        inputPattern: /.{2,}/,
        inputErrorMessage: '请输入至少2个字符的驳回原因',
        type: 'warning'
      }
    )
    
    auditLoading.value = true
    await auditWithdrawal(row.id, { status: 2, rejectReason: value })
    
    ElNotification({
      title: '操作成功',
      message: `已驳回护士【${row.nurseName}】的提现申请`,
      type: 'warning',
      duration: 3000
    })
    
    detailDialogVisible.value = false
    loadData()
    loadStats()
  } catch (error) {
    if (error !== 'cancel') {
      if (!error?.__handled) {
        ElMessage.error(error?.message || '审核操作失败')
      }
    }
  } finally {
    auditLoading.value = false
  }
}

/**
 * 批量审核通过
 */
const handleBatchApprove = async () => {
  if (!canBatchAudit.value) return
  
  const totalAmount = selectedRows.value.reduce((sum, row) => sum + (row.amount || 0), 0)
  
  try {
    await ElMessageBox.confirm(
      `确定批量通过${selectedRows.value.length}条提现申请吗？\n总金额：¥${totalAmount.toFixed(2)}\n\n请确保已完成线下打款！`,
      '批量审核确认',
      {
        confirmButtonText: '确认批量通过',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )
    
    auditLoading.value = true
    
    await batchAuditWithdrawals({
      action: 'pay',
      ids: selectedRows.value.map(item => item.id),
      remark: '批量线下打款确认'
    })
    
    ElMessage.success(`已批量通过${selectedRows.value.length}条提现申请`)
    loadData()
    loadStats()
  } catch (error) {
    if (error !== 'cancel') {
      if (!error?.__handled) {
        ElMessage.error(error?.message || '批量审核失败')
      }
    }
  } finally {
    auditLoading.value = false
  }
}

/**
 * 导出 PDF 报表
 */
const handleExportPdf = async () => {
  try {
    await ElMessageBox.confirm(
      '确定导出当前筛选条件下的提现PDF报表吗？',
      '导出确认',
      {
        confirmButtonText: '导出',
        cancelButtonText: '取消',
        type: 'info'
      }
    )

    exportLoading.value = true
    const blob = await exportWithdrawalPdf(queryParams)
    const url = window.URL.createObjectURL(new Blob([blob], { type: 'application/pdf' }))
    const link = document.createElement('a')
    const dateStr = new Date().toISOString().slice(0, 10)
    link.href = url
    link.download = `提现财务报表_${dateStr}.pdf`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)

    ElMessage.success('PDF报表导出成功')
  } catch (error) {
    if (error !== 'cancel') {
      if (!error?.__handled) {
        ElMessage.error(error?.message || '导出失败，请稍后重试')
      }
    }
  } finally {
    exportLoading.value = false
  }
}

/**
 * 快速筛选-待审核
 */
const handleQuickFilterPending = () => {
  queryParams.status = 0
  queryParams.page = 1
  loadData()
}

/**
 * 格式化金额
 */
const formatAmount = (amount) => {
  return amount ? `¥${Number(amount).toFixed(2)}` : '¥0.00'
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
    minute: '2-digit'
  })
}

/**
 * 复制到剪贴板
 */
const copyToClipboard = async (text) => {
  try {
    await navigator.clipboard.writeText(text)
    ElMessage.success('已复制到剪贴板')
  } catch {
    ElMessage.error('复制失败')
  }
}

const goNurseDetail = (row) => {
  const keyword = String(row?.nursePhone || row?.nurseName || '').trim()
  if (!keyword) {
    ElMessage.warning('护士信息不足，无法跳转')
    return
  }
  router.push({ path: '/nurses/list', query: { keyword } })
}

// ==================== 生命周期 ====================

onMounted(() => {
  loadData()
  loadStats()
})
</script>

<template>
  <div class="withdrawals-container">
    <!-- 统计卡片 -->
    <el-row :gutter="gutter" class="stats-row">
      <el-col :xs="12" :sm="6">
        <el-card shadow="hover" class="stat-card stat-card-clickable" @click="handleQuickFilterPending">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #e6a23c;">
              <el-icon :size="24"><Clock /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.pendingCount || 0 }}</p>
              <p class="stat-label">待审核</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="12" :sm="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #f56c6c;">
              <el-icon :size="24"><Money /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ formatAmount(statsData.pendingAmount) }}</p>
              <p class="stat-label">待处理金额</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="12" :sm="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #67c23a;">
              <el-icon :size="24"><CircleCheck /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.approvedCount || 0 }}</p>
              <p class="stat-label">已打款</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="12" :sm="6">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #409eff;">
              <el-icon :size="24"><Wallet /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ formatAmount(statsData.approvedAmount) }}</p>
              <p class="stat-label">累计打款</p>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 主卡片 -->
    <el-card shadow="never" class="main-card">
      <template #header>
        <div class="card-header">
          <span class="title">提现审核</span>
          <div class="header-actions">
            <el-button
              :loading="exportLoading"
              @click="handleExportPdf"
            >
              <el-icon><Download /></el-icon>
              {{ exportLoading ? '导出中...' : '导出PDF' }}
            </el-button>
            <el-button
              v-if="canBatchAudit"
              type="success"
              :loading="auditLoading"
              @click="handleBatchApprove"
            >
              <el-icon><Check /></el-icon>
              批量通过 ({{ selectedRows.length }})
            </el-button>
          </div>
        </div>
      </template>
      
      <!-- 搜索栏 -->
      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="关键词">
          <el-input 
            v-model="queryParams.keyword" 
            placeholder="护士姓名/支付宝" 
            clearable 
            style="width: 160px;"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="状态">
          <el-select 
            v-model="queryParams.status" 
            placeholder="全部状态" 
            clearable 
            style="width: 120px;"
          >
            <el-option
              v-for="option in statusOptions"
              :key="option.value"
              :label="option.label"
              :value="option.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="申请时间">
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
        @selection-change="handleSelectionChange"
      >
        <el-table-column type="selection" width="50" :selectable="row => row.status === 0" />
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="nurseName" label="护士信息" width="150">
          <template #default="{ row }">
            <div class="nurse-info">
              <el-avatar :size="32">{{ row.nurseName?.charAt(0) }}</el-avatar>
              <div class="nurse-detail">
                <span class="name">{{ row.nurseName }}</span>
                <span class="phone">{{ row.nursePhone }}</span>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="amount" label="提现金额" width="120" align="right">
          <template #default="{ row }">
            <span class="amount">{{ formatAmount(row.amount) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="alipayAccount" label="支付宝账号" width="180">
          <template #default="{ row }">
            <div class="alipay-info">
              <span>{{ row.alipayAccount }}</span>
              <el-button 
                type="primary" 
                link 
                size="small" 
                @click="copyToClipboard(row.alipayAccount)"
              >
                <el-icon><CopyDocument /></el-icon>
              </el-button>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="realName" label="收款人" width="100" />
        <el-table-column prop="status" label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="statusMap[row.status]?.type" effect="plain">
              {{ statusMap[row.status]?.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="rejectReason" label="驳回原因" min-width="150" show-overflow-tooltip>
          <template #default="{ row }">
            <span v-if="row.status === 2" class="reject-reason">{{ row.rejectReason }}</span>
            <span v-else class="text-muted">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="申请时间" width="160">
          <template #default="{ row }">
            {{ formatTime(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column prop="auditTime" label="审核时间" width="160">
          <template #default="{ row }">
            {{ formatTime(row.auditTime) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="handleViewDetail(row)">
              <el-icon><View /></el-icon>详情
            </el-button>
            <el-button type="success" link size="small" @click="goNurseDetail(row)">护士</el-button>
            <template v-if="row.status === 0">
              <el-button type="success" link size="small" @click="handleApprove(row)">
                <el-icon><Check /></el-icon>通过
              </el-button>
              <el-button type="danger" link size="small" @click="handleReject(row)">
                <el-icon><Close /></el-icon>驳回
              </el-button>
            </template>
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
      title="提现详情" 
      :width="dialogWidth"
      destroy-on-close
    >
      <div v-loading="detailLoading">
        <template v-if="currentWithdrawal">
          <!-- 状态展示 -->
          <div class="status-banner" :class="`status-${currentWithdrawal.status}`">
            <el-icon :size="32">
              <Clock v-if="currentWithdrawal.status === 0" />
              <CircleCheck v-else-if="currentWithdrawal.status === 3" />
              <CircleClose v-else />
            </el-icon>
            <div class="status-text">
              <span class="label">{{ statusMap[currentWithdrawal.status]?.label }}</span>
              <span v-if="currentWithdrawal.status === 2" class="reason">
                {{ currentWithdrawal.rejectReason }}
              </span>
            </div>
          </div>

          <!-- 提现信息 -->
          <el-descriptions :column="1" border class="detail-descriptions">
            <el-descriptions-item label="提现金额">
              <span class="amount-large">{{ formatAmount(currentWithdrawal.amount) }}</span>
            </el-descriptions-item>
            <el-descriptions-item label="护士姓名">
              <el-button type="primary" link @click="goNurseDetail(currentWithdrawal)">{{ currentWithdrawal.nurseName }}</el-button>
            </el-descriptions-item>
            <el-descriptions-item label="护士手机">
              <el-link :href="`tel:${currentWithdrawal.nursePhone}`">
                {{ currentWithdrawal.nursePhone }}
              </el-link>
            </el-descriptions-item>
          </el-descriptions>

          <!-- 收款信息 -->
          <el-divider content-position="left">收款账户</el-divider>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="支付宝账号">
              <div class="alipay-info">
                <span>{{ currentWithdrawal.alipayAccount }}</span>
                <el-button 
                  type="primary" 
                  link 
                  size="small" 
                  @click="copyToClipboard(currentWithdrawal.alipayAccount)"
                >
                  <el-icon><CopyDocument /></el-icon>复制
                </el-button>
              </div>
            </el-descriptions-item>
            <el-descriptions-item label="收款人姓名">
              <span>{{ currentWithdrawal.realName }}</span>
              <el-button 
                type="primary" 
                link 
                size="small" 
                @click="copyToClipboard(currentWithdrawal.realName)"
              >
                <el-icon><CopyDocument /></el-icon>复制
              </el-button>
            </el-descriptions-item>
          </el-descriptions>

          <!-- 时间信息 -->
          <el-divider content-position="left">时间记录</el-divider>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="申请时间">
              {{ formatTime(currentWithdrawal.createdAt) }}
            </el-descriptions-item>
            <el-descriptions-item label="审核时间">
              {{ formatTime(currentWithdrawal.auditTime) }}
            </el-descriptions-item>
          </el-descriptions>

          <!-- 护士账户余额（如果有） -->
          <template v-if="currentWithdrawal.nurseBalance !== undefined">
            <el-divider content-position="left">账户信息</el-divider>
            <el-descriptions :column="2" border>
              <el-descriptions-item label="账户余额">
                {{ formatAmount(currentWithdrawal.nurseBalance) }}
              </el-descriptions-item>
              <el-descriptions-item label="提现后余额">
                {{ formatAmount(currentWithdrawal.nurseBalance - currentWithdrawal.amount) }}
              </el-descriptions-item>
            </el-descriptions>
          </template>
        </template>
      </div>
      
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="detailDialogVisible = false">关闭</el-button>
          
          <!-- 待审核状态显示审核按钮 -->
          <template v-if="currentWithdrawal?.status === 0">
            <el-button 
              type="danger" 
              :loading="auditLoading"
              @click="handleReject(currentWithdrawal)"
            >
              <el-icon><Close /></el-icon>驳回申请
            </el-button>
            <el-button 
              type="success" 
              :loading="auditLoading"
              @click="handleApprove(currentWithdrawal)"
            >
              <el-icon><Check /></el-icon>确认已打款
            </el-button>
          </template>
        </div>
      </template>
    </el-dialog>

  </div>
</template>

<style scoped>
.withdrawals-container {
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

/* 搜索表单 */
.search-form {
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #ebeef5;
}

/* 护士信息 */
.nurse-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.nurse-detail {
  display: flex;
  flex-direction: column;
}

.nurse-detail .name {
  font-weight: 500;
  color: #303133;
}

.nurse-detail .phone {
  font-size: 12px;
  color: #909399;
}

/* 支付宝信息 */
.alipay-info {
  display: flex;
  align-items: center;
  gap: 4px;
}

/* 金额 */
.amount {
  color: #f56c6c;
  font-weight: 600;
  font-size: 15px;
}

.amount-large {
  color: #f56c6c;
  font-weight: 700;
  font-size: 24px;
}

/* 驳回原因 */
.reject-reason {
  color: #f56c6c;
}

.text-muted {
  color: #c0c4cc;
}

/* 分页 */
.pagination-container {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}

/* 状态横幅 */
.status-banner {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
  border-radius: 8px;
  margin-bottom: 20px;
}

.status-banner.status-0 {
  background-color: #fdf6ec;
  color: #e6a23c;
}

.status-banner.status-1 {
  background-color: #ecf5ff;
  color: #409eff;
}

.status-banner.status-2 {
  background-color: #fef0f0;
  color: #f56c6c;
}

.status-banner.status-3 {
  background-color: #f0f9eb;
  color: #67c23a;
}

.status-text {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.status-text .label {
  font-size: 18px;
  font-weight: 600;
}

.status-text .reason {
  font-size: 13px;
  opacity: 0.8;
}

/* 详情描述 */
.detail-descriptions {
  margin-top: 16px;
}

/* 弹窗底部 */
.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

/* 响应式 */
@media (max-width: 768px) {
  .search-form :deep(.el-form-item) {
    margin-bottom: 12px;
  }
}
</style>
