<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getNotifyTemplateConfig, saveNotifyTemplateConfig } from '@/api/system'
import { useResponsive } from '@/composables/useResponsive'

const { tableConfig, buttonSize, searchFormInline, dialogWidth } = useResponsive()

const defaultTemplates = [
  {
    key: 'maintenance',
    name: '系统维护',
    title: '系统维护通知',
    content: '尊敬的用户，系统将于今晚22:00-次日02:00进行维护升级，届时部分功能可能无法使用，给您带来不便敬请谅解。',
    type: 3,
    targetType: 'all',
    enabled: true,
    sortOrder: 10
  },
  {
    key: 'update',
    name: '版本更新',
    title: '新版本更新',
    content: '新版本已发布，请前往应用商店更新，新版本包含多项功能优化和问题修复。',
    type: 3,
    targetType: 'all',
    enabled: true,
    sortOrder: 20
  },
  {
    key: 'promotion',
    name: '优惠活动',
    title: '限时优惠活动',
    content: '护理服务限时优惠，新用户首单立减10元，老用户推荐有礼，快来参与吧！',
    type: 3,
    targetType: 'all',
    enabled: true,
    sortOrder: 30
  },
  {
    key: 'nurse_reminder',
    name: '护士提醒',
    title: '接单提醒',
    content: '您所在区域有新订单待接，请及时查看并接单，祝您工作顺利！',
    type: 1,
    targetType: 'nurses',
    enabled: true,
    sortOrder: 40
  }
]

const typeOptions = [
  { label: '订单更新', value: 1 },
  { label: '审核结果', value: 2 },
  { label: '系统消息', value: 3 }
]

const targetOptions = [
  { label: '全部用户', value: 'all' },
  { label: '普通用户', value: 'users' },
  { label: '所有护士', value: 'nurses' },
  { label: '指定用户', value: 'selected' }
]

const queryParams = reactive({
  keyword: '',
  enabled: ''
})

const loading = ref(false)
const saving = ref(false)
const templates = ref([])
const editVisible = ref(false)
const editingKey = ref('')

const formRef = ref(null)
const formData = reactive({
  name: '',
  title: '',
  content: '',
  type: 3,
  targetType: 'all',
  enabled: true,
  sortOrder: 10
})

const rules = {
  name: [{ required: true, message: '请输入模板名称', trigger: 'blur' }],
  title: [{ required: true, message: '请输入通知标题', trigger: 'blur' }],
  content: [{ required: true, message: '请输入通知内容', trigger: 'blur' }]
}

const cloneDefaults = () => defaultTemplates.map(item => ({ ...item }))

const normalizeTemplates = (list) => {
  if (!Array.isArray(list)) return []
  return list
    .filter(item => item && item.title && item.content)
    .map((item, index) => ({
      key: String(item.key || `template_${index}_${Date.now()}`),
      name: String(item.name || item.title || `模板${index + 1}`),
      title: String(item.title || ''),
      content: String(item.content || ''),
      type: Number(item.type || 3),
      targetType: String(item.targetType || 'all'),
      enabled: item.enabled !== false,
      sortOrder: Number(item.sortOrder || (index + 1) * 10)
    }))
}

const sortedTemplates = computed(() => {
  const keyword = queryParams.keyword.trim()
  const enabledFilter = queryParams.enabled
  return templates.value
    .filter(item => {
      if (enabledFilter !== '' && Boolean(item.enabled) !== Boolean(Number(enabledFilter))) {
        return false
      }
      if (!keyword) return true
      return item.name.includes(keyword) || item.title.includes(keyword) || item.content.includes(keyword)
    })
    .slice()
    .sort((a, b) => Number(a.sortOrder) - Number(b.sortOrder))
})

const loadTemplates = async () => {
  loading.value = true
  try {
    const res = await getNotifyTemplateConfig()
    const value = res?.data?.configValue || '[]'
    let parsed = []
    try {
      parsed = JSON.parse(value)
    } catch {
      parsed = []
    }
    const normalized = normalizeTemplates(parsed)
    templates.value = normalized.length > 0 ? normalized : cloneDefaults()
  } finally {
    loading.value = false
  }
}

const persistTemplates = async (message = '通知模板已保存') => {
  saving.value = true
  try {
    await saveNotifyTemplateConfig(templates.value)
    ElMessage.success(message)
  } finally {
    saving.value = false
  }
}

const handleSearch = () => {}

const handleReset = () => {
  queryParams.keyword = ''
  queryParams.enabled = ''
}

const openCreate = () => {
  editingKey.value = ''
  Object.assign(formData, {
    name: '',
    title: '',
    content: '',
    type: 3,
    targetType: 'all',
    enabled: true,
    sortOrder: (templates.value.length + 1) * 10
  })
  editVisible.value = true
}

const openEdit = (row) => {
  editingKey.value = row.key
  Object.assign(formData, {
    name: row.name,
    title: row.title,
    content: row.content,
    type: row.type,
    targetType: row.targetType,
    enabled: row.enabled,
    sortOrder: row.sortOrder
  })
  editVisible.value = true
}

const handleSaveTemplate = async () => {
  try {
    await formRef.value.validate()
  } catch {
    return
  }

  const payload = {
    key: editingKey.value || `custom_${Date.now()}`,
    name: formData.name.trim(),
    title: formData.title.trim(),
    content: formData.content.trim(),
    type: Number(formData.type),
    targetType: formData.targetType,
    enabled: Boolean(formData.enabled),
    sortOrder: Number(formData.sortOrder || 10)
  }

  if (editingKey.value) {
    const idx = templates.value.findIndex(item => item.key === editingKey.value)
    if (idx >= 0) {
      templates.value.splice(idx, 1, payload)
    }
  } else {
    templates.value.push(payload)
  }

  editVisible.value = false
  await persistTemplates('模板已保存')
}

