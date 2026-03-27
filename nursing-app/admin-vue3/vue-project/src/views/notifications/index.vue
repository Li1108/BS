<script setup>
/**
 * 通知管理页面
 */
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getNotificationList, sendNotification } from '@/api/notification'
import { getNotifyTemplateConfig } from '@/api/system'
import { useResponsive } from '@/composables/useResponsive'

const { tableConfig, dialogWidth, searchFormInline, buttonSize } = useResponsive()

// 类型映射
const typeMap = {
  1: { label: '订单更新', type: 'primary' },
  2: { label: '审核结果', type: 'warning' },
  3: { label: '系统消息', type: 'info' }
}

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 10,
  type: ''
})

// 数据
const tableData = ref([])
const total = ref(0)
const loading = ref(false)

// 发送通知弹窗
const dialogVisible = ref(false)
const formData = reactive({
  title: '',
  type: 3,
  content: '',
  userIds: []
})

const templateOptions = ref([])
const selectedTemplateKey = ref('')

const loadTemplateOptions = async () => {
  try {
    const res = await getNotifyTemplateConfig()
    const raw = res?.data?.configValue || '[]'
    const parsed = JSON.parse(raw)
    templateOptions.value = (Array.isArray(parsed) ? parsed : [])
      .filter(item => item && item.title && item.content && item.enabled !== false)
      .map(item => ({
        key: String(item.key || ''),
        name: String(item.name || item.title),
        title: String(item.title || ''),
        content: String(item.content || ''),
        type: Number(item.type || 3)
      }))
  } catch {
    templateOptions.value = []
  }
}

const handleTemplateChange = (key) => {
  const template = templateOptions.value.find(item => item.key === key)
  if (!template) return
  formData.type = Number(template.type || 3)
  formData.title = template.title || ''
  formData.content = template.content || ''
}

// 加载数据
const loadData = async () => {
  loading.value = true
  try {
    const res = await getNotificationList(queryParams)
    tableData.value = res.data.records
    total.value = res.data.total
  } catch (error) {
    console.error('加载通知列表失败:', error)
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
    type: ''
  })
  loadData()
}

// 分页
const handlePageChange = (page) => {
  queryParams.page = page
  loadData()
}

// 打开发送通知弹窗
const handleOpenSend = () => {
  Object.assign(formData, {
    title: '',
    type: 3,
    content: '',
    userIds: []
  })
  selectedTemplateKey.value = ''
  dialogVisible.value = true
}

// 发送通知
const handleSend = async () => {
  if (!formData.title.trim()) {
    ElMessage.warning('请输入通知标题')
    return
  }
  if (!formData.content.trim()) {
    ElMessage.warning('请输入通知内容')
    return
  }
  
  try {
    await sendNotification(formData)
    ElMessage.success('发送成功')
    dialogVisible.value = false
    loadData()
  } catch (error) {
    console.error('发送失败:', error)
  }
}

onMounted(() => {
  loadData()
  loadTemplateOptions()
})
</script>

<template>
  <div class="notifications-container">
    <el-card shadow="never">
      <template #header>
        <div class="card-header">
          <span>通知管理</span>
          <el-button type="primary" @click="handleOpenSend">
            <el-icon><Bell /></el-icon>发送通知
          </el-button>
        </div>
      </template>
      
      <!-- 搜索栏 -->
      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="类型">
          <el-select v-model="queryParams.type" placeholder="全部" clearable>
            <el-option
              v-for="(item, key) in typeMap"
              :key="key"
              :label="item.label"
              :value="key"
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
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="userName" label="接收者" width="120" />
        <el-table-column prop="type" label="类型" width="100">
          <template #default="{ row }">
            <el-tag :type="typeMap[row.type]?.type">
              {{ typeMap[row.type]?.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="content" label="内容" show-overflow-tooltip />
        <el-table-column prop="isRead" label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.isRead === 1 ? 'info' : 'primary'">
              {{ row.isRead === 1 ? '已读' : '未读' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="发送时间" width="170" class-name="hidden-mobile" />
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
    
    <!-- 发送通知弹窗 -->
    <el-dialog v-model="dialogVisible" title="发送通知" :width="dialogWidth">
      <el-form :model="formData" label-width="80px">
        <el-form-item label="模板">
          <el-select
            v-model="selectedTemplateKey"
            clearable
            filterable
            placeholder="选择模板自动填充"
            @change="handleTemplateChange"
          >
            <el-option
              v-for="item in templateOptions"
              :key="item.key"
              :label="item.name"
              :value="item.key"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="formData.type" placeholder="请选择类型">
            <el-option
              v-for="(item, key) in typeMap"
              :key="key"
              :label="item.label"
              :value="Number(key)"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="标题">
          <el-input
            v-model="formData.title"
            placeholder="请输入通知标题"
            maxlength="50"
            show-word-limit
          />
        </el-form-item>
        <el-form-item label="内容">
          <el-input
            v-model="formData.content"
            type="textarea"
            :rows="4"
            placeholder="请输入通知内容"
          />
        </el-form-item>
        <el-form-item>
          <el-alert
            title="留空用户ID将发送给所有用户"
            type="info"
            :closable="false"
            show-icon
          />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button :size="buttonSize" @click="dialogVisible = false">取消</el-button>
        <el-button :size="buttonSize" type="primary" @click="handleSend">发送</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.notifications-container {
  padding: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
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
  .card-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .search-form :deep(.el-form-item) {
    margin-bottom: 10px;
    width: 100%;
  }

  .search-form :deep(.el-form-item__content) {
    width: 100%;
  }

  .search-form :deep(.el-select) {
    width: 100% !important;
  }

  .pagination-container {
    justify-content: center;
  }
}
</style>
