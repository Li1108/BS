<script setup>
/**
 * 地图视图页面
 * 集成@amap/amap-jsapi-loader显示护士/订单位置
 * 功能：实时定位标记、地图控件、信息窗口、筛选显示
 */
import { ref, reactive, onMounted, onUnmounted, computed } from 'vue'
import { ElMessage, ElNotification } from 'element-plus'
import AMapLoader from '@amap/amap-jsapi-loader'
import { getNurseLocations } from '@/api/nurse'
import { getOrderList } from '@/api/order'
import { getOrderHeatmap } from '@/api/stats'
import { useResponsive } from '@/composables/useResponsive'

// ==================== 常量定义 ====================

const { isMobile, drawerWidth, buttonSize } = useResponsive()

// 高德地图配置
const amapKey = import.meta.env.VITE_AMAP_KEY
const AMAP_CONFIG = {
  key: amapKey,
  version: '2.0',
  plugins: [
    'AMap.Scale',
    'AMap.ToolBar',
    'AMap.Geolocation',
    'AMap.Marker',
    'AMap.InfoWindow',
    'AMap.Icon',
    'AMap.HeatMap'
  ]
}

// 护士状态配置
const NURSE_STATUS_MAP = {
  0: { label: '离线', color: '#909399' },
  1: { label: '空闲', color: '#67c23a' },
  2: { label: '服务中', color: '#e6a23c' },
  3: { label: '休息', color: '#f56c6c' }
}

// 订单状态配置
const ORDER_STATUS_MAP = {
  1: { label: '待接单', color: '#909399' },
  2: { label: '已派单', color: '#409eff' },
  3: { label: '已接单', color: '#409eff' },
  4: { label: '护士已到达', color: '#67c23a' },
  5: { label: '服务中', color: '#e6a23c' },
  6: { label: '已完成', color: '#67c23a' }
}

// ==================== 状态定义 ====================

// 地图实例
let map = null
let AMap = null
const markers = [] // 标记点集合
const infoWindow = ref(null) // 信息窗口
let heatmapLayer = null

// 数据
const nurses = ref([])
const orders = ref([])
const loading = ref(false)
const mapReady = ref(false)
const heatmapPoints = ref([])

// 显示控制
const displayOptions = reactive({
  showNurses: true,
  showOrders: true,
  showHeatmap: true,
  nurseStatus: [], // 筛选护士状态
  orderStatus: [] // 筛选订单状态
})

// 侧边栏控制
const sidebarVisible = ref(true)
const activeTab = ref('nurses')

// 自动刷新
const autoRefresh = ref(false)
let refreshTimer = null

// ==================== 计算属性 ====================

// 筛选后的护士
const filteredNurses = computed(() => {
  if (!displayOptions.showNurses) return []
  if (displayOptions.nurseStatus.length === 0) return nurses.value
  return nurses.value.filter(n => displayOptions.nurseStatus.includes(n.status))
})

// 筛选后的订单
const filteredOrders = computed(() => {
  if (!displayOptions.showOrders) return []
  if (displayOptions.orderStatus.length === 0) return orders.value
  return orders.value.filter(o => displayOptions.orderStatus.includes(o.status))
})

// 统计数据
const stats = computed(() => ({
  totalNurses: nurses.value.length,
  activeNurses: nurses.value.filter(n => n.status === 1 || n.status === 2).length,
  totalOrders: orders.value.length,
  activeOrders: orders.value.filter(o => o.status === 2 || o.status === 3).length
}))

const listHeight = computed(() => (isMobile.value ? 'calc(100vh - 320px)' : 'calc(100vh - 420px)'))

// ==================== 方法定义 ====================

/**
 * 初始化地图
 */
const initMap = async () => {
  try {
    // 加载高德地图SDK
    AMap = await AMapLoader.load(AMAP_CONFIG)
    
    // 创建地图实例
    map = new AMap.Map('map-container', {
      zoom: 12,
      center: [116.397428, 39.90923], // 默认北京天安门
      mapStyle: 'amap://styles/normal',
      viewMode: '2D'
    })
    
    // 添加比例尺控件
    const scale = new AMap.Scale({
      position: 'LB' // 左下角
    })
    map.addControl(scale)
    
    // 添加工具栏控件
    const toolbar = new AMap.ToolBar({
      position: 'RT' // 右上角
    })
    map.addControl(toolbar)
    
    // 创建信息窗口
    infoWindow.value = new AMap.InfoWindow({
      isCustom: false,
      autoMove: true,
      offset: new AMap.Pixel(0, -30)
    })
    
    mapReady.value = true
    
    // 加载数据
    await loadData()
    
    ElMessage.success('地图加载成功')
  } catch (error) {
    console.error('地图初始化失败:', error)
    ElMessage.error('地图加载失败，请检查网络连接')
  }
}

