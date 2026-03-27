<script setup>
/**
 * 控制台首页
 */
import { ref, onMounted } from 'vue'
import { getDashboardStats } from '@/api/stats'
import { useResponsive } from '@/composables/useResponsive'

const { gutter, cardColSpan, isMobile } = useResponsive()

// 统计数据
const stats = ref({
  todayOrders: 0,
  totalOrders: 0,
  totalUsers: 0,
  totalNurses: 0,
  pendingAudit: 0,
  pendingWithdrawals: 0,
  todayIncome: 0,
  totalIncome: 0
})

// 加载状态
const loading = ref(false)

// 加载数据
const loadStats = async () => {
  loading.value = true
  try {
    const res = await getDashboardStats()
    stats.value = res.data
  } catch (error) {
    console.error('加载统计数据失败:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadStats()
})
</script>

<template>
  <div class="dashboard-container">
    <h2 class="page-title">控制台</h2>
    
    <!-- 统计卡片 -->
    <el-row :gutter="gutter" class="stat-cards">
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background-color: #409eff;">
            <el-icon :size="28"><List /></el-icon>
          </div>
          <div class="stat-info">
            <p class="stat-value">{{ stats.todayOrders }}</p>
            <p class="stat-label">今日订单</p>
          </div>
        </el-card>
      </el-col>
      
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background-color: #67c23a;">
            <el-icon :size="28"><User /></el-icon>
          </div>
          <div class="stat-info">
            <p class="stat-value">{{ stats.totalUsers }}</p>
            <p class="stat-label">注册用户</p>
          </div>
        </el-card>
      </el-col>
      
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background-color: #e6a23c;">
            <el-icon :size="28"><UserFilled /></el-icon>
          </div>
          <div class="stat-info">
            <p class="stat-value">{{ stats.totalNurses }}</p>
            <p class="stat-label">注册护士</p>
          </div>
        </el-card>
      </el-col>
      
      <el-col v-bind="cardColSpan">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-icon" style="background-color: #f56c6c;">
            <el-icon :size="28"><Warning /></el-icon>
          </div>
          <div class="stat-info">
            <p class="stat-value">{{ stats.pendingAudit }}</p>
            <p class="stat-label">待审核</p>
          </div>
        </el-card>
      </el-col>
    </el-row>
    
    <!-- 快捷入口 -->
    <el-row :gutter="gutter" class="quick-actions">
      <el-col :span="24">
        <el-card shadow="hover">
          <template #header>
            <span>快捷操作</span>
          </template>
          <el-row :gutter="gutter">
            <el-col :xs="12" :sm="6" :md="4">
              <router-link to="/orders" class="action-item">
                <el-icon :size="isMobile ? 24 : 32" color="#409eff"><List /></el-icon>
                <span>订单管理</span>
              </router-link>
            </el-col>
            <el-col :xs="12" :sm="6" :md="4">
              <router-link to="/nurses/audit" class="action-item">
                <el-icon :size="isMobile ? 24 : 32" color="#e6a23c"><Stamp /></el-icon>
                <span>资质审核</span>
              </router-link>
            </el-col>
            <el-col :xs="12" :sm="6" :md="4">
              <router-link to="/withdrawals" class="action-item">
                <el-icon :size="isMobile ? 24 : 32" color="#67c23a"><Wallet /></el-icon>
                <span>提现管理</span>
              </router-link>
            </el-col>
            <el-col :xs="12" :sm="6" :md="4">
              <router-link to="/evaluations" class="action-item">
                <el-icon :size="isMobile ? 24 : 32" color="#f56c6c"><Star /></el-icon>
                <span>评价管理</span>
              </router-link>
            </el-col>
            <el-col :xs="12" :sm="6" :md="4">
              <router-link to="/system/config" class="action-item">
                <el-icon :size="isMobile ? 24 : 32" color="#909399"><Setting /></el-icon>
                <span>系统设置</span>
              </router-link>
            </el-col>
            <el-col :xs="12" :sm="6" :md="4">
              <router-link to="/map" class="action-item">
                <el-icon :size="isMobile ? 24 : 32" color="#409eff"><Location /></el-icon>
                <span>地图视图</span>
              </router-link>
            </el-col>
          </el-row>
        </el-card>
      </el-col>
    </el-row>
    
    <!-- 欢迎信息 -->
    <el-row :gutter="20">
      <el-col :span="24">
        <el-card shadow="hover">
          <template #header>
            <span>系统说明</span>
          </template>
          <div class="welcome-content">
            <el-alert
              title="欢迎使用护理服务管理后台"
              type="success"
              description='本系统是“互联网+”护理服务APP的管理端，支持订单管理、护士资质审核、用户管理、评价管理、提现审核、系统配置等功能。'
              :closable="false"
              show-icon
            />
          </div>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<style scoped>
.dashboard-container {
  padding: 0;
}

.page-title {
  font-size: 20px;
  color: #303133;
  margin-bottom: 20px;
}

.stat-cards {
  margin-bottom: 20px;
}

.stat-card {
  margin-bottom: 20px;
}

.stat-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  padding: 20px;
}

.stat-icon {
  width: 60px;
  height: 60px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
  flex-shrink: 0;
}

.stat-info {
  margin-left: 16px;
}

.stat-value {
  font-size: 28px;
  font-weight: bold;
  color: #303133;
  line-height: 1.2;
}

.stat-label {
  font-size: 14px;
  color: #909399;
  margin-top: 4px;
}

.quick-actions {
  margin-bottom: 20px;
}

.action-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 20px;
  border-radius: 8px;
  text-decoration: none;
  color: #606266;
  transition: all 0.3s;
}

.action-item:hover {
  background-color: #f5f7fa;
  color: #409eff;
}

.action-item span {
  margin-top: 8px;
  font-size: 14px;
}

.welcome-content {
  padding: 10px 0;
}

@media (max-width: 768px) {
  .page-title {
    font-size: 16px;
    margin-bottom: 12px;
  }

  .stat-card :deep(.el-card__body) {
    padding: 14px;
  }

  .stat-icon {
    width: 44px;
    height: 44px;
  }

  .stat-value {
    font-size: 22px;
  }

  .stat-label {
    font-size: 12px;
  }

  .action-item {
    padding: 12px 8px;
  }

  .action-item span {
    font-size: 12px;
  }
}

@media (max-width: 480px) {
  .stat-icon {
    width: 36px;
    height: 36px;
  }

  .stat-value {
    font-size: 18px;
  }

  .stat-info {
    margin-left: 10px;
  }
}
</style>
