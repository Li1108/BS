<script setup>
/**
 * 服务管理页面
 */
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  getServiceList,
  createService,
  updateService,
  deleteService,
  updateServiceStatus,
  getCategoryList,
  batchUpdateServiceStatus,
  getServiceOptionList,
  addServiceOption,
  updateServiceOption,
  deleteServiceOption,
  sortServiceCategories
} from '@/api/service'
import { useResponsive } from '@/composables/useResponsive'

const { tableConfig, dialogWidth, searchFormInline, buttonSize } = useResponsive()
const activeTab = ref('items')

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 10,
  categoryId: '',
  status: '',
  keyword: ''
})

// 数据
const tableData = ref([])
const total = ref(0)
const loading = ref(false)
const selectedRows = ref([])

// 编辑弹窗
const dialogVisible = ref(false)
const dialogTitle = ref('新增服务')
const formData = reactive({
  id: null,
  serviceName: '',
  price: 0,
  serviceDesc: '',
  categoryId: '',
  coverImageUrl: '',
  durationMinutes: 60,
  status: 1
})

// 表单规则
const formRules = {
  serviceName: [{ required: true, message: '请输入服务名称', trigger: 'blur' }],
  price: [{ required: true, message: '请输入服务价格', trigger: 'blur' }],
  categoryId: [{ required: true, message: '请选择分类', trigger: 'change' }]
}

const formRef = ref(null)
const optionDialogVisible = ref(false)
const optionDialogTitle = ref('新增可选项')
const optionFormRef = ref(null)
const optionQuery = reactive({ serviceId: '' })
const optionList = ref([])
const optionLoading = ref(false)
const optionForm = reactive({
  id: null,
  serviceId: '',
  optionName: '',
  optionPrice: 0,
  status: 1
})
const optionRules = {
  serviceId: [{ required: true, message: '请选择服务项目', trigger: 'change' }],
  optionName: [{ required: true, message: '请输入可选项名称', trigger: 'blur' }],
  optionPrice: [{ required: true, message: '请输入加价金额', trigger: 'blur' }]
}

// 分类选项
const categories = ref([])
const categorySortRows = ref([])

// 加载数据
const loadData = async () => {
  loading.value = true
  try {
    const res = await getServiceList(queryParams)
    const records = res?.data?.records || []
    const categoryMap = new Map(categories.value.map(item => [item.id, item.categoryName]))
    tableData.value = records.map(item => ({
      ...item,
      name: item.serviceName,
      category: categoryMap.get(item.categoryId) || `分类#${item.categoryId}`,
      description: item.serviceDesc
    }))
    total.value = res.data.total
  } catch (error) {
    console.error('加载服务列表失败:', error)
  } finally {
    loading.value = false
  }
}

const loadOptions = async () => {
  optionLoading.value = true
  try {
    const res = await getServiceOptionList({ serviceId: optionQuery.serviceId || undefined })
    optionList.value = res?.data || []
  } finally {
    optionLoading.value = false
  }
}

const handleSelectionChange = (rows) => {
  selectedRows.value = rows || []
}

const handleBatchStatus = async (status) => {
  if (!selectedRows.value.length) {
    ElMessage.warning('请先选择服务项目')
    return
  }
  await batchUpdateServiceStatus(selectedRows.value.map(item => item.id), status)
  ElMessage.success(status === 1 ? '批量上架成功' : '批量下架成功')
  loadData()
}

const openOptionDialog = (row) => {
  if (row) {
    optionDialogTitle.value = '编辑可选项'
    Object.assign(optionForm, {
      id: row.id,
      serviceId: row.serviceId,
      optionName: row.optionName,
      optionPrice: row.optionPrice,
      status: row.status
    })
  } else {
    optionDialogTitle.value = '新增可选项'
    Object.assign(optionForm, {
      id: null,
      serviceId: optionQuery.serviceId || '',
      optionName: '',
      optionPrice: 0,
      status: 1
    })
  }
  optionDialogVisible.value = true
}

const saveOption = async () => {
  if (!optionFormRef.value) return
  await optionFormRef.value.validate()
  if (optionForm.id) {
    await updateServiceOption(optionForm.id, optionForm)
    ElMessage.success('可选项更新成功')
  } else {
    await addServiceOption(optionForm)
    ElMessage.success('可选项创建成功')
  }
  optionDialogVisible.value = false
  loadOptions()
}

const removeOption = async (row) => {
  await ElMessageBox.confirm('确定删除该可选项吗？', '提示', { type: 'warning' })
  await deleteServiceOption(row.id)
  ElMessage.success('删除成功')
  loadOptions()
}

const saveCategorySort = async () => {
  await sortServiceCategories(
    categorySortRows.value.map(item => ({ id: item.id, sortNo: Number(item.sortNo || 0) }))
  )
  ElMessage.success('分类排序已保存')
  await loadCategories()
}

