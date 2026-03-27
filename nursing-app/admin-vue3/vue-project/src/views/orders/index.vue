<script setup>
/**
 * 订单管理页面
 * 功能：ElTable订单列表、状态筛选、分页、导出Excel（调用后端EasyExcel API）
 * 基于项目文档：订单状态 0待支付,1待接单,2已派单,3已接单,4护士已到达,5服务中,6已完成,7已评价,8已取消,9退款中,10已退款
 * 集成VueUse实现响应式设计和移动端适配
 */
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox, ElNotification } from 'element-plus'
import { useRoute } from 'vue-router'
import { getOrderList, getOrderDetail, getOrderFlow, updateOrderStatus, cancelOrder, refundOrder, exportOrders, getOrderStats } from '@/api/order'
import { manualAssign } from '@/api/dispatch'
import { getNurseList } from '@/api/nurse'
import { useResponsive } from '@/composables/useResponsive'

// 响应式设计
const { isMobile, isTablet, tableConfig, dialogWidth, gutter, cardColSpan, searchFormInline, descColumn } = useResponsive()
const route = useRoute()

// ==================== 常量定义 ====================

// 订单状态映射（基于数据库设计）
const statusMap = {
  0: { label: '待支付', type: 'info', color: '#909399' },
  1: { label: '待接单', type: 'warning', color: '#e6a23c' },
  2: { label: '已派单', type: 'primary', color: '#409eff' },
  3: { label: '已接单', type: 'primary', color: '#409eff' },
  4: { label: '护士已到达', type: 'primary', color: '#409eff' },
  5: { label: '服务中', type: 'primary', color: '#409eff' },
  6: { label: '已完成', type: 'success', color: '#67c23a' },
  7: { label: '已评价', type: 'success', color: '#67c23a' },
  8: { label: '已取消', type: 'danger', color: '#f56c6c' },
  9: { label: '退款中', type: 'warning', color: '#e6a23c' },
  10: { label: '已退款', type: 'success', color: '#67c23a' }
}

// 支付状态映射
const payStatusMap = {
  0: { label: '未支付', type: 'info' },
  1: { label: '已支付', type: 'success' }
}

// 退款状态映射
const refundStatusMap = {
  0: { label: '无退款', type: 'info' },
  1: { label: '退款中', type: 'warning' },
  2: { label: '已退款', type: 'success' }
}

// ==================== 状态定义 ====================

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 10,
  status: '',
  orderNo: '',
  phone: '',
  contactName: '',
  startDate: '',
  endDate: '',
  nurseId: ''
})

// 日期范围（用于日期选择器）
const dateRange = ref([])

// 数据列表
const tableData = ref([])
const total = ref(0)
const loading = ref(false)

// 导出加载状态
const exporting = ref(false)

// 统计数据
const statsData = ref({
  todayCount: 0,
  pendingCount: 0,
  processingCount: 0,
  completedCount: 0
})

// 订单详情弹窗
const detailDialogVisible = ref(false)
const currentOrder = ref(null)
const detailLoading = ref(false)
const currentOrderFlow = ref({
  statusLogs: [],
  assignLogs: [],
  paymentRecords: [],
  refundRecords: [],
  sosRecords: []
})

// 退款弹窗
const refundDialogVisible = ref(false)
const refundForm = reactive({
  orderNo: '',
  refundAmount: 0,
  reason: ''
})
const refundLoading = ref(false)

// 手动派单弹窗
const dispatchDialogVisible = ref(false)
const dispatchLoading = ref(false)
const nurseLoading = ref(false)
const nurseOptions = ref([])
const dispatchForm = reactive({
  orderNo: '',
  nurseUserId: undefined,
  remark: ''
})

// 选中的订单（用于批量操作）
const selectedOrders = ref([])

// ==================== 计算属性 ====================

// 是否可以批量导出
const canBatchExport = computed(() => selectedOrders.value.length > 0)

// 状态选项列表
const statusOptions = computed(() => {
  return Object.entries(statusMap).map(([value, item]) => ({
    value: Number(value),
    label: item.label
  }))
})

// ==================== 方法定义 ====================

