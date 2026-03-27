<script setup>
/**
 * 护士资质审核页面
 * 功能：ElTable列表、ElImage显示证件照片、通过/拒绝按钮更新audit_status、账户管理（禁用status=0）
 * 基于数据库设计：nurse_profile.audit_status (0待审，1通过，2拒绝)、sys_user.status (1正常, 0禁用)
 */
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox, ElNotification } from 'element-plus'
import {
  getNurseList,
  getPendingAuditList,
  auditNurse,
  updateNurseStatus,
  getNurseStats,
  approveHospitalChangeNurse,
  rejectHospitalChangeNurse
} from '@/api/nurse'
import { useResponsive } from '@/composables/useResponsive'

const { gutter, cardColSpan, tableConfig, dialogWidth, searchFormInline, buttonSize } = useResponsive()

// ==================== 常量定义 ====================

// 审核状态映射
const auditStatusMap = {
  0: { label: '待审核', type: 'warning', color: '#e6a23c' },
  1: { label: '已通过', type: 'success', color: '#67c23a' },
  2: { label: '已拒绝', type: 'danger', color: '#f56c6c' }
}

// 账户状态映射
const accountStatusMap = {
  1: { label: '正常', type: 'success' },
  0: { label: '已禁用', type: 'danger' }
}

// 工作模式映射
const workModeMap = {
  1: { label: '接单中', type: 'success' },
  0: { label: '休息中', type: 'info' }
}

const resolveWorkModeValue = (nurse) => {
  return Number(
    nurse?.acceptEnabled ??
      nurse?.accept_enabled ??
      nurse?.workMode ??
      nurse?.work_mode ??
      0
  )
}

const hospitalChangeStatusMap = {
  0: { label: '待审核', type: 'warning' },
  1: { label: '已通过', type: 'success' },
  2: { label: '已拒绝', type: 'danger' }
}

// ==================== 状态定义 ====================

// 当前选中的Tab
const activeTab = ref('pending')

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 10,
  auditStatus: '',
  keyword: '',
  status: ''
})

// 数据
const tableData = ref([])
const total = ref(0)
const loading = ref(false)
const lastRefreshTime = ref('')

// 统计数据
const statsData = ref({
  totalCount: 0,
  pendingCount: 0,
  approvedCount: 0,
  rejectedCount: 0,
  disabledCount: 0
})

// 详情弹窗
const dialogVisible = ref(false)
const currentNurse = ref(null)
const detailLoading = ref(false)

// 审核操作加载
const auditLoading = ref(false)
const selectedRows = ref([])

const isPendingTab = computed(() => activeTab.value === 'pending')
const canBatchAudit = computed(() => {
  return isPendingTab.value && selectedRows.value.length > 0 && !auditLoading.value
})

// 图片预览列表
const previewImages = computed(() => {
  if (!currentNurse.value) return []
  return [
    currentNurse.value.nursePhotoUrl,
    currentNurse.value.idCardPhotoFront,
    currentNurse.value.idCardPhotoBack,
    currentNurse.value.certificatePhoto
  ].filter(Boolean)
})

// 审核状态选项
const auditStatusOptions = computed(() => {
  return Object.entries(auditStatusMap).map(([value, item]) => ({
    value: Number(value),
    label: item.label
  }))
})

// ==================== 方法定义 ====================

/**
 * 加载护士列表数据
 */
const loadData = async () => {
  loading.value = true
  try {
    let res
    if (activeTab.value === 'pending') {
      // 待审核Tab使用专门的API
      res = await getPendingAuditList({
        page: queryParams.page,
        pageSize: queryParams.pageSize
      })
    } else {
      // 全部护士Tab使用通用API
      res = await getNurseList(queryParams)
    }
    tableData.value = res.data.records || []
    total.value = res.data.total || 0
    lastRefreshTime.value = new Date().toLocaleString('zh-CN', {
      hour12: false
    })
    if (!isPendingTab.value) {
      selectedRows.value = []
    }
  } catch (error) {
    console.error('加载护士列表失败:', error)
    ElMessage.error('加载数据失败')
  } finally {
    loading.value = false
  }
}

const handleSelectionChange = (rows) => {
  selectedRows.value = rows || []
}

/**
 * 加载统计数据
 */
