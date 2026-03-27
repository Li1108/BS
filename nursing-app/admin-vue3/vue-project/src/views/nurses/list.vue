<script setup>
/**
 * 护士列表页面
 */
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { User } from '@element-plus/icons-vue'
import { useRoute } from 'vue-router'
import { getNurseList, getNurseDetail, updateNurseStatus, getNurseRejectAlerts } from '@/api/nurse'
import { getUserDetail } from '@/api/user'
import { useResponsive } from '@/composables/useResponsive'

const { tableConfig, searchFormInline, buttonSize, dialogWidth, descColumn } = useResponsive()
const route = useRoute()

// 审核状态映射
const auditStatusMap = {
  0: { label: '待审核', type: 'warning' },
  1: { label: '已通过', type: 'success' },
  2: { label: '已拒绝', type: 'danger' }
}

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 10,
  keyword: '',
  auditStatus: ''
})

// 数据
const tableData = ref([])
const total = ref(0)
const loading = ref(false)
const detailVisible = ref(false)
const detailLoading = ref(false)
const currentNurse = ref(null)
const showSensitiveInfo = ref(false)
const rejectAlertData = ref({ limit: 5, alerts: [] })

const maskPhone = (value) => {
  const text = String(value || '').trim()
  if (!text) return '-'
  if (text.length < 7) return text
  return `${text.slice(0, 3)}****${text.slice(-4)}`
}

const maskIdCard = (value) => {
  const text = String(value || '').trim()
  if (!text) return '-'
  if (text.length < 8) return text
  return `${text.slice(0, 4)}${'*'.repeat(text.length - 8)}${text.slice(-4)}`
}

const displayPhone = (value) => {
  if (showSensitiveInfo.value) return value || '-'
  return maskPhone(value)
}

const displayIdCard = (value) => {
  if (showSensitiveInfo.value) return value || '-'
  return maskIdCard(value)
}

const getWorkModeText = (nurse) => {
  const mode = Number(nurse?.acceptEnabled ?? nurse?.accept_enabled ?? nurse?.workMode ?? nurse?.work_mode ?? 0)
  return mode === 1 ? '接单中' : '休息中'
}

// 加载数据
const loadData = async () => {
  loading.value = true
  try {
    const res = await getNurseList(queryParams)
    tableData.value = res.data.records
    total.value = res.data.total
  } catch (error) {
    console.error('加载护士列表失败:', error)
  } finally {
    loading.value = false
  }
}

// 搜索
const handleSearch = () => {
  queryParams.page = 1
  loadData()
}

// 重置
const handleReset = () => {
  Object.assign(queryParams, {
    page: 1,
    pageSize: 10,
    keyword: '',
    auditStatus: ''
  })
  loadData()
}

// 分页
const handlePageChange = (page) => {
  queryParams.page = page
  loadData()
}

// 详情
const handleViewDetail = async (row) => {
  detailVisible.value = true
  detailLoading.value = true
  showSensitiveInfo.value = false
  try {
    const [nurseRes, userRes] = await Promise.all([
      getNurseDetail(row.userId),
      getUserDetail(row.userId)
    ])

    const nurseData = nurseRes?.data || {}
    const userData = userRes?.data || {}
    currentNurse.value = {
      ...nurseData,
      userRealName: userData.realName || '',
      userIdCardNo: userData.idCardNo || '',
      emergencyContact: userData.emergencyContact || '',
      emergencyPhone: userData.emergencyPhone || '',
      realNameVerified: Number(userData.realNameVerified ?? 0),
      realNameVerifyTime: userData.realNameVerifyTime || '',
      userNickname: userData.nickname || '',
      userGender: userData.gender,
      phone: nurseData.phone || userData.phone || row.phone || ''
    }
  } catch (error) {
    currentNurse.value = row
    if (!error?.__handled) {
      ElMessage.warning('详情加载失败，已显示列表基础信息')
    }
  } finally {
    detailLoading.value = false
  }
}