/**
 * 加载数据
 */
const loadData = async () => {
  if (!mapReady.value) return
  
  loading.value = true
  try {
    const [nurseRes, orderRes, heatRes] = await Promise.all([
      getNurseLocations(),
      getOrderList({ pageNo: 1, pageSize: 200 }),
      getOrderHeatmap()
    ])
    
    nurses.value = nurseRes.data || []
    orders.value = (orderRes?.data?.records || [])
      .map(item => ({
        ...item,
        latitude: Number(item.latitude || 0),
        longitude: Number(item.longitude || 0),
        totalPrice: Number(item.totalPrice || item.totalAmount || 0),
        serviceTime: item.serviceTime || item.appointmentTime,
        userName: item.userName || item.contactName || '',
        status: Number(item.status)
      }))
      .filter(item => [1, 2, 3, 4, 5].includes(item.status))

    heatmapPoints.value = (heatRes?.data || [])
      .map(item => ({
        lng: Number(item.lng),
        lat: Number(item.lat),
        count: Number(item.weight || 1)
      }))
      .filter(item => item.lng && item.lat)
    
    updateMarkers()
    updateHeatmap()
  } catch (error) {
    console.error('加载数据失败:', error)
    ElMessage.error('数据加载失败')
  } finally {
    loading.value = false
  }
}

/**
 * 更新标记点
 */
const updateMarkers = () => {
  if (!map || !AMap) return
  
  // 清除现有标记
  clearMarkers()
  
  // 添加护士标记
  filteredNurses.value.forEach(nurse => {
    if (nurse.locationLng && nurse.locationLat) {
      addNurseMarker(nurse)
    }
  })
  
  // 添加订单标记
  filteredOrders.value.forEach(order => {
    if (order.longitude && order.latitude) {
      addOrderMarker(order)
    }
  })
  
  // 自适应显示所有标记
  if (markers.length > 0) {
    map.setFitView(markers, false, [100, 100, 100, 100])
  }
}

const updateHeatmap = () => {
  if (!map || !AMap) return
  if (!displayOptions.showHeatmap) {
    if (heatmapLayer) {
      heatmapLayer.hide()
    }
    return
  }

  if (!heatmapLayer) {
    heatmapLayer = new AMap.HeatMap(map, {
      radius: 30,
      opacity: [0, 0.9],
      gradient: {
        0.2: '#a6d96a',
        0.4: '#fdae61',
        0.6: '#f46d43',
        0.8: '#d53e4f'
      }
    })
  }

  heatmapLayer.setDataSet({
    data: heatmapPoints.value,
    max: 8
  })
  heatmapLayer.show()
}

/**
 * 添加护士标记
 */
const addNurseMarker = (nurse) => {
  const statusInfo = NURSE_STATUS_MAP[nurse.status] || NURSE_STATUS_MAP[0]
  
  // 创建自定义图标
  const icon = new AMap.Icon({
    size: new AMap.Size(32, 32),
    image: `data:image/svg+xml;base64,${btoa(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
        <circle cx="16" cy="16" r="14" fill="${statusInfo.color}" opacity="0.3"/>
        <circle cx="16" cy="16" r="10" fill="${statusInfo.color}"/>
        <path d="M16 8 L20 12 L18 12 L18 18 L20 18 L16 22 L12 18 L14 18 L14 12 L12 12 Z" fill="white"/>
      </svg>
    `)}`,
    imageSize: new AMap.Size(32, 32)
  })
  
  const marker = new AMap.Marker({
    position: [nurse.locationLng, nurse.locationLat],
    icon: icon,
    title: nurse.realName,
    extData: { type: 'nurse', data: nurse },
    offset: new AMap.Pixel(-16, -16)
  })
  
  // 点击事件
  marker.on('click', () => {
    showNurseInfo(nurse, marker)
  })
  
  map.add(marker)
  markers.push(marker)
}

/**
 * 添加订单标记
 */
const addOrderMarker = (order) => {
  const statusInfo = ORDER_STATUS_MAP[order.status] || ORDER_STATUS_MAP[1]
  
  const icon = new AMap.Icon({
    size: new AMap.Size(32, 32),
    image: `data:image/svg+xml;base64,${btoa(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
        <path d="M16 2 L28 10 L28 22 L16 30 L4 22 L4 10 Z" fill="${statusInfo.color}" opacity="0.9"/>
        <circle cx="16" cy="16" r="6" fill="white"/>
      </svg>
    `)}`,
    imageSize: new AMap.Size(32, 32)
  })
  
  const marker = new AMap.Marker({
    position: [order.longitude, order.latitude],
    icon: icon,
    title: order.orderNo,
    extData: { type: 'order', data: order },
    offset: new AMap.Pixel(-16, -16)
  })
  
  // 点击事件
  marker.on('click', () => {
    showOrderInfo(order, marker)
  })
  
  map.add(marker)
  markers.push(marker)
}

