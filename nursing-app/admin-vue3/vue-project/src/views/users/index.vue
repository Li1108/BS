<script setup>
/**
 * 用户管理页面
 */
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { User } from '@element-plus/icons-vue'
import { getUserList, updateUserStatus, getUserDetail } from '@/api/user'
import { useResponsive } from '@/composables/useResponsive'

const { tableConfig, searchFormInline, buttonSize } = useResponsive()

// 查询参数
const queryParams = reactive({
  pageNo: 1,
  pageSize: 10,
  keyword: '',
  status: ''
})

// 数据
const tableData = ref([])
const total = ref(0)
const loading = ref(false)

// 详情对话框
const detailDialogVisible = ref(false)
const currentUser = ref(null)
const detailLoading = ref(false)
const showSensitiveInfo = ref(false)

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

// 加载数据
const loadData = async () => {
  loading.value = true
  try {
    const res = await getUserList(queryParams)
    tableData.value = res.data.records
    total.value = res.data.total
  } catch (error) {
    console.error('加载用户列表失败:', error)
  } finally {
    loading.value = false
  }
}

// 搜索
const handleSearch = () => {
  queryParams.pageNo = 1
  loadData()
}

// 重置
const handleReset = () => {
  Object.assign(queryParams, {
    pageNo: 1,
    pageSize: 10,
    keyword: '',
    status: ''
  })
  loadData()
}

// 分页
const handlePageChange = (page) => {
  queryParams.pageNo = page
  loadData()
}

// 切换状态（启用/禁用）
const handleToggleStatus = async (row) => {
  const newStatus = row.status === 1 ? 0 : 1
  const action = newStatus === 1 ? '启用' : '禁用'
  
  try {
    await ElMessageBox.confirm(`确定要${action}该用户账号吗？`, '提示', {
      type: 'warning'
    })
    await updateUserStatus(row.id, { status: newStatus })
    ElMessage.success(`${action}成功`)
    loadData()
  } catch {
    // 取消操作
  }
}

// 查看详情
const handleViewDetail = async (row) => {
  detailDialogVisible.value = true
  detailLoading.value = true
  currentUser.value = null
  showSensitiveInfo.value = false
  try {
    const res = await getUserDetail(row.id)
    currentUser.value = res.data
  } catch (error) {
    ElMessage.error('加载用户详情失败')
    console.error('加载用户详情失败:', error)
  } finally {
    detailLoading.value = false
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="users-container">
    <el-card shadow="never">
      <template #header>
        <span>用户管理</span>
      </template>
      
      <!-- 搜索栏 -->
      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="关键词">
          <el-input v-model="queryParams.keyword" placeholder="昵称/手机号" clearable />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="queryParams.status" placeholder="全部" clearable>
            <el-option label="正常" :value="1" />
            <el-option label="禁用" :value="0" />
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
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="avatar" label="头像" width="80">
          <template #default="{ row }">
            <el-avatar :size="40" :src="row.avatar">
              <el-icon><User /></el-icon>
            </el-avatar>
          </template>
        </el-table-column>
        <el-table-column prop="username" label="昵称" width="120" />
        <el-table-column prop="phone" label="手机号" width="130" />
        <el-table-column prop="role" label="角色" width="100">
          <template #default="{ row }">
            <el-tag>{{ row.role === 'USER' ? '用户' : '护士' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'">
              {{ row.status === 1 ? '正常' : '禁用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="注册时间" width="170" class-name="hidden-mobile" />
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

    <!-- 用户详情对话框 -->
    <el-dialog
      v-model="detailDialogVisible"
      title="用户详情"
      width="600px"
    >
      <div v-loading="detailLoading">
        <div v-if="currentUser" style="margin-bottom: 12px; text-align: right;">
          <el-button size="small" @click="showSensitiveInfo = !showSensitiveInfo">
            {{ showSensitiveInfo ? '隐藏敏感信息' : '显示敏感信息' }}
          </el-button>
        </div>
        <el-descriptions v-if="currentUser" :column="1" border>
          <el-descriptions-item label="用户ID">{{ currentUser.id }}</el-descriptions-item>
          <el-descriptions-item label="手机号">{{ displayPhone(currentUser.phone) }}</el-descriptions-item>
          <el-descriptions-item label="昵称">{{ currentUser.nickname || '-' }}</el-descriptions-item>
          <el-descriptions-item label="头像">
            <el-avatar v-if="currentUser.avatarUrl" :size="60" :src="currentUser.avatarUrl" />
            <span v-else>-</span>
          </el-descriptions-item>
          <el-descriptions-item label="性别">
            {{ currentUser.gender === 1 ? '男' : currentUser.gender === 2 ? '女' : '未设置' }}
          </el-descriptions-item>
          <el-descriptions-item label="真实姓名">{{ currentUser.realName || '-' }}</el-descriptions-item>
          <el-descriptions-item label="身份证号">{{ displayIdCard(currentUser.idCardNo) }}</el-descriptions-item>
          <el-descriptions-item label="实名状态">
            <el-tag :type="Number(currentUser.realNameVerified) === 1 ? 'success' : 'info'">
              {{ Number(currentUser.realNameVerified) === 1 ? '已认证' : '未认证' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="认证时间">{{ currentUser.realNameVerifyTime || '-' }}</el-descriptions-item>
          <el-descriptions-item label="紧急联系人">{{ currentUser.emergencyContact || '-' }}</el-descriptions-item>
          <el-descriptions-item label="紧急电话">{{ displayPhone(currentUser.emergencyPhone) }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="currentUser.status === 1 ? 'success' : 'danger'">
              {{ currentUser.status === 1 ? '正常' : '禁用' }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="注册时间">{{ currentUser.createTime || '-' }}</el-descriptions-item>
          <el-descriptions-item label="最后登录">{{ currentUser.lastLoginTime || '-' }}</el-descriptions-item>
        </el-descriptions>
      </div>
      <template #footer>
        <el-button @click="detailDialogVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.users-container {
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
