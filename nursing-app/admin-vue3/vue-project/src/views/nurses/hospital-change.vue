<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  getNurseList,
  approveHospitalChangeNurse,
  rejectHospitalChangeNurse
} from '@/api/nurse'

const loading = ref(false)
const auditLoading = ref(false)
const tableData = ref([])
const total = ref(0)

const queryParams = reactive({
  page: 1,
  pageSize: 10,
  keyword: ''
})

const loadData = async () => {
  loading.value = true
  try {
    const res = await getNurseList({
      page: queryParams.page,
      pageSize: queryParams.pageSize,
      keyword: queryParams.keyword,
      hospitalChangeStatus: 0
    })

    const records = res?.data?.records || []
    tableData.value = records.filter(
      (row) => Number(row.hospitalChangeStatus) === 0 && !!row.pendingHospital
    )
    total.value = res?.data?.total || tableData.value.length
  } catch (error) {
    ElMessage.error(error?.message || '加载医院变更申请失败')
  } finally {
    loading.value = false
  }
}

const handleSearch = () => {
  queryParams.page = 1
  loadData()
}

const handleReset = () => {
  queryParams.page = 1
  queryParams.pageSize = 10
  queryParams.keyword = ''
  loadData()
}

const handlePageChange = (page) => {
  queryParams.page = page
  loadData()
}

const handleSizeChange = (size) => {
  queryParams.pageSize = size
  queryParams.page = 1
  loadData()
}

const handleApprove = async (row) => {
  try {
    await ElMessageBox.confirm(
      `确认通过护士【${row.realName || '-'}】的医院变更申请吗？\n新医院：${row.pendingHospital || '-'}`,
      '审核医院变更',
      {
        confirmButtonText: '通过',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )

    auditLoading.value = true
    await approveHospitalChangeNurse(row.userId)
    ElMessage.success('医院变更已通过')
    await loadData()
  } catch (error) {
    if (error !== 'cancel' && !error?.__handled) {
      ElMessage.error(error?.message || '医院变更审核失败')
    }
  } finally {
    auditLoading.value = false
  }
}

const handleReject = async (row) => {
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

    auditLoading.value = true
    await rejectHospitalChangeNurse(row.userId, { remark: value })
    ElMessage.success('医院变更申请已拒绝')
    await loadData()
  } catch (error) {
    if (error !== 'cancel' && !error?.__handled) {
      ElMessage.error(error?.message || '医院变更审核失败')
    }
  } finally {
    auditLoading.value = false
  }
}

onMounted(() => {
  loadData()
})
</script>

<template>
  <div class="hospital-change-audit-container">
    <el-card shadow="never">
      <template #header>
        <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;">
          <span style="font-weight:600;">医院变更审核</span>
          <div style="display:flex;gap:8px;flex-wrap:wrap;">
            <el-input
              v-model="queryParams.keyword"
              placeholder="搜索护士姓名/手机号"
              clearable
              style="width:220px;"
              @keyup.enter="handleSearch"
            />
            <el-button type="primary" @click="handleSearch">搜索</el-button>
            <el-button @click="handleReset">重置</el-button>
          </div>
        </div>
      </template>

      <el-table :data="tableData" border stripe v-loading="loading">
        <el-table-column prop="realName" label="护士姓名" min-width="120" />
        <el-table-column prop="phone" label="手机号" min-width="140" />
        <el-table-column prop="serviceArea" label="当前医院" min-width="180">
          <template #default="{ row }">
            {{ row.serviceArea || '-' }}
          </template>
        </el-table-column>
        <el-table-column prop="pendingHospital" label="申请医院" min-width="180">
          <template #default="{ row }">
            <el-tag type="warning">{{ row.pendingHospital || '-' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="hospitalChangeRemark" label="申请说明" min-width="180">
          <template #default="{ row }">
            {{ row.hospitalChangeRemark || '-' }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button
              type="success"
              link
              :loading="auditLoading"
              @click="handleApprove(row)"
            >
              通过
            </el-button>
            <el-button
              type="danger"
              link
              :loading="auditLoading"
              @click="handleReject(row)"
            >
              拒绝
            </el-button>
          </template>
        </el-table-column>
      </el-table>

      <div style="display:flex;justify-content:flex-end;margin-top:12px;">
        <el-pagination
          background
          layout="total, sizes, prev, pager, next"
          :total="total"
          :current-page="queryParams.page"
          :page-size="queryParams.pageSize"
          :page-sizes="[10, 20, 50]"
          @current-change="handlePageChange"
          @size-change="handleSizeChange"
        />
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.hospital-change-audit-container {
  padding: 0;
}
</style>