/**
 * 清除所有标记
 */
const clearMarkers = () => {
  markers.forEach(marker => {
    map.remove(marker)
  })
  markers.length = 0
  if (infoWindow.value) {
    infoWindow.value.close()
  }
}

/**
 * 显示护士信息窗口
 */
const showNurseInfo = (nurse, marker) => {
  const statusInfo = NURSE_STATUS_MAP[nurse.status] || NURSE_STATUS_MAP[0]
  
  const content = `
    <div class="info-window">
      <h4 style="margin: 0 0 8px; color: #303133;">
        <span style="background: ${statusInfo.color}; color: white; padding: 2px 8px; border-radius: 3px; font-size: 12px;">
          ${statusInfo.label}
        </span>
        ${nurse.realName}
      </h4>
      <div style="color: #606266; line-height: 1.6;">
        <p style="margin: 4px 0;">📱 ${nurse.phone || '未绑定'}</p>
        <p style="margin: 4px 0;">🏥 ${nurse.hospitalName || '未关联医院'}</p>
        <p style="margin: 4px 0;">💼 完成订单: ${nurse.completedOrders || 0} 单</p>
        <p style="margin: 4px 0;">⭐ 评分: ${nurse.rating || '暂无'}</p>
        <p style="margin: 4px 0; font-size: 12px; color: #909399;">
          更新时间: ${formatTime(nurse.locationUpdateTime)}
        </p>
      </div>
    </div>
  `
  
  infoWindow.value.setContent(content)
  infoWindow.value.open(map, marker.getPosition())
}

/**
 * 显示订单信息窗口
 */
const showOrderInfo = (order, marker) => {
  const statusInfo = ORDER_STATUS_MAP[order.status] || ORDER_STATUS_MAP[1]
  
  const content = `
    <div class="info-window">
      <h4 style="margin: 0 0 8px; color: #303133;">
        <span style="background: ${statusInfo.color}; color: white; padding: 2px 8px; border-radius: 3px; font-size: 12px;">
          ${statusInfo.label}
        </span>
        订单 #${order.orderNo}
      </h4>
      <div style="color: #606266; line-height: 1.6;">
        <p style="margin: 4px 0;">🏥 ${order.serviceName}</p>
        <p style="margin: 4px 0;">👤 ${order.userName || '用户'}</p>
        <p style="margin: 4px 0;">👩‍⚕️ ${order.nurseName || '待分配'}</p>
        <p style="margin: 4px 0;">💰 ¥${order.totalPrice?.toFixed(2) || '0.00'}</p>
        <p style="margin: 4px 0;">📍 ${order.address || '地址信息加载中'}</p>
        <p style="margin: 4px 0; font-size: 12px; color: #909399;">
          ${formatTime(order.serviceTime)}
        </p>
      </div>
    </div>
  `
  
  infoWindow.value.setContent(content)
  infoWindow.value.open(map, marker.getPosition())
}

/**
 * 定位到指定护士
 */