const loadCategories = async () => {
  const res = await getCategoryList()
  categories.value = res?.data || []
  categorySortRows.value = (res?.data || []).map(item => ({ ...item }))
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
    categoryId: '',
    status: '',
    keyword: ''
  })
  loadData()
}

// 分页
const handlePageChange = (page) => {
  queryParams.page = page
  loadData()
}

// 新增
const handleAdd = () => {
  dialogTitle.value = '新增服务'
  Object.assign(formData, {
    id: null,
    serviceName: '',
    price: 0,
    serviceDesc: '',
    categoryId: '',
    coverImageUrl: '',
    durationMinutes: 60,
    status: 1
  })
  dialogVisible.value = true
}

// 编辑
const handleEdit = (row) => {
  dialogTitle.value = '编辑服务'
  Object.assign(formData, {
    id: row.id,
    serviceName: row.serviceName,
    serviceDesc: row.serviceDesc,
    categoryId: row.categoryId,
    price: row.price,
    coverImageUrl: row.coverImageUrl,
    durationMinutes: row.durationMinutes || 60,
    status: row.status
  })
  dialogVisible.value = true
}

// 保存
const handleSave = async () => {
  if (!formRef.value) return
  
  try {
    await formRef.value.validate()
    
    if (formData.id) {
      await updateService(formData.id, formData)
      ElMessage.success('更新成功')
    } else {
      await createService(formData)
      ElMessage.success('创建成功')
    }
    
    dialogVisible.value = false
    loadData()
  } catch (error) {
    console.error('保存失败:', error)
  }
}

// 删除
const handleDelete = async (row) => {
  try {
    await ElMessageBox.confirm('确定要删除该服务吗？', '提示', {
      type: 'warning'
    })
    await deleteService(row.id)
    ElMessage.success('删除成功')
    loadData()
  } catch {
    // 取消操作
  }
}

// 切换状态（上架/下架）
const handleToggleStatus = async (row) => {
  const newStatus = row.status === 1 ? 0 : 1
  const action = newStatus === 1 ? '上架' : '下架'
  
  try {
    await updateServiceStatus(row.id, newStatus)
    ElMessage.success(`${action}成功`)
    loadData()
  } catch (error) {
    console.error('操作失败:', error)
  }
}

onMounted(() => {
  loadCategories().finally(() => {
    loadData()
    loadOptions()
  })
})
</script>