/**
 * 加载订单列表数据
 */
const loadData = async () => {
  loading.value = true
  try {
    const res = await getOrderList(queryParams)
    tableData.value = res.data.records || []
    total.value = res.data.total || 0
  } catch (error) {
    console.error('加载订单失败:', error)
    ElMessage.error('加载订单数据失败')
  } finally {
    loading.value = false
  }
}

/**
 * 加载统计数据
 */
const loadStats = async () => {
  try {
    const res = await getOrderStats()
    const statusData = res?.data || {}
    statsData.value = {
      todayCount: Number(statusData.todayCount || 0),
      pendingCount: statusData['待接单'] || 0,
      processingCount: statusData['服务中'] || 0,
      completedCount: statusData['已完成'] || 0
    }
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
    orderNo: '',
    phone: '',
    contactName: '',
    startDate: '',
    endDate: '',
    nurseId: ''
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
  selectedOrders.value = selection
}

/**
 * 查看订单详情
 */
const handleViewDetail = async (row) => {
  detailLoading.value = true
  detailDialogVisible.value = true
  currentOrderFlow.value = {
    statusLogs: [],
    assignLogs: [],
    paymentRecords: [],
    refundRecords: [],
    sosRecords: []
  }
  try {
    const [detailRes, flowRes] = await Promise.all([
      getOrderDetail(row.orderNo),
      getOrderFlow(row.orderNo)
    ])
    currentOrder.value = detailRes.data
    currentOrderFlow.value = {
      statusLogs: flowRes?.data?.statusLogs || [],
      assignLogs: flowRes?.data?.assignLogs || [],
      paymentRecords: flowRes?.data?.paymentRecords || [],
      refundRecords: flowRes?.data?.refundRecords || [],
      sosRecords: flowRes?.data?.sosRecords || []
    }
  } catch (error) {
    ElMessage.error('获取订单详情失败')
    detailDialogVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

const resolveImageUrl = (value) => {
  const raw = String(value || '').trim()
  if (!raw) return ''
  if (/^https?:\/\//i.test(raw)) return raw

  const apiBase = String(import.meta.env.VITE_API_BASE_URL || '').trim()
  if (!apiBase) {
    return raw.startsWith('/') ? raw : `/${raw}`
  }

  if (apiBase.startsWith('/')) {
    const base = apiBase.replace(/\/$/, '')
    if (raw.startsWith('/api/')) return raw
    if (raw.startsWith('/uploads/')) return `${base}${raw}`
    return raw.startsWith('/') ? `${base}${raw}` : `${base}/${raw}`
  }

  try {
    const url = new URL(apiBase)
    const basePath = url.pathname.replace(/\/$/, '')
    if (raw.startsWith('/uploads/')) return `${url.origin}${basePath}${raw}`
    if (raw.startsWith('/api/')) return `${url.origin}${raw}`
    return raw.startsWith('/') ? `${url.origin}${raw}` : `${url.origin}/${raw}`
  } catch {
    return raw
  }
}

const getPayMethodLabel = (method) => {
  if (method === 1) return '支付宝'
  if (method === 2) return '微信'
  return '-'
}

const getPayStatusLabel = (status) => {
  if (status === 1) return '支付成功'
  if (status === 2) return '支付失败'
  return '未支付'
}

const getRefundStatusLabel = (status) => {
  if (status === 1) return '退款成功'
  if (status === 2) return '退款失败'
  return '待处理'
}

const getSosStatusLabel = (status) => {
  return status === 1 ? '已处理' : '待处理'
}

const getCallerRoleLabel = (role) => {
  if (role === 'NURSE') return '护士'
  if (role === 'USER') return '用户'
  return role || '-'
}

/**
 * 取消订单
 */
const handleCancel = async (row) => {
  // 检查是否可取消（待支付、待接单、已接单状态可取消）
  if (row.status > 2) {
    ElMessage.warning('当前订单状态不可取消')
    return
  }
  
  try {
    const { value } = await ElMessageBox.prompt('请输入取消原因', '取消订单', {
      confirmButtonText: '确定取消',
      cancelButtonText: '返回',
      inputPattern: /.+/,
      inputErrorMessage: '请输入取消原因',
      type: 'warning'
    })
    
    await cancelOrder(row.orderNo, { reason: value })
    ElMessage.success('订单已取消')
    loadData()
    loadStats()
  } catch {
    // 用户取消操作
  }
}

/**
 * 打开退款弹窗
 */
const handleRefund = (row) => {
  // 检查是否可退款（已支付且未完成的订单）
  if (row.payStatus !== 1) {
    ElMessage.warning('该订单未支付，无法退款')
    return
  }
  if (row.refundStatus === 2) {
    ElMessage.warning('该订单已退款')
    return
  }
  
  refundForm.orderNo = row.orderNo
  refundForm.refundAmount = row.totalAmount
  refundForm.reason = ''
  refundDialogVisible.value = true
}

/**
 * 确认退款
 */
const handleConfirmRefund = async () => {
  if (!refundForm.reason.trim()) {
    ElMessage.warning('请输入退款原因')
    return
  }
  if (refundForm.refundAmount <= 0) {
    ElMessage.warning('退款金额必须大于0')
    return
  }
  
  refundLoading.value = true
  try {
    await refundOrder(refundForm.orderNo, {
      refundAmount: refundForm.refundAmount,
      reason: refundForm.reason
    })
    ElMessage.success('退款申请已提交')
    refundDialogVisible.value = false
    loadData()
  } catch (error) {
    if (!error?.__handled) {
      ElMessage.error(error?.message || '退款失败')
    }
  } finally {
    refundLoading.value = false
  }
}

/**
 * 加载可派单护士列表（仅审核通过+接单中）
 */
const loadAvailableNurses = async () => {
  nurseLoading.value = true
  try {
    const res = await getNurseList({
      pageNo: 1,
      pageSize: 200,
      auditStatus: 1,
      acceptEnabled: 1
    })
    nurseOptions.value = (res?.data?.records || []).map(item => ({
      userId: item.userId,
      name: item.realName || item.nurseName || `护士${item.userId}`,
      phone: item.phone || '-',
      hospital: item.serviceArea || item.hospital || '-'
    }))
  } catch (error) {
    ElMessage.error('加载可派单护士失败')
  } finally {
    nurseLoading.value = false
  }
}

/**
 * 打开手动派单弹窗
 */
const handleOpenDispatch = async (row) => {
  if (row.status !== 1) {
    ElMessage.warning('仅待接单状态支持手动派单')
    return
  }
  dispatchForm.orderNo = row.orderNo
  dispatchForm.nurseUserId = undefined
  dispatchForm.remark = ''
  dispatchDialogVisible.value = true
  await loadAvailableNurses()
}

/**
 * 确认手动派单
 */
const handleConfirmDispatch = async () => {
  if (!dispatchForm.orderNo) {
    ElMessage.warning('缺少订单号')
    return
  }
  if (!dispatchForm.nurseUserId) {
    ElMessage.warning('请选择护士')
    return
  }

  dispatchLoading.value = true
  try {
    await manualAssign({
      orderNo: dispatchForm.orderNo,
      nurseUserId: dispatchForm.nurseUserId,
      remark: dispatchForm.remark?.trim() || ''
    })
    ElNotification({
      title: '派单成功',
      message: `订单 ${dispatchForm.orderNo} 已手动派单，护士端将同步可见。`,
      type: 'success'
    })
    dispatchDialogVisible.value = false
    await Promise.all([loadData(), loadStats()])
  } catch (error) {
    if (!error?.__handled) {
      ElMessage.error(error?.message || '手动派单失败')
    }
  } finally {
    dispatchLoading.value = false
  }
}

/**
 * 导出Excel - 调用后端EasyExcel API
 */
const handleExport = async () => {
  exporting.value = true
  
  try {
    // 确认导出
    await ElMessageBox.confirm(
      `确定要导出订单数据吗？${selectedOrders.value.length > 0 ? `（已选择${selectedOrders.value.length}条）` : '（当前筛选条件下的所有数据）'}`,
      '导出确认',
      {
        confirmButtonText: '确定导出',
        cancelButtonText: '取消',
        type: 'info'
      }
    )
    
    // 构建导出参数
    const exportParams = {
      ...queryParams,
      // 如果有选中的订单，只导出选中的
      ids: selectedOrders.value.length > 0 
        ? selectedOrders.value.map(o => o.id).join(',') 
        : undefined
    }
    
    // 调用后端EasyExcel导出API
    const res = await exportOrders(exportParams)
    
    // 创建Blob对象并下载
    const blob = new Blob([res], { 
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' 
    })
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    
    // 生成文件名：订单列表_2026-01-24_143052.xlsx
    const now = new Date()
    const dateStr = now.toISOString().slice(0, 10)
    const timeStr = now.toTimeString().slice(0, 8).replace(/:/g, '')
    link.download = `订单列表_${dateStr}_${timeStr}.xlsx`
    
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
    
    ElNotification({
      title: '导出成功',
      message: '订单数据已导出为Excel文件',
      type: 'success',
      duration: 3000
    })
  } catch (error) {
    if (error !== 'cancel') {
      console.error('导出失败:', error)
      ElMessage.error('导出失败，请稍后重试')
    }
  } finally {
    exporting.value = false
  }
}

/**
 * 快速筛选状态
 */
const handleQuickFilter = (status) => {
  queryParams.status = status
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

// ==================== 生命周期 ====================

onMounted(() => {
  const routeOrderNo = String(route.query.orderNo || '').trim()
  if (routeOrderNo) {
    queryParams.orderNo = routeOrderNo
    queryParams.page = 1
  }
  loadData()
  loadStats()
})
</script>

<template>
  <div class="orders-container">
    <!-- 统计卡片 -->
    <el-row :gutter="gutter" class="stats-row">
      <el-col v-bind="cardColSpan" @click="handleQuickFilter('')">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #409eff;">
              <el-icon :size="24"><List /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.todayCount || 0 }}</p>
              <p class="stat-label">今日订单</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col v-bind="cardColSpan" @click="handleQuickFilter(1)">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #e6a23c;">
              <el-icon :size="24"><Clock /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.pendingCount || 0 }}</p>
              <p class="stat-label">待接单</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col v-bind="cardColSpan" @click="handleQuickFilter(5)">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #409eff;">
              <el-icon :size="24"><Loading /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.processingCount || 0 }}</p>
              <p class="stat-label">服务中</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card" @click="handleQuickFilter(6)">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #67c23a;">
              <el-icon :size="24"><CircleCheck /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.completedCount || 0 }}</p>
              <p class="stat-label">已完成</p>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 主卡片 -->
    <el-card shadow="never" class="main-card">
      <template #header>
        <div class="card-header">
          <span class="title">订单管理</span>
          <div class="header-actions">
            <el-button 
              type="success" 
              :loading="exporting"
              @click="handleExport"
            >
              <el-icon><Download /></el-icon>
              {{ exporting ? '导出中...' : '导出Excel' }}
            </el-button>
          </div>
        </div>
      </template>
      
      <!-- 搜索栏 -->
      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="订单号">
          <el-input 
            v-model="queryParams.orderNo" 
            placeholder="请输入订单号" 
            clearable 
            class="search-input"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="联系人">
          <el-input 
            v-model="queryParams.contactName" 
            placeholder="联系人姓名" 
            clearable 
            class="search-input"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="手机号">
          <el-input 
            v-model="queryParams.phone" 
            placeholder="联系电话" 
            clearable 
            class="search-input"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="订单状态">
          <el-select 
            v-model="queryParams.status" 
            placeholder="全部状态" 
            clearable 
            class="search-input"
          >
            <el-option
              v-for="option in statusOptions"
              :key="option.value"
              :label="option.label"
              :value="option.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="日期范围">
          <el-date-picker
            v-model="dateRange"
            type="daterange"
            range-separator="至"
            start-placeholder="开始日期"
            end-placeholder="结束日期"
            value-format="YYYY-MM-DD"
            class="date-picker-input"
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
      <div class="table-wrapper">
      <el-table 
        :data="tableData" 
        v-loading="loading" 
        stripe 
        :border="tableConfig.border"
        row-key="id"
        @selection-change="handleSelectionChange"
      >
        <el-table-column type="selection" width="50" fixed="left" />
        <el-table-column prop="orderNo" label="订单号" width="180" fixed="left">
          <template #default="{ row }">
            <el-link type="primary" @click="handleViewDetail(row)">
              {{ row.orderNo }}
            </el-link>
          </template>
        </el-table-column>
        <el-table-column prop="serviceName" label="服务名称" width="120" />
        <el-table-column prop="contactName" label="联系人" width="100" />
        <el-table-column prop="contactPhone" label="联系电话" width="130" />
        <el-table-column prop="address" label="服务地址" min-width="180" show-overflow-tooltip />
        <el-table-column prop="totalAmount" label="订单金额" width="100" align="right">
          <template #default="{ row }">
            <span class="amount">{{ formatAmount(row.totalAmount) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="nurseIncome" label="护士收入" width="100" align="right">
          <template #default="{ row }">
            <span class="income">{{ formatAmount(row.nurseIncome) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="订单状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="statusMap[row.status]?.type" effect="plain">
              {{ statusMap[row.status]?.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="payStatus" label="支付状态" width="90" align="center">
          <template #default="{ row }">
            <el-tag :type="payStatusMap[row.payStatus]?.type" size="small">
              {{ payStatusMap[row.payStatus]?.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="refundStatus" label="退款状态" width="90" align="center">
          <template #default="{ row }">
            <el-tag 
              v-if="row.refundStatus > 0"
              :type="refundStatusMap[row.refundStatus]?.type" 
              size="small"
            >
              {{ refundStatusMap[row.refundStatus]?.label }}
            </el-tag>
            <span v-else class="text-muted">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="appointmentTime" label="预约时间" width="160">
          <template #default="{ row }">
            {{ formatTime(row.appointmentTime) }}
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="创建时间" width="160">
          <template #default="{ row }">
            {{ formatTime(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="handleViewDetail(row)">
              <el-icon><View /></el-icon>详情
            </el-button>
            <el-button
              v-if="row.status === 1"
              type="success"
              link
              size="small"
              @click="handleOpenDispatch(row)"
            >
              <el-icon><Position /></el-icon>派单
            </el-button>
            <el-button
              v-if="row.status <= 2"
              type="warning"
              link
              size="small"
              @click="handleCancel(row)"
            >
              <el-icon><Close /></el-icon>取消
            </el-button>
            <el-button
              v-if="row.payStatus === 1 && row.refundStatus === 0 && row.status !== 6"
              type="danger"
              link
              size="small"
              @click="handleRefund(row)"
            >
              <el-icon><RefreshLeft /></el-icon>退款
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      </div>
      
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

    <!-- 手动派单弹窗 -->
    <el-dialog
      v-model="dispatchDialogVisible"
      title="手动派单"
      :width="dialogWidth"
      destroy-on-close
    >
      <el-form :model="dispatchForm" label-width="100px">
        <el-form-item label="订单号">
          <el-input v-model="dispatchForm.orderNo" disabled />
        </el-form-item>
        <el-form-item label="选择护士" required>
          <el-select
            v-model="dispatchForm.nurseUserId"
            placeholder="请选择接单护士"
            filterable
            :loading="nurseLoading"
            style="width: 100%"
          >
            <el-option
              v-for="item in nurseOptions"
              :key="item.userId"
              :label="`${item.name}（${item.phone}）`"
              :value="item.userId"
            >
              <div style="display:flex;justify-content:space-between;gap:12px;">
                <span>{{ item.name }}（{{ item.phone }}）</span>
                <span style="color:#909399;">{{ item.hospital }}</span>
              </div>
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="备注">
          <el-input
            v-model="dispatchForm.remark"
            type="textarea"
            :rows="3"
            maxlength="100"
            show-word-limit
            placeholder="可选：填写派单说明"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dispatchDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="dispatchLoading" @click="handleConfirmDispatch">
          确认派单
        </el-button>
      </template>
    </el-dialog>

    <!-- 订单详情弹窗 -->
    <el-dialog 
      v-model="detailDialogVisible" 
      title="订单详情" 
      :width="dialogWidth"
      destroy-on-close
    >
      <div v-loading="detailLoading">
        <template v-if="currentOrder">
          <!-- 基本信息 -->
          <el-descriptions :column="descColumn" border>
            <el-descriptions-item label="订单号" :span="2">
              <el-tag>{{ currentOrder.orderNo }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="服务名称">
              {{ currentOrder.serviceName }}
            </el-descriptions-item>
            <el-descriptions-item label="服务价格">
              {{ formatAmount(currentOrder.servicePrice) }}
            </el-descriptions-item>
            <el-descriptions-item label="订单金额">
              <span class="amount">{{ formatAmount(currentOrder.totalAmount) }}</span>
            </el-descriptions-item>
            <el-descriptions-item label="平台服务费">
              {{ formatAmount(currentOrder.platformFee) }}
            </el-descriptions-item>
            <el-descriptions-item label="护士收入">
              <span class="income">{{ formatAmount(currentOrder.nurseIncome) }}</span>
            </el-descriptions-item>
            <el-descriptions-item label="订单状态">
              <el-tag :type="statusMap[currentOrder.status]?.type">
                {{ statusMap[currentOrder.status]?.label }}
              </el-tag>
            </el-descriptions-item>
          </el-descriptions>

          <!-- 联系信息 -->
          <el-divider content-position="left">联系信息</el-divider>
          <el-descriptions :column="descColumn" border>
            <el-descriptions-item label="联系人">
              {{ currentOrder.contactName }}
            </el-descriptions-item>
            <el-descriptions-item label="联系电话">
              <el-link :href="`tel:${currentOrder.contactPhone}`">
                {{ currentOrder.contactPhone }}
              </el-link>
            </el-descriptions-item>
            <el-descriptions-item label="服务地址" :span="2">
              {{ currentOrder.address }}
            </el-descriptions-item>
            <el-descriptions-item label="预约时间">
              {{ formatTime(currentOrder.appointmentTime) }}
            </el-descriptions-item>
            <el-descriptions-item label="用户备注">
              {{ currentOrder.remark || '无' }}
            </el-descriptions-item>
          </el-descriptions>

          <!-- 护士信息 -->
          <el-divider content-position="left">护士信息</el-divider>
          <el-descriptions :column="descColumn" border>
            <el-descriptions-item label="护士姓名">
              {{ currentOrder.nurseName || '待分配' }}
            </el-descriptions-item>
            <el-descriptions-item label="护士电话">
              {{ currentOrder.nursePhone || '-' }}
            </el-descriptions-item>
          </el-descriptions>

          <!-- 服务过程 -->
          <el-divider content-position="left">服务过程</el-divider>
          <el-descriptions :column="descColumn" border>
            <el-descriptions-item label="到达时间">
              {{ formatTime(currentOrder.arrivalTime) }}
            </el-descriptions-item>
            <el-descriptions-item label="开始服务">
              {{ formatTime(currentOrder.startTime) }}
            </el-descriptions-item>
            <el-descriptions-item label="完成服务">
              {{ formatTime(currentOrder.finishTime) }}
            </el-descriptions-item>
            <el-descriptions-item label="创建时间">
              {{ formatTime(currentOrder.createdAt) }}
            </el-descriptions-item>
          </el-descriptions>

          <!-- 状态流日志 -->
          <el-divider content-position="left">状态流日志</el-divider>
          <el-timeline v-if="currentOrderFlow.statusLogs.length">
            <el-timeline-item
              v-for="item in currentOrderFlow.statusLogs"
              :key="item.id"
              :timestamp="formatTime(item.createTime)"
            >
              状态 {{ statusMap[item.oldStatus]?.label || item.oldStatus || '-' }}
              ->
              {{ statusMap[item.newStatus]?.label || item.newStatus || '-' }}
              ，角色：{{ item.operatorRole || '-' }}，备注：{{ item.remark || '无' }}
            </el-timeline-item>
          </el-timeline>
          <el-empty v-else description="暂无状态流日志" :image-size="48" />

          <!-- 派单日志 -->
          <el-divider content-position="left">派单日志</el-divider>
          <el-table v-if="currentOrderFlow.assignLogs.length" :data="currentOrderFlow.assignLogs" size="small" border>
            <el-table-column prop="tryNo" label="轮次" width="70" />
            <el-table-column prop="nurseUserId" label="护士ID" width="100" />
            <el-table-column prop="distanceKm" label="距离(km)" width="100" />
            <el-table-column label="结果" width="90">
              <template #default="{ row }">
                <el-tag :type="row.successFlag === 1 ? 'success' : 'danger'">
                  {{ row.successFlag === 1 ? '成功' : '失败' }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="failReason" label="失败原因" min-width="160" />
            <el-table-column label="时间" min-width="140">
              <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
            </el-table-column>
          </el-table>
          <el-empty v-else description="暂无派单记录" :image-size="48" />

          <!-- 支付退款 -->
          <el-divider content-position="left">支付与退款</el-divider>
          <el-table v-if="currentOrderFlow.paymentRecords.length" :data="currentOrderFlow.paymentRecords" size="small" border>
            <el-table-column label="支付方式" width="90">
              <template #default="{ row }">{{ getPayMethodLabel(row.payMethod) }}</template>
            </el-table-column>
            <el-table-column label="支付状态" width="90">
              <template #default="{ row }">{{ getPayStatusLabel(row.payStatus) }}</template>
            </el-table-column>
            <el-table-column prop="payAmount" label="金额" width="110" />
            <el-table-column prop="tradeNo" label="交易号" min-width="180" show-overflow-tooltip />
            <el-table-column label="支付时间" min-width="140">
              <template #default="{ row }">{{ formatTime(row.payTime || row.createTime) }}</template>
            </el-table-column>
          </el-table>
          <el-empty v-else description="暂无支付记录" :image-size="48" />

          <el-table v-if="currentOrderFlow.refundRecords.length" :data="currentOrderFlow.refundRecords" size="small" border style="margin-top: 10px;">
            <el-table-column label="退款状态" width="90">
              <template #default="{ row }">{{ getRefundStatusLabel(row.refundStatus) }}</template>
            </el-table-column>
            <el-table-column prop="refundAmount" label="退款金额" width="110" />
            <el-table-column prop="refundReason" label="原因" min-width="160" show-overflow-tooltip />
            <el-table-column prop="thirdRefundNo" label="第三方退款号" min-width="160" show-overflow-tooltip />
            <el-table-column label="时间" min-width="140">
              <template #default="{ row }">{{ formatTime(row.updateTime || row.createTime) }}</template>
            </el-table-column>
          </el-table>

          <!-- SOS闭环 -->
          <el-divider content-position="left">SOS记录</el-divider>
          <el-table v-if="currentOrderFlow.sosRecords.length" :data="currentOrderFlow.sosRecords" size="small" border>
            <el-table-column label="发起方" width="90">
              <template #default="{ row }">{{ getCallerRoleLabel(row.callerRole) }}</template>
            </el-table-column>
            <el-table-column prop="emergencyType" label="类型" width="80" />
            <el-table-column prop="description" label="描述" min-width="180" show-overflow-tooltip />
            <el-table-column label="状态" width="90">
              <template #default="{ row }">{{ getSosStatusLabel(row.status) }}</template>
            </el-table-column>
            <el-table-column prop="handleRemark" label="处理说明" min-width="160" show-overflow-tooltip />
            <el-table-column label="发起时间" min-width="140">
              <template #default="{ row }">{{ formatTime(row.createTime) }}</template>
            </el-table-column>
            <el-table-column label="处理时间" min-width="140">
              <template #default="{ row }">{{ formatTime(row.handledTime) }}</template>
            </el-table-column>
          </el-table>
          <el-empty v-else description="暂无SOS记录" :image-size="48" />

          <!-- 服务照片 -->
          <el-divider content-position="left">服务照片</el-divider>
          <div class="photo-list">
            <div v-if="currentOrder.arrivalPhoto" class="photo-item">
              <p>到达打卡照</p>
              <el-image 
                :src="resolveImageUrl(currentOrder.arrivalPhoto)" 
                :preview-src-list="[resolveImageUrl(currentOrder.arrivalPhoto)]"
                fit="cover"
              />
            </div>
            <div v-if="currentOrder.startPhoto" class="photo-item">
              <p>服务前照片</p>
              <el-image 
                :src="resolveImageUrl(currentOrder.startPhoto)" 
                :preview-src-list="[resolveImageUrl(currentOrder.startPhoto)]"
                fit="cover"
              />
            </div>
            <div v-if="currentOrder.finishPhoto" class="photo-item">
              <p>服务后照片</p>
              <el-image 
                :src="resolveImageUrl(currentOrder.finishPhoto)" 
                :preview-src-list="[resolveImageUrl(currentOrder.finishPhoto)]"
                fit="cover"
              />
            </div>
            <el-empty 
              v-if="!currentOrder.arrivalPhoto && !currentOrder.startPhoto && !currentOrder.finishPhoto"
              description="暂无服务照片"
              :image-size="60"
            />
          </div>
        </template>
      </div>
      
      <template #footer>
        <el-button @click="detailDialogVisible = false">关闭</el-button>
      </template>
    </el-dialog>

    <!-- 退款弹窗 -->
    <el-dialog 
      v-model="refundDialogVisible" 
      title="订单退款" 
      :width="dialogWidth"
      destroy-on-close
    >
      <el-form :model="refundForm" label-width="100px">
        <el-form-item label="退款金额">
          <el-input-number 
            v-model="refundForm.refundAmount" 
            :min="0.01"
            :precision="2"
            :step="1"
          />
          <span class="form-tip">元</span>
        </el-form-item>
        <el-form-item label="退款原因">
          <el-input 
            v-model="refundForm.reason" 
            type="textarea" 
            :rows="3"
            placeholder="请输入退款原因"
          />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button @click="refundDialogVisible = false">取消</el-button>
        <el-button 
          type="danger" 
          :loading="refundLoading"
          @click="handleConfirmRefund"
        >
          确认退款
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.orders-container {
  padding: 0;
}

/* 统计卡片 */
.stats-row {
  margin-bottom: 16px;
}

.stat-card {
  cursor: pointer;
  transition: all 0.3s;
}

.stat-card:hover {
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
  font-size: 24px;
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

.header-actions {
  display: flex;
  gap: 8px;
}

/* 搜索输入框 */
.search-input {
  width: 160px;
}

.date-picker-input {
  width: 240px;
}

/* 搜索表单 */
.search-form {
  margin-bottom: 16px;
  padding-bottom: 16px;
  border-bottom: 1px solid #ebeef5;
}

/* 表格容器，支持横向滚动 */
.table-wrapper {
  overflow-x: auto;
  width: 100%;
}

/* 表格样式 */
.amount {
  color: #f56c6c;
  font-weight: 500;
}

.income {
  color: #67c23a;
  font-weight: 500;
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

/* 照片列表 */
.photo-list {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
}

.photo-item {
  text-align: center;
}

.photo-item p {
  font-size: 12px;
  color: #909399;
  margin-bottom: 8px;
}

.photo-item .el-image {
  width: 120px;
  height: 120px;
  border-radius: 8px;
  border: 1px solid #ebeef5;
}

/* 表单提示 */
.form-tip {
  margin-left: 8px;
  color: #909399;
}

/* 响应式 */
@media (max-width: 768px) {
  .search-form :deep(.el-form-item) {
    margin-bottom: 10px;
    width: 100%;
  }

  .search-form :deep(.el-form-item__content) {
    width: 100%;
  }

  .search-input {
    width: 100% !important;
  }

  .date-picker-input {
    width: 100% !important;
  }

  .card-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }

  .header-actions {
    width: 100%;
  }

  .stat-value {
    font-size: 20px;
  }

  .stat-icon {
    width: 40px;
    height: 40px;
  }

  .pagination-container {
    justify-content: center;
  }
}

@media (max-width: 480px) {
  .stat-value {
    font-size: 18px;
  }

  .stat-label {
    font-size: 12px;
  }

  .stat-icon {
    width: 36px;
    height: 36px;
  }

  .stat-info {
    margin-left: 8px;
  }
}
</style>
