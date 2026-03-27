<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useRouter } from 'vue-router'
import { getSosList, handleSos, getSosStats } from '@/api/sos'
import { getOrderDetail, getOrderFlow } from '@/api/order'
import { useResponsive } from '@/composables/useResponsive'

const { tableConfig, searchFormInline, buttonSize } = useResponsive()
const router = useRouter()

const statusMap = {
  0: { label: '待处理', type: 'danger' },
  1: { label: '已处理', type: 'success' }
}

const typeMap = {
  1: '服务风险',
  2: '身体不适',
  3: '其他'
}

const roleMap = {
  USER: '用户',
  NURSE: '护士'
}

const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  status: '',
  orderNo: ''
})

const loading = ref(false)
const tableData = ref([])
const total = ref(0)
const stats = ref({ total: 0, pending: 0, handled: 0, handleRate: 0 })
const detailDialogVisible = ref(false)
const currentDetail = ref(null)
const orderPreviewVisible = ref(false)
const orderPreviewLoading = ref(false)
const orderPreview = ref(null)
const orderFlow = ref({ statusLogs: [], paymentRecords: [], refundRecords: [], sosRecords: [] })
const latestPendingId = ref(null)
const flashRowId = ref(null)
const autoRefreshSec = 8
let pollTimer = null
let flashTimer = null

const pendingCount = computed(() => tableData.value.filter(item => Number(item.status) === 0).length)
const handledCount = computed(() => tableData.value.filter(item => Number(item.status) === 1).length)

const displayTableData = computed(() => {
  if (!latestPendingId.value) return tableData.value
  const index = tableData.value.findIndex(item => Number(item.id) === Number(latestPendingId.value))
  if (index <= 0) return tableData.value
  const list = [...tableData.value]
  const [target] = list.splice(index, 1)
  return [target, ...list]
})

function buildParams(raw) {
  const params = { ...raw }
  Object.keys(params).forEach((key) => {
    if (params[key] === '' || params[key] === null || params[key] === undefined) {
      delete params[key]
    }
  })
  return params
}

const loadData = async () => {
  loading.value = true
  try {
    const [res, statsRes] = await Promise.all([
      getSosList(buildParams(queryParams)),
      getSosStats()
    ])
    const pageData = res?.data || {}
    tableData.value = pageData.records || []
    total.value = pageData.total || 0
    stats.value = statsRes?.data || { total: 0, pending: 0, handled: 0, handleRate: 0 }
  } catch (error) {
    tableData.value = []
    total.value = 0
    console.error('加载SOS列表失败:', error)
  } finally {
    loading.value = false
  }
}

const rowClassName = ({ row, rowIndex }) => {
  if (rowIndex === 0 && Number(row.id) === Number(flashRowId.value)) {
    return 'sos-latest-flash-row'
  }
  return ''
}

const clearFlashTimer = () => {
  if (flashTimer) {
    clearTimeout(flashTimer)
    flashTimer = null
  }
}

const markLatestRow = (id) => {
  clearFlashTimer()
  flashRowId.value = id
  flashTimer = setTimeout(() => {
    flashRowId.value = null
    flashTimer = null
  }, 30000)
}

const checkLatestPendingSos = async () => {
  try {
    const res = await getSosList({ pageNo: 1, pageSize: 1, status: 0 })
    const latest = res?.data?.records?.[0]
    const incomingId = latest?.id

    if (!incomingId) return

    const oldId = latestPendingId.value
    latestPendingId.value = incomingId

    if (oldId && Number(oldId) !== Number(incomingId)) {
      markLatestRow(incomingId)
      ElMessage.warning('检测到新的 SOS 事件，已置顶并高亮首行')

      if (queryParams.pageNo !== 1) {
        queryParams.pageNo = 1
      }
    } else if (!oldId) {
      markLatestRow(incomingId)
    }
  } catch (error) {
    console.error('检测最新SOS失败:', error)
  }
}

const startPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer)
  }
  pollTimer = setInterval(async () => {
    await checkLatestPendingSos()
    await loadData()
  }, autoRefreshSec * 1000)
}

const stopPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer)
    pollTimer = null
  }
  clearFlashTimer()
}

const handleSearch = () => {
  queryParams.pageNo = 1
  loadData()
}

const handleReset = () => {
  Object.assign(queryParams, {
    pageNo: 1,
    pageSize: 10,
    status: '',
    orderNo: ''
  })
  loadData()
}