// 切换状态
const handleToggleStatus = async (row) => {
  const newStatus = row.status === 1 ? 0 : 1
  const action = newStatus === 1 ? '启用' : '禁用'
  
  try {
    await ElMessageBox.confirm(`确定要${action}该护士账号吗？`, '提示', {
      type: 'warning'
    })
    await updateNurseStatus(row.userId, { status: newStatus })
    ElMessage.success(`${action}成功`)
    loadData()
  } catch {
    // 取消操作
  }
}

const loadRejectAlerts = async () => {
  try {
    const res = await getNurseRejectAlerts()
    rejectAlertData.value = res?.data || { limit: 5, alerts: [] }
  } catch {
    rejectAlertData.value = { limit: 5, alerts: [] }
  }
}

onMounted(() => {
  const keyword = String(route.query.keyword || '').trim()
  if (keyword) {
    queryParams.keyword = keyword
    queryParams.page = 1
  }
  loadData()
  loadRejectAlerts()
})
</script>

<template>
  <div class="nurses-container">
    <el-card shadow="never">
      <template #header>
        <span>护士列表</span>
      </template>

      <el-alert
        v-if="rejectAlertData.alerts?.length"
        type="warning"
        :closable="false"
        show-icon
        style="margin-bottom: 12px"
        :title="`今日有 ${rejectAlertData.alerts.length} 位护士拒单已达阈值（${rejectAlertData.limit}次）`"
      />
      
      <!-- 搜索栏 -->
      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="关键词">
          <el-input v-model="queryParams.keyword" placeholder="姓名/手机号" clearable />
        </el-form-item>
        <el-form-item label="审核状态">
          <el-select v-model="queryParams.auditStatus" placeholder="全部" clearable>
            <el-option
              v-for="(item, key) in auditStatusMap"
              :key="key"
              :label="item.label"
              :value="Number(key)"
            />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button :size="buttonSize" type="primary" @click="handleSearch">搜索</el-button>
          <el-button :size="buttonSize" @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>
      
      <!-- 数据表格 -->
      <div class="table-wrapper">
      <el-table :data="tableData" v-loading="loading" stripe :border="tableConfig.border">
        <el-table-column prop="avatar" label="头像" width="80">
          <template #default="{ row }">
            <el-avatar :size="36" :src="row.avatar">
              <el-icon><User /></el-icon>
            </el-avatar>
          </template>
        </el-table-column>
        <el-table-column prop="realName" label="姓名" width="100" />
        <el-table-column prop="phone" label="手机号" width="130" />
        <el-table-column prop="auditStatus" label="审核状态" width="100">
          <template #default="{ row }">
            <el-tag :type="auditStatusMap[row.auditStatus]?.type">
              {{ auditStatusMap[row.auditStatus]?.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="rating" label="评分" width="100">
          <template #default="{ row }">
            <el-rate v-model="row.rating" disabled show-score />
          </template>
        </el-table-column>
        <el-table-column prop="balance" label="账户余额" width="120" class-name="hidden-mobile">
          <template #default="{ row }">
            ¥{{ row.balance?.toFixed(2) }}
          </template>
        </el-table-column>
        <el-table-column prop="status" label="账号状态" width="100" class-name="hidden-mobile">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'">
              {{ row.status === 1 ? '正常' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="handleViewDetail(row)">详情</el-button>
            <el-button
              :type="row.status === 1 ? 'danger' : 'success'"
              link
              size="small"
              @click="handleToggleStatus(row)"
            >
              {{ row.status === 1 ? '禁用' : '启用' }}
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      </div>
      
      <!-- 分页 -->
      <div class="pagination-container">
        <el-pagination
          v-model:current-page="queryParams.page"
          :page-size="queryParams.pageSize"
          :page-sizes="tableConfig.pageSizes"
          :total="total"
          :layout="tableConfig.paginationLayout"
          @size-change="(size) => { queryParams.pageSize = size; queryParams.page = 1; loadData() }"
          @current-change="handlePageChange"
        />
      </div>
    </el-card>

    <el-dialog
      v-model="detailVisible"
      title="护士详情"
      :width="dialogWidth"
      destroy-on-close
    >
      <div v-loading="detailLoading">
        <div v-if="currentNurse" style="margin-bottom: 12px; text-align: right;">
          <el-button size="small" @click="showSensitiveInfo = !showSensitiveInfo">
            {{ showSensitiveInfo ? '隐藏敏感信息' : '显示敏感信息' }}
          </el-button>
        </div>
        <el-descriptions v-if="currentNurse" :column="descColumn" border>
          <el-descriptions-item label="头像">
            <el-avatar :size="56" :src="currentNurse.avatar">
              <el-icon><User /></el-icon>
            </el-avatar>
          </el-descriptions-item>
          <el-descriptions-item label="姓名">{{ currentNurse.realName || '-' }}</el-descriptions-item>
          <el-descriptions-item label="手机号">{{ displayPhone(currentNurse.phone) }}</el-descriptions-item>
          <el-descriptions-item label="审核状态">
            <el-tag :type="auditStatusMap[currentNurse.auditStatus]?.type">
              {{ auditStatusMap[currentNurse.auditStatus]?.label || '-' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="账号状态">
            <el-tag :type="currentNurse.status === 1 ? 'success' : 'danger'">
              {{ currentNurse.status === 1 ? '正常' : '禁用' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="接单状态">
            {{ getWorkModeText(currentNurse) }}
          </el-descriptions-item>
          <el-descriptions-item label="评分">{{ currentNurse.rating ?? '-' }}</el-descriptions-item>
          <el-descriptions-item label="账户余额">¥{{ Number(currentNurse.balance || 0).toFixed(2) }}</el-descriptions-item>
          <el-descriptions-item label="服务区域">{{ currentNurse.serviceArea || '-' }}</el-descriptions-item>
          <el-descriptions-item label="创建时间">{{ currentNurse.createdAt || '-' }}</el-descriptions-item>
          <el-descriptions-item label="用户昵称">{{ currentNurse.userNickname || '-' }}</el-descriptions-item>
          <el-descriptions-item label="用户实名">{{ currentNurse.userRealName || '-' }}</el-descriptions-item>
          <el-descriptions-item label="用户身份证">{{ displayIdCard(currentNurse.userIdCardNo) }}</el-descriptions-item>
          <el-descriptions-item label="实名状态">
            <el-tag :type="Number(currentNurse.realNameVerified) === 1 ? 'success' : 'info'">
              {{ Number(currentNurse.realNameVerified) === 1 ? '已认证' : '未认证' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="认证时间">{{ currentNurse.realNameVerifyTime || '-' }}</el-descriptions-item>
          <el-descriptions-item label="紧急联系人">{{ currentNurse.emergencyContact || '-' }}</el-descriptions-item>
          <el-descriptions-item label="紧急电话">{{ displayPhone(currentNurse.emergencyPhone) }}</el-descriptions-item>
          <el-descriptions-item label="审核备注" :span="descColumn === 1 ? 1 : 2">
            {{ currentNurse.auditReason || '-' }}
          </el-descriptions-item>
        </el-descriptions>
      </div>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.nurses-container {
  padding: 0;
}

.search-form {
  margin-bottom: 16px;
}

.table-wrapper {
  overflow-x: auto;
  width: 100%;
}

.pagination-container {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}

@media (max-width: 768px) {
  .search-form :deep(.el-form-item) {
    margin-bottom: 10px;
    width: 100%;
  }

  .search-form :deep(.el-form-item__content) {
    width: 100%;
  }

  .search-form :deep(.el-input),
  .search-form :deep(.el-select) {
    width: 100% !important;
  }

  .pagination-container {
    justify-content: center;
  }
}
</style>