const locateNurse = (nurse) => {
  if (!nurse.locationLng || !nurse.locationLat) {
    ElMessage.warning('该护士暂无位置信息')
    return
  }
  
  map.setZoomAndCenter(15, [nurse.locationLng, nurse.locationLat])
  
  // 查找对应的标记并显示信息窗口
  const marker = markers.find(m => {
    const data = m.getExtData()
    return data.type === 'nurse' && data.data.id === nurse.id
  })
  
  if (marker) {
    showNurseInfo(nurse, marker)
  }
}

/**
 * 定位到指定订单
 */
const locateOrder = (order) => {
  if (!order.longitude || !order.latitude) {
    ElMessage.warning('该订单暂无位置信息')
    return
  }
  
  map.setZoomAndCenter(15, [order.longitude, order.latitude])
  
  const marker = markers.find(m => {
    const data = m.getExtData()
    return data.type === 'order' && data.data.id === order.id
  })
  
  if (marker) {
    showOrderInfo(order, marker)
  }
}

/**
 * 显示控制变化
 */
const handleDisplayChange = () => {
  updateMarkers()
  updateHeatmap()
}

/**
 * 切换自动刷新
 */
const toggleAutoRefresh = () => {
  if (autoRefresh.value) {
    refreshTimer = setInterval(() => {
      loadData()
    }, 30000) // 30秒刷新一次
    ElNotification({
      title: '自动刷新已启用',
      message: '地图数据将每30秒自动更新',
      type: 'success',
      duration: 2000
    })
  } else {
    if (refreshTimer) {
      clearInterval(refreshTimer)
      refreshTimer = null
    }
    ElNotification({
      title: '自动刷新已关闭',
      type: 'info',
      duration: 2000
    })
  }
}

/**
 * 格式化时间
 */
const formatTime = (time) => {
  if (!time) return '未知'
  return new Date(time).toLocaleString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

/**
 * 获取护士状态标签类型
 */
const getNurseStatusType = (status) => {
  const map = { 0: 'info', 1: 'success', 2: 'warning', 3: 'danger' }
  return map[status] || 'info'
}

/**
 * 获取订单状态标签类型
 */
const getOrderStatusType = (status) => {
  const map = { 1: 'info', 2: 'primary', 3: 'primary', 4: 'success', 5: 'warning', 6: 'success' }
  return map[status] || 'info'
}

// ==================== 生命周期 ====================

onMounted(() => {
  initMap()
})

onUnmounted(() => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
  }
  if (map) {
    map.destroy()
  }
  heatmapLayer = null
})
</script>