const handlePageChange = (page) => {
  queryParams.pageNo = page
  loadData()
}

const handleProcess = async (row) => {
  const { value } = await ElMessageBox.prompt('请输入处理备注（可选）', '处理SOS事件', {
    confirmButtonText: '确认处理',
    cancelButtonText: '取消',
    inputPlaceholder: '例如：已电话沟通并派单支援'
  }).catch(() => ({ value: null }))

  if (value === null) {
    return
  }

  await handleSos(row.id, { remark: value || '' })
  ElMessage.success('已标记为处理完成')
  loadData()
}

const openDetail = (row) => {
  currentDetail.value = row
  detailDialogVisible.value = true
}

const goOrderDetail = (orderNo) => {
  const target = String(orderNo || '').trim()
  if (!target) {
    ElMessage.warning('订单号为空，无法跳转')
    return
  }
  router.push({ path: '/orders', query: { orderNo: target } })
}

const openOrderPreview = async (orderNo) => {
  const target = String(orderNo || '').trim()
  if (!target) {
    ElMessage.warning('订单号为空，无法查看')
    return
  }
  orderPreviewVisible.value = true
  orderPreviewLoading.value = true
  orderPreview.value = null
  orderFlow.value = { statusLogs: [], paymentRecords: [], refundRecords: [], sosRecords: [] }
  try {
    const [detailRes, flowRes] = await Promise.all([
      getOrderDetail(target),
      getOrderFlow(target)
    ])
    orderPreview.value = detailRes?.data || null
    orderFlow.value = {
      statusLogs: flowRes?.data?.statusLogs || [],
      paymentRecords: flowRes?.data?.paymentRecords || [],
      refundRecords: flowRes?.data?.refundRecords || [],
      sosRecords: flowRes?.data?.sosRecords || []
    }
  } catch (error) {
    ElMessage.error(error?.message || '加载订单详情失败')
  } finally {
    orderPreviewLoading.value = false
  }
}

onMounted(() => {
  checkLatestPendingSos()
  loadData()
  startPolling()
})

onBeforeUnmount(() => {
  stopPolling()
})
</script>