const handleToggleEnabled = async (row) => {
  const idx = templates.value.findIndex(item => item.key === row.key)
  if (idx < 0) return
  templates.value[idx].enabled = row.enabled
  await persistTemplates('模板状态已更新')
}

const handleDelete = async (row) => {
  try {
    await ElMessageBox.confirm(`确定删除模板【${row.name}】吗？`, '删除模板', { type: 'warning' })
    templates.value = templates.value.filter(item => item.key !== row.key)
    await persistTemplates('模板已删除')
  } catch {
    // ignore
  }
}

const handleRestoreDefaults = async () => {
  try {
    await ElMessageBox.confirm('确定恢复默认模板吗？当前自定义模板将被覆盖。', '恢复默认', { type: 'warning' })
    templates.value = cloneDefaults()
    await persistTemplates('已恢复默认模板')
  } catch {
    // ignore
  }
}

const typeLabel = (type) => typeOptions.find(item => item.value === Number(type))?.label || '系统消息'
const targetLabel = (targetType) => targetOptions.find(item => item.value === targetType)?.label || '全部用户'

const previewTitle = computed(() => formData.title?.trim() || '（通知标题预览）')
const previewContent = computed(() => formData.content?.trim() || '（通知内容预览）')

onMounted(() => {
  loadTemplates()
})
</script>

<template>
  <div class="notify-template-container">
    <el-card shadow="never" v-loading="loading">
      <template #header>
        <div class="card-header">
          <span class="title">通知模板管理</span>
          <div class="header-actions">
            <el-button :size="buttonSize" @click="handleRestoreDefaults">恢复默认</el-button>
            <el-button :size="buttonSize" type="primary" @click="openCreate">新增模板</el-button>
          </div>
        </div>
      </template>

      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="关键词">
          <el-input v-model="queryParams.keyword" clearable placeholder="模板名称/标题/内容" @keyup.enter="handleSearch" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="queryParams.enabled" clearable placeholder="全部">
            <el-option label="启用" :value="1" />
            <el-option label="停用" :value="0" />
          </el-select>
        </el-form-item>
        <el-form-item>
          <el-button :size="buttonSize" type="primary" @click="handleSearch">搜索</el-button>
          <el-button :size="buttonSize" @click="handleReset">重置</el-button>
        </el-form-item>
      </el-form>

      <el-table :data="sortedTemplates" stripe :border="tableConfig.border">
        <el-table-column prop="name" label="模板名称" min-width="120" />
        <el-table-column prop="title" label="通知标题" min-width="150" show-overflow-tooltip />
        <el-table-column prop="content" label="通知内容" min-width="260" show-overflow-tooltip />
        <el-table-column prop="type" label="类型" width="100">
          <template #default="{ row }">
            <el-tag type="info" effect="plain">{{ typeLabel(row.type) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="targetType" label="默认目标" width="110">
          <template #default="{ row }">{{ targetLabel(row.targetType) }}</template>
        </el-table-column>
        <el-table-column prop="sortOrder" label="排序" width="90" />
        <el-table-column prop="enabled" label="状态" width="100">
          <template #default="{ row }">
            <el-switch v-model="row.enabled" @change="handleToggleEnabled(row)" />
          </template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link @click="openEdit(row)">编辑</el-button>
            <el-button type="danger" link @click="handleDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-dialog v-model="editVisible" title="模板编辑" :width="dialogWidth" destroy-on-close>
      <el-form ref="formRef" :model="formData" :rules="rules" label-width="90px">
        <el-form-item label="模板名称" prop="name">
          <el-input v-model="formData.name" maxlength="20" show-word-limit />
        </el-form-item>
        <el-form-item label="通知标题" prop="title">
          <el-input v-model="formData.title" maxlength="50" show-word-limit />
        </el-form-item>
        <el-form-item label="通知内容" prop="content">
          <el-input v-model="formData.content" type="textarea" :rows="4" maxlength="500" show-word-limit />
        </el-form-item>
        <el-form-item label="通知类型" prop="type">
          <el-select v-model="formData.type" style="width: 100%;">
            <el-option v-for="item in typeOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="默认目标" prop="targetType">
          <el-select v-model="formData.targetType" style="width: 100%;">
            <el-option v-for="item in targetOptions" :key="item.value" :label="item.label" :value="item.value" />
          </el-select>
        </el-form-item>
        <el-form-item label="排序" prop="sortOrder">
          <el-input-number v-model="formData.sortOrder" :min="1" :step="1" />
        </el-form-item>
        <el-form-item label="启用" prop="enabled">
          <el-switch v-model="formData.enabled" />
        </el-form-item>
      </el-form>

      <el-card shadow="never" class="preview-card">
        <template #header>
          <div class="preview-header">
            <span>推送预览</span>
            <el-tag size="small" effect="plain">{{ typeLabel(formData.type) }} · {{ targetLabel(formData.targetType) }}</el-tag>
          </div>
        </template>
        <div class="preview-title">{{ previewTitle }}</div>
        <div class="preview-content">{{ previewContent }}</div>
      </el-card>

      <template #footer>
        <el-button @click="editVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSaveTemplate">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.notify-template-container {
  padding: 0;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-actions {
  display: flex;
  gap: 8px;
}

.search-form {
  margin-bottom: 16px;
}

.preview-card {
  margin-top: 12px;
}

.preview-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
}

.preview-title {
  font-weight: 600;
  color: #303133;
  margin-bottom: 8px;
}

.preview-content {
  color: #606266;
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

@media (max-width: 768px) {
  .card-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }

  .header-actions {
    width: 100%;
  }

  .header-actions .el-button {
    flex: 1;
  }

  .preview-header {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