<template>
  <div class="map-view-container">
    <!-- 左侧地图 -->
    <div class="map-section">
      <el-card shadow="never" class="map-card">
        <template #header>
          <div class="map-header">
            <div class="header-left">
              <span class="title">实时地图监控</span>
              <el-tag v-if="loading" type="info" effect="plain" size="small">
                <el-icon class="is-loading"><Loading /></el-icon>
                加载中...
              </el-tag>
            </div>
            <div class="header-right">
              <el-button-group :size="buttonSize">
                <el-button :size="buttonSize" @click="loadData">
                  <el-icon><Refresh /></el-icon>
                </el-button>
                <el-button :size="buttonSize" @click="sidebarVisible = !sidebarVisible">
                  <el-icon><Menu /></el-icon>
                </el-button>
              </el-button-group>
            </div>
          </div>
        </template>
        
        <!-- 地图容器 -->
        <div id="map-container" class="map-box"></div>
        
        <!-- 统计信息 -->
        <div class="map-stats">
          <div class="stat-item">
            <el-icon :size="16" color="#67c23a"><UserFilled /></el-icon>
            <span>在线护士: <b>{{ stats.activeNurses }}</b>/{{ stats.totalNurses }}</span>
          </div>
          <div class="stat-item">
            <el-icon :size="16" color="#409eff"><Document /></el-icon>
            <span>进行中订单: <b>{{ stats.activeOrders }}</b>/{{ stats.totalOrders }}</span>
          </div>
          <div class="stat-item">
            <el-switch
              v-model="autoRefresh"
              size="small"
              inline-prompt
              active-text="自动"
              inactive-text="手动"
              @change="toggleAutoRefresh"
            />
          </div>
        </div>
      </el-card>
    </div>
    
    <div
      v-if="sidebarVisible && isMobile"
      class="sidebar-mask"
      @click="sidebarVisible = false"
    ></div>

    <!-- 右侧面板 -->
    <transition name="slide">
      <div
        v-show="sidebarVisible"
        class="sidebar-section"
        :class="{ 'sidebar-drawer': isMobile }"
        :style="isMobile ? { width: drawerWidth } : null"
      >
        <el-card shadow="never" class="sidebar-card">
          <!-- 筛选控制 -->
          <div class="filter-section">
            <el-divider content-position="left">显示控制</el-divider>
            <div class="filter-group">
              <el-checkbox
                v-model="displayOptions.showNurses"
                @change="handleDisplayChange"
              >
                显示护士 ({{ filteredNurses.length }})
              </el-checkbox>
              <el-checkbox-group
                v-if="displayOptions.showNurses"
                v-model="displayOptions.nurseStatus"
                size="small"
                @change="handleDisplayChange"
              >
                <el-checkbox-button :label="0">离线</el-checkbox-button>
                <el-checkbox-button :label="1">空闲</el-checkbox-button>
                <el-checkbox-button :label="2">服务中</el-checkbox-button>
                <el-checkbox-button :label="3">休息</el-checkbox-button>
              </el-checkbox-group>
            </div>
            
            <div class="filter-group">
              <el-checkbox
                v-model="displayOptions.showHeatmap"
                @change="handleDisplayChange"
              >
                显示订单热力图
              </el-checkbox>
            </div>

            <div class="filter-group">
              <el-checkbox
                v-model="displayOptions.showOrders"
                @change="handleDisplayChange"
              >
                显示订单 ({{ filteredOrders.length }})
              </el-checkbox>
              <el-checkbox-group
                v-if="displayOptions.showOrders"
                v-model="displayOptions.orderStatus"
                size="small"
                @change="handleDisplayChange"
              >
                <el-checkbox-button :label="1">待接单</el-checkbox-button>
                <el-checkbox-button :label="2">已派单</el-checkbox-button>
                <el-checkbox-button :label="3">已接单</el-checkbox-button>
                <el-checkbox-button :label="5">服务中</el-checkbox-button>
              </el-checkbox-group>
            </div>
          </div>
          
          <!-- 列表 -->
          <el-tabs v-model="activeTab" class="list-tabs">
            <!-- 护士列表 -->
            <el-tab-pane label="护士列表" name="nurses">
              <div class="list-container">
                <el-scrollbar :height="listHeight">
                  <div
                    v-for="nurse in filteredNurses"
                    :key="nurse.id"
                    class="list-item"
                    @click="locateNurse(nurse)"
                  >
                    <div class="item-header">
                      <el-avatar :size="32">{{ nurse.realName?.charAt(0) }}</el-avatar>
                      <div class="item-info">
                        <span class="name">{{ nurse.realName }}</span>
                        <el-tag
                          :type="getNurseStatusType(nurse.status)"
                          size="small"
                          effect="plain"
                        >
                          {{ NURSE_STATUS_MAP[nurse.status]?.label }}
                        </el-tag>
                      </div>
                    </div>
                    <div class="item-detail">
                      <span>📱 {{ nurse.phone }}</span>
                      <span>⭐ {{ nurse.rating || '暂无' }}</span>
                    </div>
                  </div>
                  <el-empty
                    v-if="filteredNurses.length === 0"
                    description="暂无护士数据"
                    :image-size="80"
                  />
                </el-scrollbar>
              </div>
            </el-tab-pane>
            
            <!-- 订单列表 -->
            <el-tab-pane label="订单列表" name="orders">
              <div class="list-container">
                <el-scrollbar :height="listHeight">
                  <div
                    v-for="order in filteredOrders"
                    :key="order.id"
                    class="list-item"
                    @click="locateOrder(order)"
                  >
                    <div class="item-header">
                      <div class="item-info" style="flex: 1;">
                        <span class="name">#{{ order.orderNo }}</span>
                        <el-tag
                          :type="getOrderStatusType(order.status)"
                          size="small"
                          effect="plain"
                        >
                          {{ ORDER_STATUS_MAP[order.status]?.label }}
                        </el-tag>
                      </div>
                    </div>
                    <div class="item-detail">
                      <span>🏥 {{ order.serviceName }}</span>
                      <span>💰 ¥{{ order.totalPrice?.toFixed(2) }}</span>
                    </div>
                    <div class="item-detail">
                      <span style="font-size: 12px; color: #909399;">
                        {{ formatTime(order.serviceTime) }}
                      </span>
                    </div>
                  </div>
                  <el-empty
                    v-if="filteredOrders.length === 0"
                    description="暂无订单数据"
                    :image-size="80"
                  />
                </el-scrollbar>
              </div>
            </el-tab-pane>
          </el-tabs>
        </el-card>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.map-view-container {
  display: flex;
  gap: 16px;
  height: calc(100vh - 120px);
  min-height: 600px;
}