<template>
  <div class="services-container">
    <el-card shadow="never">
      <el-tabs v-model="activeTab">
        <el-tab-pane name="items" label="服务项目管理">
          <template #label>服务项目管理</template>

          <div class="card-header" style="margin-bottom: 12px;">
            <span>服务项目</span>
            <div style="display:flex; gap:8px; flex-wrap:wrap;">
              <el-button type="success" @click="handleBatchStatus(1)">批量上架</el-button>
              <el-button type="warning" @click="handleBatchStatus(0)">批量下架</el-button>
              <el-button type="primary" @click="handleAdd">
                <el-icon><Plus /></el-icon>新增服务
              </el-button>
            </div>
          </div>

          <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
            <el-form-item label="分类">
              <el-select v-model="queryParams.categoryId" placeholder="全部" clearable>
                <el-option v-for="cat in categories" :key="cat.id" :label="cat.categoryName" :value="cat.id" />
              </el-select>
            </el-form-item>
            <el-form-item label="状态">
              <el-select v-model="queryParams.status" placeholder="全部" clearable>
                <el-option label="上架" :value="1" />
                <el-option label="下架" :value="0" />
              </el-select>
            </el-form-item>
            <el-form-item>
              <el-button :size="buttonSize" type="primary" @click="handleSearch">搜索</el-button>
              <el-button :size="buttonSize" @click="handleReset">重置</el-button>
            </el-form-item>
          </el-form>

          <div class="table-wrapper">
            <el-table :data="tableData" v-loading="loading" stripe :border="tableConfig.border" @selection-change="handleSelectionChange">
              <el-table-column type="selection" width="44" />
              <el-table-column prop="id" label="ID" width="80" />
              <el-table-column prop="name" label="服务名称" width="150" />
              <el-table-column prop="category" label="分类" width="120" />
              <el-table-column prop="price" label="价格" width="100">
                <template #default="{ row }">
                  ¥{{ row.price?.toFixed(2) }}
                </template>
              </el-table-column>
              <el-table-column prop="description" label="描述" show-overflow-tooltip class-name="hidden-mobile" />
              <el-table-column prop="status" label="状态" width="100">
                <template #default="{ row }">
                  <el-switch
                    :model-value="row.status === 1"
                    @change="handleToggleStatus(row)"
                  />
                </template>
              </el-table-column>
              <el-table-column label="操作" width="150" fixed="right">
                <template #default="{ row }">
                  <el-button type="primary" link size="small" @click="handleEdit(row)">
                    编辑
                  </el-button>
                  <el-button type="danger" link size="small" @click="handleDelete(row)">
                    删除
                  </el-button>
                </template>
              </el-table-column>
            </el-table>
          </div>

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

          <el-divider />
          <div class="card-header" style="margin-bottom: 8px;">
            <span>服务分类排序</span>
            <el-button type="primary" @click="saveCategorySort">保存排序</el-button>
          </div>
          <el-table :data="categorySortRows" size="small" :border="tableConfig.border">
            <el-table-column prop="categoryName" label="分类名称" min-width="180" />
            <el-table-column label="排序值" width="180">
              <template #default="{ row }">
                <el-input-number v-model="row.sortNo" :min="0" :step="1" />
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>

        <el-tab-pane name="options" label="服务可选项管理">
          <div class="card-header" style="margin-bottom: 12px;">
            <span>可选项列表</span>
            <el-button type="primary" @click="openOptionDialog()">新增可选项</el-button>
          </div>

          <el-form :inline="searchFormInline" :model="optionQuery" class="search-form">
            <el-form-item label="服务项目">
              <el-select v-model="optionQuery.serviceId" clearable placeholder="全部服务" style="width:220px" @change="loadOptions">
                <el-option v-for="item in tableData" :key="item.id" :label="item.serviceName" :value="item.id" />
              </el-select>
            </el-form-item>
            <el-form-item>
              <el-button :size="buttonSize" type="primary" @click="loadOptions">查询</el-button>
            </el-form-item>
          </el-form>

          <el-table :data="optionList" v-loading="optionLoading" stripe :border="tableConfig.border">
            <el-table-column prop="id" label="ID" width="80" />
            <el-table-column prop="serviceId" label="服务ID" width="100" />
            <el-table-column prop="optionName" label="可选项名称" min-width="180" />
            <el-table-column label="加价" width="120">
              <template #default="{ row }">¥{{ Number(row.optionPrice || 0).toFixed(2) }}</template>
            </el-table-column>
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="Number(row.status) === 1 ? 'success' : 'info'">{{ Number(row.status) === 1 ? '启用' : '禁用' }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="操作" width="150" fixed="right">
              <template #default="{ row }">
                <el-button type="primary" link size="small" @click="openOptionDialog(row)">编辑</el-button>
                <el-button type="danger" link size="small" @click="removeOption(row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
    </el-card>
    
    <!-- 编辑弹窗 -->
    <el-dialog v-model="dialogVisible" :title="dialogTitle" :width="dialogWidth">
      <el-form ref="formRef" :model="formData" :rules="formRules" label-width="80px">
        <el-form-item label="名称" prop="serviceName">
          <el-input v-model="formData.serviceName" placeholder="请输入服务名称" />
        </el-form-item>
        <el-form-item label="分类" prop="categoryId">
          <el-select v-model="formData.categoryId" placeholder="请选择分类">
            <el-option v-for="cat in categories" :key="cat.id" :label="cat.categoryName" :value="cat.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="价格" prop="price">
          <el-input-number v-model="formData.price" :min="0" :precision="2" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="formData.serviceDesc" type="textarea" :rows="3" />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button :size="buttonSize" @click="dialogVisible = false">取消</el-button>
        <el-button :size="buttonSize" type="primary" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="optionDialogVisible" :title="optionDialogTitle" :width="dialogWidth">
      <el-form ref="optionFormRef" :model="optionForm" :rules="optionRules" label-width="100px">
        <el-form-item label="服务项目" prop="serviceId">
          <el-select v-model="optionForm.serviceId" placeholder="请选择服务项目">
            <el-option v-for="item in tableData" :key="item.id" :label="item.serviceName" :value="item.id" />
          </el-select>
        </el-form-item>
        <el-form-item label="可选项名称" prop="optionName">
          <el-input v-model="optionForm.optionName" placeholder="请输入名称" />
        </el-form-item>
        <el-form-item label="加价金额" prop="optionPrice">
          <el-input-number v-model="optionForm.optionPrice" :min="0" :precision="2" />
        </el-form-item>
        <el-form-item label="状态">
          <el-select v-model="optionForm.status">
            <el-option :value="1" label="启用" />
            <el-option :value="0" label="禁用" />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button :size="buttonSize" @click="optionDialogVisible = false">取消</el-button>
        <el-button :size="buttonSize" type="primary" @click="saveOption">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.services-container {
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

  .search-form :deep(.el-input),
  .search-form :deep(.el-select),
  .search-form :deep(.el-input-number) {
    width: 100% !important;
  }

  .pagination-container {
    justify-content: center;
  }
}
</style>