const loadStats = async () => {
  try {
    const res = await getNurseStats()
    statsData.value = res.data
  } catch (error) {
    console.error('加载统计数据失败:', error)
  }
}

/**
 * Tab切换
 */
const handleTabChange = (tabName) => {
  activeTab.value = tabName
  queryParams.page = 1
  queryParams.auditStatus = ''
  queryParams.keyword = ''
  queryParams.status = ''
  loadData()
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
    auditStatus: '',
    keyword: '',
    status: ''
  })
  loadData()
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
  currentNurse.value = { ...row }
  dialogVisible.value = true
}

/**
 * 审核通过
 */
const handleApprove = async (row) => {
  try {
    await ElMessageBox.confirm(
      `确定通过护士【${row.realName}】的资质审核吗？审核通过后该护士可以开始接单。`,
      '审核确认',
      {
        confirmButtonText: '确定通过',
        cancelButtonText: '取消',
        type: 'success',
        icon: 'CircleCheck'
      }
    )
    
    auditLoading.value = true
    await auditNurse(row.userId, { approved: true })
    
    ElNotification({
      title: '审核成功',
      message: `护士【${row.realName}】资质审核已通过`,
      type: 'success',
      duration: 3000
    })
    
    dialogVisible.value = false
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
 * 审核拒绝
 */
const handleReject = async (row) => {
  try {
    const { value } = await ElMessageBox.prompt(
      '请输入拒绝原因，该原因将通知给护士',
      '审核拒绝',
      {
        confirmButtonText: '确定拒绝',
        cancelButtonText: '取消',
        inputPlaceholder: '请输入拒绝原因...',
        inputPattern: /.{2,}/,
        inputErrorMessage: '请输入至少2个字符的拒绝原因',
        type: 'warning'
      }
    )
    
    auditLoading.value = true
    await auditNurse(row.userId, { approved: false, rejectReason: value })
    
    ElNotification({
      title: '操作成功',
      message: `已拒绝护士【${row.realName}】的资质申请`,
      type: 'warning',
      duration: 3000
    })
    
    dialogVisible.value = false
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

const handleBatchApprove = async () => {
  if (!canBatchAudit.value) return

  const names = selectedRows.value.map((item) => item.realName).join('、')
  try {
    await ElMessageBox.confirm(
      `确定批量通过 ${selectedRows.value.length} 位护士的资质审核吗？\n${names}`,
      '批量审核确认',
      {
        confirmButtonText: '批量通过',
        cancelButtonText: '取消',
        type: 'success'
      }
    )

    auditLoading.value = true
    await Promise.all(
      selectedRows.value.map((row) => auditNurse(row.userId, { approved: true }))
    )

    ElNotification({
      title: '批量审核成功',
      message: `已通过 ${selectedRows.value.length} 位护士的资质审核`,
      type: 'success',
      duration: 2500
    })

    selectedRows.value = []
    await Promise.all([loadData(), loadStats()])
  } catch (error) {
    if (error !== 'cancel' && !error?.__handled) {
      ElMessage.error(error?.message || '批量审核失败')
    }
  } finally {
    auditLoading.value = false
  }
}

const handleBatchReject = async () => {
  if (!canBatchAudit.value) return

  try {
    const { value } = await ElMessageBox.prompt(
      '请输入批量拒绝原因，该原因将通知给所有选中的护士',
      '批量拒绝确认',
      {
        confirmButtonText: '批量拒绝',
        cancelButtonText: '取消',
        inputPlaceholder: '请输入拒绝原因...',
        inputPattern: /.{2,}/,
        inputErrorMessage: '请输入至少2个字符的拒绝原因',
        type: 'warning'
      }
    )

    auditLoading.value = true
    await Promise.all(
      selectedRows.value.map((row) =>
        auditNurse(row.userId, { approved: false, rejectReason: value })
      )
    )

    ElNotification({
      title: '批量处理完成',
      message: `已拒绝 ${selectedRows.value.length} 位护士的资质申请`,
      type: 'warning',
      duration: 2500
    })

    selectedRows.value = []
    await Promise.all([loadData(), loadStats()])
  } catch (error) {
    if (error !== 'cancel' && !error?.__handled) {
      ElMessage.error(error?.message || '批量审核失败')
    }
  } finally {
    auditLoading.value = false
  }
}

/**
 * 禁用/启用账户
 */
const handleToggleStatus = async (row) => {
  const newStatus = row.status === 1 ? 0 : 1
  const actionText = newStatus === 0 ? '禁用' : '启用'
  const warningText = newStatus === 0 
    ? '禁用后该账户将无法登录系统' 
    : '启用后该账户可以正常使用'
  
  try {
    await ElMessageBox.confirm(
      `确定要${actionText}护士【${row.realName}】的账户吗？${warningText}`,
      `${actionText}账户`,
      {
        confirmButtonText: `确定${actionText}`,
        cancelButtonText: '取消',
        type: newStatus === 0 ? 'warning' : 'info'
      }
    )
    
    await updateNurseStatus(row.userId, { status: newStatus })
    
    ElMessage.success(`账户已${actionText}`)
    
    // 更新本地数据
    row.status = newStatus
    loadStats()
  } catch (error) {
    if (error !== 'cancel') {
      if (!error?.__handled) {
        ElMessage.error(error?.message || '操作失败')
      }
    }
  }
}

const handleApproveHospitalChange = async (row) => {
  try {
    await ElMessageBox.confirm(
      `确认通过护士【${row.realName}】的医院变更申请吗？\n新医院：${row.pendingHospital || '-'}`,
      '审核医院变更',
      {
        confirmButtonText: '通过',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )
    await approveHospitalChangeNurse(row.userId)
    ElMessage.success('医院变更已通过')
    await Promise.all([loadData(), loadStats()])
  } catch (error) {
    if (error !== 'cancel' && !error?.__handled) {
      ElMessage.error(error?.message || '医院变更审核失败')
    }
  }
}

const handleRejectHospitalChange = async (row) => {
  try {
    const { value } = await ElMessageBox.prompt(
      '请输入拒绝原因',
      '拒绝医院变更',
      {
        confirmButtonText: '拒绝',
        cancelButtonText: '取消',
        inputPlaceholder: '请输入拒绝原因...',
        inputPattern: /.{2,}/,
        inputErrorMessage: '请输入至少2个字符的拒绝原因',
        type: 'warning'
      }
    )

    await rejectHospitalChangeNurse(row.userId, { remark: value })
    ElMessage.success('医院变更申请已拒绝')
    await Promise.all([loadData(), loadStats()])
  } catch (error) {
    if (error !== 'cancel' && !error?.__handled) {
      ElMessage.error(error?.message || '医院变更审核失败')
    }
  }
}

/**
 * 快速筛选-待审核
 */
const handleQuickFilterPending = () => {
  activeTab.value = 'pending'
  queryParams.page = 1
  selectedRows.value = []
  loadData()
}

/**
 * 快速筛选-已禁用
 */
const handleQuickFilterDisabled = () => {
  activeTab.value = 'all'
  queryParams.status = 0
  queryParams.page = 1
  selectedRows.value = []
  loadData()
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
 * 获取图片完整URL
 */
const getImageUrl = (path) => {
  if (!path) return ''
  const value = path.toString().trim()
  // 完整URL或已包含 /api 前缀，直接返回
  if (value.startsWith('http') || value.startsWith('/api/')) return value
  if (!value.startsWith('/')) return value
  // 其余相对路径拼接 baseUrl
  const baseUrl = import.meta.env.VITE_API_BASE_URL || ''
  return `${baseUrl}${value}`
}

// ==================== 生命周期 ====================

onMounted(() => {
  loadData()
  loadStats()
})
</script>

<template>
  <div class="audit-container">
    <!-- 统计卡片 -->
    <el-row :gutter="gutter" class="stats-row">
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #409eff;">
              <el-icon :size="24"><User /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.totalCount || 0 }}</p>
              <p class="stat-label">护士总数</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col v-bind="cardColSpan">
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
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #67c23a;">
              <el-icon :size="24"><CircleCheck /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.approvedCount || 0 }}</p>
              <p class="stat-label">已通过</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card stat-card-clickable" @click="handleQuickFilterDisabled">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #f56c6c;">
              <el-icon :size="24"><Warning /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.disabledCount || 0 }}</p>
              <p class="stat-label">已禁用</p>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 主卡片 -->
    <el-card shadow="never" class="main-card">
      <!-- Tab切换 -->
      <el-tabs v-model="activeTab" @tab-change="handleTabChange">
        <el-tab-pane label="待审核" name="pending">
          <template #label>
            <span>
              待审核
              <el-badge 
                v-if="statsData.pendingCount > 0" 
                :value="statsData.pendingCount" 
                :max="99" 
                class="tab-badge"
              />
            </span>
          </template>
        </el-tab-pane>
        <el-tab-pane label="全部护士" name="all" />
      </el-tabs>

      <div class="toolbar-row">
        <div class="toolbar-left" v-if="isPendingTab">
          <el-button
            type="success"
            :disabled="!canBatchAudit"
            :loading="auditLoading"
            @click="handleBatchApprove"
          >
            批量通过
          </el-button>
          <el-button
            type="danger"
            plain
            :disabled="!canBatchAudit"
            :loading="auditLoading"
            @click="handleBatchReject"
          >
            批量拒绝
          </el-button>
          <span class="selection-tip" v-if="selectedRows.length > 0">
            已选择 {{ selectedRows.length }} 人
          </span>
        </div>
        <div class="toolbar-right">
          <span class="refresh-time" v-if="lastRefreshTime">更新于 {{ lastRefreshTime }}</span>
          <el-button :size="buttonSize" @click="loadData">
            <el-icon><Refresh /></el-icon>刷新
          </el-button>
        </div>
      </div>
      
      <!-- 搜索栏（仅全部护士Tab显示） -->
      <el-form 
        v-if="activeTab === 'all'" 
        :inline="searchFormInline" 
        :model="queryParams" 
        class="search-form"
      >
        <el-form-item label="关键词">
          <el-input 
            v-model="queryParams.keyword" 
            placeholder="姓名/手机号" 
            clearable 
            style="width: 150px;"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="审核状态">
          <el-select 
            v-model="queryParams.auditStatus" 
            placeholder="全部" 
            clearable 
            style="width: 120px;"
          >
            <el-option
              v-for="option in auditStatusOptions"
              :key="option.value"
              :label="option.label"
              :value="option.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="账户状态">
          <el-select 
            v-model="queryParams.status" 
            placeholder="全部" 
            clearable 
            style="width: 100px;"
          >
            <el-option label="正常" :value="1" />
            <el-option label="禁用" :value="0" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button :size="buttonSize" type="primary" @click="handleSearch">
            <el-icon><Search /></el-icon>搜索
          </el-button>
          <el-button :size="buttonSize" @click="handleReset">
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
        row-key="userId"
        @selection-change="handleSelectionChange"
      >
        <el-table-column v-if="isPendingTab" type="selection" width="50" fixed="left" />
        <el-table-column prop="realName" label="姓名" width="100" fixed="left">
          <template #default="{ row }">
            <div class="nurse-name">
              <el-avatar 
                :size="32" 
                :src="getImageUrl(row.avatar)"
              >
                {{ row.realName?.charAt(0) }}
              </el-avatar>
              <span>{{ row.realName }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="phone" label="手机号" width="130" />
        <el-table-column prop="idCardNo" label="身份证号" width="180" class-name="hidden-mobile">
          <template #default="{ row }">
            <span>{{ row.idCardNo ? row.idCardNo.replace(/^(.{6})(.*)(.{4})$/, '$1****$3') : '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="证件照片" width="150" class-name="hidden-mobile">
          <template #default="{ row }">
            <div class="photo-thumbnails">
              <el-image
                v-if="row.idCardPhotoFront"
                :src="getImageUrl(row.idCardPhotoFront)"
                :preview-src-list="[
                  getImageUrl(row.idCardPhotoFront),
                  getImageUrl(row.idCardPhotoBack),
                  getImageUrl(row.certificatePhoto)
                ].filter(Boolean)"
                fit="cover"
                class="thumbnail"
                preview-teleported
              >
                <template #error>
                  <div class="image-error">
                    <el-icon><Picture /></el-icon>
                  </div>
                </template>
              </el-image>
              <el-button type="primary" link size="small" @click="handleViewDetail(row)">
                查看全部
              </el-button>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="auditStatus" label="审核状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="auditStatusMap[row.auditStatus]?.type" effect="plain">
              {{ auditStatusMap[row.auditStatus]?.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column 
          v-if="activeTab === 'all'" 
          prop="status" 
          label="账户状态" 
          width="100" 
          align="center"
        >
          <template #default="{ row }">
            <el-tag :type="accountStatusMap[row.status]?.type" size="small">
              {{ accountStatusMap[row.status]?.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column 
          v-if="activeTab === 'all'" 
          prop="workMode" 
          label="工作模式" 
          width="90" 
          align="center"
        >
          <template #default="{ row }">
            <el-tag :type="workModeMap[resolveWorkModeValue(row)]?.type" size="small">
              {{ workModeMap[resolveWorkModeValue(row)]?.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column 
          v-if="activeTab === 'all'" 
          prop="rating" 
          label="评分" 
          width="90" 
          align="center"
          class-name="hidden-mobile"
        >
          <template #default="{ row }">
            <div class="rating">
              <el-icon class="star"><StarFilled /></el-icon>
              <span>{{ row.rating?.toFixed(1) || '5.0' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column 
          v-if="activeTab === 'all'" 
          prop="balance" 
          label="账户余额" 
          width="100" 
          align="right"
          class-name="hidden-mobile"
        >
          <template #default="{ row }">
            <span class="balance">¥{{ row.balance?.toFixed(2) || '0.00' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="serviceArea" label="服务区域" width="120" v-if="activeTab === 'all'" class-name="hidden-mobile">
          <template #default="{ row }">
            {{ row.serviceArea || '-' }}
          </template>
        </el-table-column>
        <el-table-column
          v-if="activeTab === 'all'"
          prop="hospitalChangeStatus"
          label="医院变更"
          width="150"
          align="center"
          class-name="hidden-mobile"
        >
          <template #default="{ row }">
            <template v-if="row.hospitalChangeStatus === 0 && row.pendingHospital">
              <el-tag :type="hospitalChangeStatusMap[0].type">待审核</el-tag>
              <div style="font-size: 12px; color: #909399; margin-top: 4px;">{{ row.pendingHospital }}</div>
            </template>
            <template v-else-if="row.hospitalChangeStatus === 1">
              <el-tag :type="hospitalChangeStatusMap[1].type">已通过</el-tag>
            </template>
            <template v-else-if="row.hospitalChangeStatus === 2">
              <el-tag :type="hospitalChangeStatusMap[2].type">已拒绝</el-tag>
            </template>
            <template v-else>
              <span>-</span>
            </template>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="注册时间" width="160" class-name="hidden-mobile">
          <template #default="{ row }">
            {{ formatTime(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" :width="activeTab === 'pending' ? 200 : 180" fixed="right">
          <template #default="{ row }">
            <!-- 待审核状态显示审核按钮 -->
            <template v-if="row.auditStatus === 0">
              <el-button type="success" size="small" @click="handleApprove(row)">
                <el-icon><Check /></el-icon>通过
              </el-button>
              <el-button type="danger" size="small" @click="handleReject(row)">
                <el-icon><Close /></el-icon>拒绝
              </el-button>
            </template>
            <!-- 已审核状态显示详情和账户管理 -->
            <template v-else>
              <el-button type="primary" link size="small" @click="handleViewDetail(row)">
                <el-icon><View /></el-icon>详情
              </el-button>
              <el-button
                v-if="row.hospitalChangeStatus === 0 && row.pendingHospital"
                type="success"
                link
                size="small"
                @click="handleApproveHospitalChange(row)"
              >
                通过变更
              </el-button>
              <el-button
                v-if="row.hospitalChangeStatus === 0 && row.pendingHospital"
                type="danger"
                link
                size="small"
                @click="handleRejectHospitalChange(row)"
              >
                拒绝变更
              </el-button>
              <el-button
                v-if="row.status === 1"
                type="warning"
                link
                size="small"
                @click="handleToggleStatus(row)"
              >
                <el-icon><Lock /></el-icon>禁用
              </el-button>
              <el-button
                v-else
                type="success"
                link
                size="small"
                @click="handleToggleStatus(row)"
              >
                <el-icon><Unlock /></el-icon>启用
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
      v-model="dialogVisible" 
      title="护士资质详情" 
      :width="dialogWidth"
      destroy-on-close
    >
      <template v-if="currentNurse">
        <!-- 基本信息 -->
        <el-descriptions :column="2" border>
          <el-descriptions-item label="姓名">
            <div class="nurse-name">
              <el-avatar 
                :size="40" 
                :src="getImageUrl(currentNurse.avatar)"
              >
                {{ currentNurse.realName?.charAt(0) }}
              </el-avatar>
              <span>{{ currentNurse.realName }}</span>
            </div>
          </el-descriptions-item>
          <el-descriptions-item label="手机号">
            <el-link :href="`tel:${currentNurse.phone}`">
              {{ currentNurse.phone }}
            </el-link>
          </el-descriptions-item>
          <el-descriptions-item label="身份证号" :span="2">
            {{ currentNurse.idCardNo }}
          </el-descriptions-item>
          <el-descriptions-item label="执业证编号" :span="2">
            {{ currentNurse.licenseNo || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="所属医院/机构" :span="2">
            {{ currentNurse.hospital || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="从业年限">
            {{ currentNurse.workYears !== undefined ? `${currentNurse.workYears}年` : '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="技能描述" :span="2">
            {{ currentNurse.skillDesc || '-' }}
          </el-descriptions-item>
          <el-descriptions-item label="审核状态">
            <el-tag :type="auditStatusMap[currentNurse.auditStatus]?.type">
              {{ auditStatusMap[currentNurse.auditStatus]?.label }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="账户状态">
            <el-tag :type="accountStatusMap[currentNurse.status]?.type">
              {{ accountStatusMap[currentNurse.status]?.label }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item v-if="currentNurse.auditStatus === 2" label="拒绝原因" :span="2">
            <span class="reject-reason">{{ currentNurse.auditReason || '-' }}</span>
          </el-descriptions-item>
        </el-descriptions>
        
        <!-- 工作信息（仅已通过的护士显示） -->
        <template v-if="currentNurse.auditStatus === 1">
          <el-divider content-position="left">工作信息</el-divider>
          <el-descriptions :column="3" border>
            <el-descriptions-item label="工作模式">
              <el-tag :type="workModeMap[resolveWorkModeValue(currentNurse)]?.type">
                {{ workModeMap[resolveWorkModeValue(currentNurse)]?.label }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="综合评分">
              <div class="rating">
                <el-icon class="star"><StarFilled /></el-icon>
                <span>{{ currentNurse.rating?.toFixed(1) || '5.0' }}</span>
              </div>
            </el-descriptions-item>
            <el-descriptions-item label="账户余额">
              <span class="balance">¥{{ currentNurse.balance?.toFixed(2) || '0.00' }}</span>
            </el-descriptions-item>
            <el-descriptions-item label="服务区域">
              {{ currentNurse.serviceArea || '-' }}
            </el-descriptions-item>
            <el-descriptions-item label="注册时间">
              {{ formatTime(currentNurse.createdAt) }}
            </el-descriptions-item>
          </el-descriptions>
        </template>
        
        <!-- 证件照片 -->
        <el-divider content-position="left">证件照片</el-divider>
        <div class="image-preview">
          <div class="image-item">
            <p>护士个人照片</p>
            <el-image
              :src="getImageUrl(currentNurse.nursePhotoUrl)"
              fit="contain"
              :preview-src-list="previewImages.map(getImageUrl)"
              preview-teleported
            >
              <template #error>
                <div class="image-placeholder">
                  <el-icon :size="48"><Picture /></el-icon>
                  <span>暂无图片</span>
                </div>
              </template>
            </el-image>
          </div>
          <div class="image-item">
            <p>身份证正面</p>
            <el-image
              :src="getImageUrl(currentNurse.idCardPhotoFront)"
              fit="contain"
              :preview-src-list="previewImages.map(getImageUrl)"
              preview-teleported
            >
              <template #error>
                <div class="image-placeholder">
                  <el-icon :size="48"><Picture /></el-icon>
                  <span>暂无图片</span>
                </div>
              </template>
            </el-image>
          </div>
          <div class="image-item">
            <p>身份证背面</p>
            <el-image
              :src="getImageUrl(currentNurse.idCardPhotoBack)"
              fit="contain"
              :preview-src-list="previewImages.map(getImageUrl)"
              preview-teleported
            >
              <template #error>
                <div class="image-placeholder">
                  <el-icon :size="48"><Picture /></el-icon>
                  <span>暂无图片</span>
                </div>
              </template>
            </el-image>
          </div>
          <div class="image-item">
            <p>护士执业证</p>
            <el-image
              :src="getImageUrl(currentNurse.certificatePhoto)"
              fit="contain"
              :preview-src-list="previewImages.map(getImageUrl)"
              preview-teleported
            >
              <template #error>
                <div class="image-placeholder">
                  <el-icon :size="48"><Picture /></el-icon>
                  <span>暂无图片</span>
                </div>
              </template>
            </el-image>
          </div>
        </div>
      </template>
      
      <template #footer>
        <div class="dialog-footer">
          <el-button @click="dialogVisible = false">关闭</el-button>
          
          <!-- 待审核状态显示审核按钮 -->
          <template v-if="currentNurse?.auditStatus === 0">
            <el-button 
              type="success" 
              :loading="auditLoading"
              @click="handleApprove(currentNurse)"
            >
              <el-icon><Check /></el-icon>通过审核
            </el-button>
            <el-button 
              type="danger" 
              :loading="auditLoading"
              @click="handleReject(currentNurse)"
            >
              <el-icon><Close /></el-icon>拒绝审核
            </el-button>
          </template>
          
          <!-- 已审核状态显示账户管理按钮 -->
          <template v-else-if="currentNurse">
            <el-button
              v-if="currentNurse.status === 1"
              type="warning"
              @click="handleToggleStatus(currentNurse)"
            >
              <el-icon><Lock /></el-icon>禁用账户
            </el-button>
            <el-button
              v-else
              type="success"
              @click="handleToggleStatus(currentNurse)"
            >
              <el-icon><Unlock /></el-icon>启用账户
            </el-button>
          </template>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.audit-container {
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

.main-card :deep(.el-card__body) {
  padding-top: 0;
}

/* Tab徽章 */
.tab-badge {
  margin-left: 6px;
}

.tab-badge :deep(.el-badge__content) {
  font-size: 10px;
}

/* 搜索表单 */
.search-form {
  margin-bottom: 16px;
  padding: 16px 0;
  border-bottom: 1px solid #ebeef5;
}

.toolbar-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 14px;
}

.toolbar-left,
.toolbar-right {
  display: flex;
  align-items: center;
  gap: 8px;
}

.selection-tip {
  font-size: 12px;
  color: #606266;
}

.refresh-time {
  font-size: 12px;
  color: #909399;
}

/* 护士姓名 */
.nurse-name {
  display: flex;
  align-items: center;
  gap: 8px;
}

/* 照片缩略图 */
.photo-thumbnails {
  display: flex;
  align-items: center;
  gap: 8px;
}

.thumbnail {
  width: 40px;
  height: 40px;
  border-radius: 4px;
  cursor: pointer;
}

.image-error {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: #f5f7fa;
  color: #c0c4cc;
}

/* 评分 */
.rating {
  display: flex;
  align-items: center;
  gap: 4px;
  color: #303133;
}

.rating .star {
  color: #f7ba2a;
}

/* 余额 */
.balance {
  color: #67c23a;
  font-weight: 500;
}

/* 拒绝原因 */
.reject-reason {
  color: #f56c6c;
}

/* 分页 */
.pagination-container {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}

/* 图片预览 */
.image-preview {
  display: flex;
  gap: 20px;
}

.image-item {
  flex: 1;
  text-align: center;
}

.image-item p {
  margin-bottom: 8px;
  color: #606266;
  font-size: 14px;
}

.image-item .el-image {
  width: 100%;
  height: 200px;
  border: 1px solid #ebeef5;
  border-radius: 8px;
  background-color: #fafafa;
}

.image-placeholder {
  width: 100%;
  height: 200px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #c0c4cc;
  gap: 8px;
}

.image-placeholder span {
  font-size: 12px;
}

/* 弹窗底部 */
.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

/* 响应式 */
@media (max-width: 768px) {
  .toolbar-row {
    flex-direction: column;
    align-items: flex-start;
  }

  .search-form :deep(.el-form-item) {
    margin-bottom: 12px;
  }
  
  .image-preview {
    flex-direction: column;
  }
  
  .image-item .el-image {
    height: 150px;
  }
}
</style>