<template>
  <div class="sos-container">
    <el-card shadow="never">
      <template #header>
        <span>SOS紧急呼叫</span>
      </template>

      <div class="summary-row">
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">当前页待处理</div>
          <div class="summary-value danger">{{ pendingCount }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">当前页已处理</div>
          <div class="summary-value success">{{ handledCount }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">检索总数</div>
          <div class="summary-value">{{ total }}</div>
        </el-card>
        <el-card shadow="never" class="summary-card">
          <div class="summary-title">全量处理率</div>
          <div class="summary-value">{{ (Number(stats.handleRate || 0) * 100).toFixed(1) }}%</div>
        </el-card>
      </div>

      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="订单号">
          <el-input v-model="queryParams.orderNo" placeholder="请输入订单号" clearable />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="queryParams.status" placeholder="全部" clearable>
            <el-option :value="0" label="待处理" />
            <el-option :value="1" label="已处理" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button :size="buttonSize" type="primary" @click="handleSearch">搜索</el-button>
          <el-button :size="buttonSize" @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>

      <el-table
        :data="displayTableData"
        v-loading="loading"
        stripe
        :border="tableConfig.border"
        :row-class-name="rowClassName"
      >
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="orderNo" label="订单号" width="170" />
        <el-table-column prop="callerRole" label="发起方" width="100">
          <template #default="{ row }">{{ roleMap[row.callerRole] || row.callerRole || '-' }}</template>
        </el-table-column>
        <el-table-column prop="emergencyType" label="类型" width="100">
          <template #default="{ row }">{{ typeMap[row.emergencyType] || '-' }}</template>
        </el-table-column>
        <el-table-column prop="description" label="描述" show-overflow-tooltip />
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMap[row.status]?.type || 'info'">{{ statusMap[row.status]?.label || '-' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createTime" label="触发时间" width="170" />
        <el-table-column prop="handledTime" label="处理时间" width="170" />
        <el-table-column label="操作" width="190" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" text @click="openDetail(row)">详情</el-button>
            <el-button type="warning" text @click="openOrderPreview(row.orderNo)">就地查看</el-button>
            <el-button type="success" text @click="goOrderDetail(row.orderNo)">查看订单</el-button>
            <el-button
              v-if="row.status === 0"
              type="danger"
              text
              @click="handleProcess(row)"
            >
              标记处理
            </el-button>
            <span v-else>已处理</span>
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

    <el-dialog v-model="detailDialogVisible" title="SOS事件详情" width="560px">
      <el-descriptions v-if="currentDetail" :column="1" border>
        <el-descriptions-item label="订单号">{{ currentDetail.orderNo || '-' }}</el-descriptions-item>
        <el-descriptions-item label="订单联查">
          <el-button type="primary" link @click="goOrderDetail(currentDetail.orderNo)">前往订单管理</el-button>
        </el-descriptions-item>
        <el-descriptions-item label="发起方">{{ roleMap[currentDetail.callerRole] || currentDetail.callerRole || '-' }}</el-descriptions-item>
        <el-descriptions-item label="类型">{{ typeMap[currentDetail.emergencyType] || '-' }}</el-descriptions-item>
        <el-descriptions-item label="状态">
          <el-tag :type="statusMap[currentDetail.status]?.type || 'info'">{{ statusMap[currentDetail.status]?.label || '-' }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="触发时间">{{ currentDetail.createTime || '-' }}</el-descriptions-item>
        <el-descriptions-item label="处理时间">{{ currentDetail.handledTime || '-' }}</el-descriptions-item>
        <el-descriptions-item label="处理备注">{{ currentDetail.handleRemark || '-' }}</el-descriptions-item>
        <el-descriptions-item label="描述">{{ currentDetail.description || '-' }}</el-descriptions-item>
      </el-descriptions>
    </el-dialog>

    <el-dialog v-model="orderPreviewVisible" title="订单详情预览" width="760px" destroy-on-close>
      <div v-loading="orderPreviewLoading">
        <template v-if="orderPreview">
          <el-descriptions :column="2" border>
            <el-descriptions-item label="订单号">{{ orderPreview.orderNo || '-' }}</el-descriptions-item>
            <el-descriptions-item label="订单状态">{{ orderPreview.status }}</el-descriptions-item>
            <el-descriptions-item label="服务项目">{{ orderPreview.serviceName || '-' }}</el-descriptions-item>
            <el-descriptions-item label="订单金额">¥{{ Number(orderPreview.totalAmount || 0).toFixed(2) }}</el-descriptions-item>
            <el-descriptions-item label="联系人">{{ orderPreview.contactName || '-' }}</el-descriptions-item>
            <el-descriptions-item label="联系电话">{{ orderPreview.contactPhone || '-' }}</el-descriptions-item>
            <el-descriptions-item label="地址" :span="2">{{ orderPreview.address || '-' }}</el-descriptions-item>
          </el-descriptions>

          <el-divider content-position="left">链路摘要</el-divider>
          <el-row :gutter="12">
            <el-col :span="6">
              <el-card shadow="never"><div>状态流：{{ orderFlow.statusLogs.length }}</div></el-card>
            </el-col>
            <el-col :span="6">
              <el-card shadow="never"><div>支付记录：{{ orderFlow.paymentRecords.length }}</div></el-card>
            </el-col>
            <el-col :span="6">
              <el-card shadow="never"><div>退款记录：{{ orderFlow.refundRecords.length }}</div></el-card>
            </el-col>
            <el-col :span="6">
              <el-card shadow="never"><div>SOS记录：{{ orderFlow.sosRecords.length }}</div></el-card>
            </el-col>
          </el-row>
        </template>
      </div>
      <template #footer>
        <el-button @click="orderPreviewVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.sos-container {
  padding: 0;
}

.summary-row {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 16px;
}

.summary-card {
  min-height: 96px;
}

.summary-title {
  color: var(--el-text-color-secondary);
  font-size: 13px;
}

.summary-value {
  margin-top: 10px;
  font-size: 26px;
  font-weight: 700;
}

.summary-value.danger {
  color: var(--el-color-danger);
}

.summary-value.success {
  color: var(--el-color-success);
}

.search-form {
  margin-bottom: 16px;
}

.pagination-container {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}

@media (max-width: 768px) {
  .summary-row {
    grid-template-columns: 1fr;
  }
}
</style>

<style scoped>
:deep(.sos-latest-flash-row) {
  animation: sosFlash 1s ease-in-out infinite;
}

@keyframes sosFlash {
  0%,
  100% {
    background-color: rgba(245, 108, 108, 0.1);
  }
  50% {
    background-color: rgba(245, 108, 108, 0.28);
  }
}
</style>