/* 地图区域 */
.map-section {
  flex: 1;
  min-width: 0;
}

.map-card {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.map-card :deep(.el-card__body) {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 0;
}

.map-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.header-left .title {
  font-size: 16px;
  font-weight: 600;
}

.map-box {
  flex: 1;
  width: 100%;
  min-height: 500px;
  background: #f5f7fa;
}

.map-stats {
  display: flex;
  justify-content: space-around;
  align-items: center;
  padding: 12px 16px;
  background: linear-gradient(135deg, #f5f7fa 0%, #e8eef5 100%);
  border-top: 1px solid #ebeef5;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: #606266;
}

.stat-item b {
  color: #303133;
  font-size: 15px;
}

/* 遮罩 */
.sidebar-mask {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.35);
  z-index: 998;
}

/* 侧边栏 */
.sidebar-section {
  width: 320px;
  flex-shrink: 0;
}

.sidebar-drawer {
  position: fixed;
  right: 0;
  top: 64px;
  bottom: 0;
  z-index: 999;
  background: #fff;
  box-shadow: -2px 0 12px rgba(0, 0, 0, 0.12);
}

.sidebar-card {
  height: 100%;
}

.sidebar-card :deep(.el-card__body) {
  padding: 16px;
  height: 100%;
  overflow: hidden;
}

/* 筛选区域 */
.filter-section {
  margin-bottom: 16px;
}

.filter-group {
  margin-bottom: 12px;
}

.filter-group :deep(.el-checkbox) {
  margin-bottom: 8px;
}

.filter-group :deep(.el-checkbox-group) {
  margin-left: 24px;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

/* 列表 */
.list-tabs {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.list-tabs :deep(.el-tabs__content) {
  flex: 1;
}

.list-container {
  margin-top: 8px;
}

.list-item {
  padding: 12px;
  margin-bottom: 8px;
  background: #f5f7fa;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.3s;
}

.list-item:hover {
  background: #e8eef5;
  transform: translateX(4px);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.item-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px;
}

.item-info {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
}

.item-info .name {
  font-weight: 500;
  color: #303133;
}

.item-detail {
  display: flex;
  justify-content: space-between;
  font-size: 13px;
  color: #606266;
  margin-top: 4px;
}

/* 动画 */
.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease;
}

.slide-enter-from,
.slide-leave-to {
  transform: translateX(100%);
  opacity: 0;
}

/* 响应式 */
@media (max-width: 1200px) {
  .sidebar-section {
    position: fixed;
    right: 16px;
    top: 80px;
    bottom: 16px;
    z-index: 999;
    box-shadow: -2px 0 8px rgba(0, 0, 0, 0.1);
  }
}

@media (max-width: 768px) {
  .map-view-container {
    height: calc(100vh - 100px);
    min-height: 520px;
  }
  
  .map-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }
  
  .header-right {
    width: 100%;
    display: flex;
    justify-content: flex-end;
  }
  
  .map-box {
    min-height: 360px;
  }
  
  .map-stats {
    flex-direction: column;
    align-items: flex-start;
    gap: 6px;
  }
  
  .stat-item {
    width: 100%;
    justify-content: space-between;
  }
  
  .sidebar-drawer {
    top: 64px;
    bottom: 0;
    right: 0;
    border-radius: 0;
  }
  
  .sidebar-card :deep(.el-card__body) {
    padding: 12px;
  }
  
  .filter-group :deep(.el-checkbox-group) {
    margin-left: 0;
  }
  
  .list-item {
    padding: 10px;
  }
  
  .item-detail {
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
  }
}
</style>

<style>
/* 全局样式 - 信息窗口 */
.info-window {
  min-width: 200px;
  padding: 4px;
}

.info-window h4 {
  display: flex;
  align-items: center;
  gap: 8px;
}

.info-window p {
  white-space: nowrap;
}
</style>
