<script setup>
/**
 * 评价管理页面
 * 功能：ElTable展示评价列表，支持搜索/过滤，便于平台进行服务质量监控与改进
 * 基于数据库设计：evaluations表 (order_id, user_id, nurse_id, rating, comment)
 */
import { ref, reactive, computed, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { getEvaluationList, getEvaluationDetail, deleteEvaluation, getEvaluationStats } from '@/api/evaluation'
import { useResponsive } from '@/composables/useResponsive'

const { gutter, cardColSpan, tableConfig, dialogWidth, searchFormInline, buttonSize } = useResponsive()

// ==================== 常量定义 ====================

// 评分颜色映射
const ratingColors = {
  1: '#f56c6c',  // 非常差 - 红色
  2: '#e6a23c',  // 较差 - 橙色
  3: '#909399',  // 一般 - 灰色
  4: '#409eff',  // 良好 - 蓝色
  5: '#67c23a'   // 优秀 - 绿色
}

// 评分文字描述
const ratingTexts = ['非常差', '较差', '一般', '良好', '优秀']

// ==================== 状态定义 ====================

// 查询参数
const queryParams = reactive({
  page: 1,
  pageSize: 10,
  rating: '',
  keyword: '',
  nurseId: '',
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
  totalCount: 0,
  avgRating: 0,
  fiveStarCount: 0,
  fiveStarRate: 0,
  lowRatingCount: 0
})

// 详情弹窗
const detailDialogVisible = ref(false)
const currentEvaluation = ref(null)
const detailLoading = ref(false)

// 选中的评价（用于批量操作）
const selectedEvaluations = ref([])

// ==================== 计算属性 ====================

// 评分分布数据（用于图表）
const ratingDistribution = computed(() => {
  // 这里可以从统计数据中获取
  return statsData.value.distribution || []
})

// 评分选项
const ratingOptions = computed(() => {
  return [
    { value: 5, label: '5星 - 优秀', icon: '⭐⭐⭐⭐⭐' },
    { value: 4, label: '4星 - 良好', icon: '⭐⭐⭐⭐' },
    { value: 3, label: '3星 - 一般', icon: '⭐⭐⭐' },
    { value: 2, label: '2星 - 较差', icon: '⭐⭐' },
    { value: 1, label: '1星 - 非常差', icon: '⭐' }
  ]
})

// ==================== 方法定义 ====================

/**
 * 加载评价列表数据
 */
const loadData = async () => {
  loading.value = true
  try {
    const res = await getEvaluationList(queryParams)
    tableData.value = res.data.records || []
    total.value = res.data.total || 0
  } catch (error) {
    console.error('加载评价列表失败:', error)
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
    const res = await getEvaluationStats()
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
    rating: '',
    keyword: '',
    nurseId: '',
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
  selectedEvaluations.value = selection
}

/**
 * 查看评价详情
 */
const handleViewDetail = async (row) => {
  detailLoading.value = true
  detailDialogVisible.value = true
  try {
    const res = await getEvaluationDetail(row.id)
    currentEvaluation.value = res.data
  } catch (error) {
    ElMessage.error('获取评价详情失败')
    currentEvaluation.value = row
  } finally {
    detailLoading.value = false
  }
}

/**
 * 删除评价（仅在特殊情况下使用，如违规内容）
 */
const handleDelete = async (row) => {
  try {
    await ElMessageBox.confirm(
      '确定要删除这条评价吗？此操作不可恢复，通常仅用于删除违规内容。',
      '删除确认',
      {
        confirmButtonText: '确定删除',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )
    
    await deleteEvaluation(row.id)
    ElMessage.success('评价已删除')
    loadData()
    loadStats()
  } catch (error) {
    if (error !== 'cancel') {
      if (!error?.__handled) {
        ElMessage.error(error?.message || '删除失败')
      }
    }
  }
}

/**
 * 快速筛选评分
 */
const handleQuickFilterRating = (rating) => {
  queryParams.rating = rating
  queryParams.page = 1
  loadData()
}

/**
 * 获取评分标签类型
 */
const getRatingTagType = (rating) => {
  if (rating >= 5) return 'success'
  if (rating >= 4) return 'primary'
  if (rating >= 3) return 'info'
  if (rating >= 2) return 'warning'
  return 'danger'
}

/**
 * 获取评分描述文字
 */
const getRatingText = (rating) => {
  return ratingTexts[rating - 1] || ''
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
 * 截断评价内容
 */
const truncateComment = (comment, maxLength = 50) => {
  if (!comment) return '-'
  return comment.length > maxLength 
    ? comment.substring(0, maxLength) + '...' 
    : comment
}

// ==================== 生命周期 ====================

onMounted(() => {
  loadData()
  loadStats()
})
</script>

<template>
  <div class="evaluations-container">
    <!-- 统计卡片 -->
    <el-row :gutter="gutter" class="stats-row">
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card" @click="handleQuickFilterRating('')">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #409eff;">
              <el-icon :size="24"><ChatDotSquare /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.totalCount || 0 }}</p>
              <p class="stat-label">评价总数</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #67c23a;">
              <el-icon :size="24"><Star /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ (statsData.avgRating || 0).toFixed(1) }}</p>
              <p class="stat-label">平均评分</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card stat-card-clickable" @click="handleQuickFilterRating(5)">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #67c23a;">
              <el-icon :size="24"><Medal /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">
                {{ statsData.fiveStarCount || 0 }}
                <span class="stat-percent">({{ (statsData.fiveStarRate || 0).toFixed(1) }}%)</span>
              </p>
              <p class="stat-label">五星好评</p>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card stat-card-clickable" @click="handleQuickFilterRating(1)">
          <div class="stat-content">
            <div class="stat-icon" style="background-color: #f56c6c;">
              <el-icon :size="24"><Warning /></el-icon>
            </div>
            <div class="stat-info">
              <p class="stat-value">{{ statsData.lowRatingCount || 0 }}</p>
              <p class="stat-label">低分评价(≤2星)</p>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 主卡片 -->
    <el-card shadow="never" class="main-card">
      <template #header>
        <div class="card-header">
          <span class="title">评价管理</span>
          <div class="header-tips">
            <el-tag type="info" size="small">评价提交后不可修改</el-tag>
          </div>
        </div>
      </template>
      
      <!-- 搜索栏 -->
      <el-form :inline="searchFormInline" :model="queryParams" class="search-form">
        <el-form-item label="关键词">
          <el-input 
            v-model="queryParams.keyword" 
            placeholder="订单号/用户/护士" 
            clearable 
            style="width: 160px;"
            @keyup.enter="handleSearch"
          />
        </el-form-item>
        <el-form-item label="评分">
          <el-select 
            v-model="queryParams.rating" 
            placeholder="全部评分" 
            clearable 
            style="width: 140px;"
          >
            <el-option
              v-for="option in ratingOptions"
              :key="option.value"
              :label="option.label"
              :value="option.value"
            >
              <span>{{ option.icon }} {{ option.label }}</span>
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="评价时间">
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
          <el-button :size="buttonSize" type="primary" @click="handleSearch">
            <el-icon><Search /></el-icon>搜索
          </el-button>
          <el-button :size="buttonSize" @click="handleReset">
            <el-icon><Refresh /></el-icon>重置
          </el-button>
        </el-form-item>
      </el-form>
      
      <!-- 快速筛选标签 -->
      <div class="quick-filters">
        <span class="filter-label">快速筛选：</span>
        <el-tag 
          :type="queryParams.rating === '' ? 'primary' : 'info'" 
          class="filter-tag"
          @click="handleQuickFilterRating('')"
        >
          全部
        </el-tag>
        <el-tag 
          :type="queryParams.rating === 5 ? 'success' : 'info'" 
          class="filter-tag"
          @click="handleQuickFilterRating(5)"
        >
          ⭐⭐⭐⭐⭐ 五星
        </el-tag>
        <el-tag 
          :type="queryParams.rating === 4 ? 'primary' : 'info'" 
          class="filter-tag"
          @click="handleQuickFilterRating(4)"
        >
          ⭐⭐⭐⭐ 四星
        </el-tag>
        <el-tag 
          :type="queryParams.rating === 3 ? 'warning' : 'info'" 
          class="filter-tag"
          @click="handleQuickFilterRating(3)"
        >
          ⭐⭐⭐ 三星
        </el-tag>
        <el-tag 
          :type="[1, 2].includes(queryParams.rating) ? 'danger' : 'info'" 
          class="filter-tag"
          @click="handleQuickFilterRating(2)"
        >
          ⭐⭐ 低分
        </el-tag>
      </div>
      
      <!-- 数据表格 -->
      <el-table 
        :data="tableData" 
        v-loading="loading" 
        stripe 
        :border="tableConfig.border"
        row-key="id"
        @selection-change="handleSelectionChange"
      >
        <el-table-column type="selection" width="50" />
        <el-table-column prop="id" label="ID" width="70" />
        <el-table-column prop="orderNo" label="订单号" width="180">
          <template #default="{ row }">
            <el-link type="primary" :underline="false">
              {{ row.orderNo }}
            </el-link>
          </template>
        </el-table-column>
        <el-table-column prop="userName" label="评价用户" width="100">
          <template #default="{ row }">
            <div class="user-info">
              <el-avatar :size="24">{{ row.userName?.charAt(0) }}</el-avatar>
              <span>{{ row.userName || '-' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="nurseName" label="被评护士" width="100">
          <template #default="{ row }">
            <div class="user-info">
              <el-avatar :size="24" style="background-color: #67c23a;">
                {{ row.nurseName?.charAt(0) }}
              </el-avatar>
              <span>{{ row.nurseName || '-' }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="serviceName" label="服务项目" width="120" />
        <el-table-column prop="rating" label="评分" width="200">
          <template #default="{ row }">
            <div class="rating-cell">
              <el-rate 
                v-model="row.rating" 
                disabled 
                :colors="['#f56c6c', '#e6a23c', '#409eff']"
              />
              <el-tag 
                :type="getRatingTagType(row.rating)" 
                size="small"
                effect="plain"
              >
                {{ getRatingText(row.rating) }}
              </el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="comment" label="评价内容" min-width="200" class-name="hidden-mobile">
          <template #default="{ row }">
            <div class="comment-cell">
              <span v-if="row.comment">{{ truncateComment(row.comment) }}</span>
              <span v-else class="no-comment">用户未填写评价内容</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="评价时间" width="160" class-name="hidden-mobile">
          <template #default="{ row }">
            {{ formatTime(row.createdAt) }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button type="primary" link size="small" @click="handleViewDetail(row)">
              <el-icon><View /></el-icon>详情
            </el-button>
            <el-button type="danger" link size="small" @click="handleDelete(row)">
              <el-icon><Delete /></el-icon>删除
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

    <!-- 评价详情弹窗 -->
    <el-dialog 
      v-model="detailDialogVisible" 
      title="评价详情" 
      :width="dialogWidth"
      destroy-on-close
    >
      <div v-loading="detailLoading">
        <template v-if="currentEvaluation">
          <!-- 订单信息 -->
          <el-descriptions :column="2" border>
            <el-descriptions-item label="订单号" :span="2">
              <el-tag>{{ currentEvaluation.orderNo }}</el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="服务项目">
              {{ currentEvaluation.serviceName }}
            </el-descriptions-item>
          </el-descriptions>

          <!-- 评价人信息 -->
          <el-divider content-position="left">评价信息</el-divider>
          <el-descriptions :column="2" border>
            <el-descriptions-item label="评价用户">
              <div class="user-info">
                <el-avatar :size="24">{{ currentEvaluation.userName?.charAt(0) }}</el-avatar>
                <span>{{ currentEvaluation.userName }}</span>
              </div>
            </el-descriptions-item>
            <el-descriptions-item label="被评护士">
              <div class="user-info">
                <el-avatar :size="24" style="background-color: #67c23a;">
                  {{ currentEvaluation.nurseName?.charAt(0) }}
                </el-avatar>
                <span>{{ currentEvaluation.nurseName }}</span>
              </div>
            </el-descriptions-item>
            <el-descriptions-item label="评价评分" :span="2">
              <div class="rating-detail">
                <el-rate 
                  v-model="currentEvaluation.rating" 
                  disabled 
                  show-score
                  :colors="['#f56c6c', '#e6a23c', '#409eff']"
                />
                <el-tag 
                  :type="getRatingTagType(currentEvaluation.rating)" 
                  size="small"
                  style="margin-left: 12px;"
                >
                  {{ getRatingText(currentEvaluation.rating) }}
                </el-tag>
              </div>
            </el-descriptions-item>
            <el-descriptions-item label="评价时间" :span="2">
              {{ formatTime(currentEvaluation.createdAt) }}
            </el-descriptions-item>
          </el-descriptions>

          <!-- 评价内容 -->
          <el-divider content-position="left">评价内容</el-divider>
          <div class="comment-content">
            <template v-if="currentEvaluation.comment">
              <p>{{ currentEvaluation.comment }}</p>
            </template>
            <el-empty v-else description="用户未填写评价内容" :image-size="60" />
          </div>
        </template>
      </div>
      
      <template #footer>
        <el-button @click="detailDialogVisible = false">关闭</el-button>
        <el-button 
          type="danger" 
          @click="handleDelete(currentEvaluation); detailDialogVisible = false"
        >
          <el-icon><Delete /></el-icon>删除评价
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.evaluations-container {
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

.stat-percent {
  font-size: 12px;
  font-weight: normal;
  color: #67c23a;
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
  margin-bottom: 12px;
  padding-bottom: 12px;
  border-bottom: 1px solid #ebeef5;
}

/* 快速筛选 */
.quick-filters {
  margin-bottom: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.filter-label {
  color: #606266;
  font-size: 13px;
}

.filter-tag {
  cursor: pointer;
  transition: all 0.2s;
}

.filter-tag:hover {
  opacity: 0.8;
}

/* 用户信息 */
.user-info {
  display: flex;
  align-items: center;
  gap: 6px;
}

/* 评分单元格 */
.rating-cell {
  display: flex;
  align-items: center;
  gap: 8px;
}

/* 评价内容 */
.comment-cell {
  color: #606266;
  line-height: 1.5;
}

.no-comment {
  color: #c0c4cc;
  font-style: italic;
}

/* 金额 */
.amount {
  color: #f56c6c;
  font-weight: 500;
}

/* 分页 */
.pagination-container {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}

/* 评价详情 */
.rating-detail {
  display: flex;
  align-items: center;
}

.comment-content {
  padding: 16px;
  background-color: #fafafa;
  border-radius: 8px;
  min-height: 80px;
}

.comment-content p {
  margin: 0;
  line-height: 1.8;
  color: #303133;
  white-space: pre-wrap;
}

/* 服务照片 */
.photo-list {
  display: flex;
  gap: 12px;
}

.service-photo {
  width: 120px;
  height: 120px;
  border-radius: 8px;
  border: 1px solid #ebeef5;
}

/* 响应式 */
@media (max-width: 768px) {
  .search-form :deep(.el-form-item) {
    margin-bottom: 12px;
  }
  
  .quick-filters {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
