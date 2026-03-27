<script setup>
/**
 * 系统配置页面
 * 功能：ElForm编辑sys_config（如费率、阿里云keys），通知管理（手动触发阿里云推送API）
 * 基于数据库设计：sys_config表 (config_key, config_value, description)
 */
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, ElMessageBox, ElNotification } from 'element-plus'
import { getConfigList, batchUpdateConfig, sendNotification, getNotificationList, getAliyunHealth } from '@/api/system'
import { getUserList } from '@/api/user'
import { getNurseList } from '@/api/nurse'
import { useResponsive } from '@/composables/useResponsive'

// ==================== 常量定义 ====================

const { isMobile, formLabelWidth, buttonSize } = useResponsive()
const router = useRouter()

// 配置分组
const configGroups = [
  {
    title: '平台基础设置',
    icon: 'Setting',
    color: '#409eff',
    keys: ['service_fee_rate', 'assign_max_retry', 'assign_retry_interval', 'upload_path'],
    descriptions: {
      'service_fee_rate': '平台抽成比例（0-1之间，如0.20表示20%）',
      'assign_max_retry': '派单最大重试次数',
      'assign_retry_interval': '派单重试间隔（秒）',
      'upload_path': '文件上传存储路径'
    }
  },
  {
    title: '高德地图配置',
    icon: 'Location',
    color: '#67c23a',
    keys: ['gaode_map_key'],
    descriptions: {
      'gaode_map_key': '高德地图Web服务API密钥'
    }
  },
  {
    title: '阿里云短信配置',
    icon: 'Message',
    color: '#e6a23c',
    keys: ['aliyun_sms_access_key', 'aliyun_sms_secret', 'aliyun_sms_sign_name'],
    descriptions: {
      'aliyun_sms_access_key': 'AccessKey（从阿里云控制台获取）',
      'aliyun_sms_secret': 'AccessKey Secret（请妥善保管）',
      'aliyun_sms_sign_name': '短信签名名称（需在阿里云审核通过）'
    }
  },
  {
    title: '阿里云移动推送配置',
    icon: 'Bell',
    color: '#f56c6c',
    keys: ['aliyun_push_app_key', 'aliyun_push_app_secret'],
    descriptions: {
      'aliyun_push_app_key': 'EMAS移动推送AppKey',
      'aliyun_push_app_secret': 'EMAS移动推送AppSecret'
    }
  }
]

// 通知类型映射
const notificationTypes = [
  { value: 1, label: '订单更新', icon: 'ShoppingCart', color: '#409eff' },
  { value: 2, label: '审核结果', icon: 'DocumentChecked', color: '#67c23a' },
  { value: 3, label: '系统消息', icon: 'InfoFilled', color: '#e6a23c' }
]

// 推送目标类型
const targetTypes = [
  { value: 'all', label: '全部用户' },
  { value: 'users', label: '普通用户' },
  { value: 'nurses', label: '所有护士' },
  { value: 'selected', label: '指定用户' }
]

// ==================== 状态定义 ====================

// 当前Tab
const activeTab = ref('config')

// 配置数据
const configList = ref([])
const loading = ref(false)
const saving = ref(false)
const healthChecking = ref(false)
const aliyunHealthDialogVisible = ref(false)
const aliyunHealth = ref(null)

// 推送通知表单
const notifyFormRef = ref(null)
const notifyForm = reactive({
  targetType: 'all',
  type: 3,
  title: '',
  content: '',
  userIds: []
})
const sendingNotify = ref(false)

// 用户/护士选择器
const userOptions = ref([])
const nurseOptions = ref([])
const loadingUsers = ref(false)

// 推送历史
const notifyHistory = ref([])
const historyLoading = ref(false)
const historyTotal = ref(0)
const historyPage = ref(1)

// 表单验证规则
const notifyRules = {
  title: [
    { required: true, message: '请输入通知标题', trigger: 'blur' },
    { min: 2, max: 50, message: '标题长度在2-50个字符之间', trigger: 'blur' }
  ],
  content: [
    { required: true, message: '请输入通知内容', trigger: 'blur' },
    { min: 5, max: 500, message: '内容长度在5-500个字符之间', trigger: 'blur' }
  ],
  type: [
    { required: true, message: '请选择通知类型', trigger: 'change' }
  ],
  userIds: [
    { 
      validator: (rule, value, callback) => {
        if (notifyForm.targetType === 'selected' && (!value || value.length === 0)) {
          callback(new Error('请选择接收用户'))
        } else {
          callback()
        }
      }, 
      trigger: 'change' 
    }
  ]
}

// ==================== 计算属性 ====================

// 是否显示用户选择器
const showUserSelector = computed(() => notifyForm.targetType === 'selected')

// 所有可选用户（用户+护士）
const allUserOptions = computed(() => {
  return [
    ...userOptions.value.map(u => ({ ...u, roleLabel: '用户' })),
    ...nurseOptions.value.map(n => ({ ...n, roleLabel: '护士' }))
  ]
})

// ==================== 方法定义 ====================

/**
 * 加载配置列表
 */
const loadConfig = async () => {
  loading.value = true
  try {
    const res = await getConfigList()
    configList.value = res.data || []
  } catch (error) {
    console.error('加载配置失败:', error)
    ElMessage.error('加载配置失败')
  } finally {
    loading.value = false
  }
}

/**
 * 获取配置值
 */
const getConfigValue = (key) => {
  const config = configList.value.find(c => c.configKey === key)
  return config?.configValue || ''
}

/**
 * 设置配置值
 */
const setConfigValue = (key, value) => {
  const config = configList.value.find(c => c.configKey === key)
  if (config) {
    config.configValue = value
  } else {
    // 如果配置不存在，添加新配置
    configList.value.push({
      configKey: key,
      configValue: value,
      remark: ''
    })
  }
}

/**
 * 获取配置描述
 */
const getConfigDescription = (key, group) => {
  // 优先使用分组中定义的描述
  if (group?.descriptions?.[key]) {
    return group.descriptions[key]
  }
  // 其次使用数据库中的描述
  const config = configList.value.find(c => c.configKey === key)
  return config?.remark || key
}

/**
 * 判断是否为敏感配置
 */
const isSensitiveConfig = (key) => {
  return key.includes('secret') || key.includes('password') || key.includes('key_secret')
}

/**
 * 保存配置
 */
const handleSave = async () => {
  saving.value = true
  try {
    const configs = configList.value.map(c => ({
      configKey: c.configKey,
      configValue: c.configValue,
      remark: c.remark || ''
    }))
    await batchUpdateConfig(configs)
    ElNotification({
      title: '保存成功',
      message: '系统配置已更新，部分配置可能需要重启服务生效',
      type: 'success',
      duration: 3000
    })
  } catch (error) {
    if (!error?.__handled) {
      ElMessage.error(error?.message || '保存失败')
    }
  } finally {
    saving.value = false
  }
}

/**
 * 重置配置（重新加载）
 */
const handleResetConfig = async () => {
  try {
    await ElMessageBox.confirm('确定要放弃当前修改并重新加载配置吗？', '确认', {
      type: 'warning'
    })
    await loadConfig()
    ElMessage.success('已重新加载配置')
  } catch {
    // 取消操作
  }
}

/**
 * 阿里云健康检查
 */
const handleAliyunHealthCheck = async () => {
  healthChecking.value = true
  try {
    const res = await getAliyunHealth()
    aliyunHealth.value = res?.data || null
    aliyunHealthDialogVisible.value = true

    const summary = aliyunHealth.value?.summary || {}
    if (summary.smsConfiguredButNotEnabled || summary.pushConfiguredButNotEnabled) {
      ElMessage.warning('检测到“已配置但未启用”项，请按需确认开关策略')
    } else {
      ElMessage.success('阿里云配置状态检测完成')
    }
  } catch (error) {
    console.error('阿里云健康检查失败:', error)
    ElMessage.error(error?.message || '阿里云健康检查失败')
  } finally {
    healthChecking.value = false
  }
}

/**
 * 加载用户和护士列表
 */
const loadUserOptions = async () => {
  if (userOptions.value.length > 0) return
  
  loadingUsers.value = true
  try {
    const [userRes, nurseRes] = await Promise.all([
      getUserList({ pageSize: 1000 }),
      getNurseList({ pageSize: 1000, auditStatus: 1 })
    ])
    
    userOptions.value = (userRes.data.records || []).map(u => ({
      id: u.id,
      label: `${u.username || u.nickname || u.phone} (${u.phone})`,
      phone: u.phone
    }))
    
    nurseOptions.value = (nurseRes.data.records || []).map(n => ({
      id: n.userId,
      label: `${n.realName} (${n.phone})`,
      phone: n.phone
    }))
  } catch (error) {
    console.error('加载用户列表失败:', error)
  } finally {
    loadingUsers.value = false
  }
}

/**
 * 加载推送历史
 */
const loadNotifyHistory = async () => {
  historyLoading.value = true
  try {
    const res = await getNotificationList({
      page: historyPage.value,
      pageSize: 10,
      type: 3 // 系统消息
    })
    notifyHistory.value = res.data.records || []
    historyTotal.value = res.data.total || 0
  } catch (error) {
    console.error('加载推送历史失败:', error)
  } finally {
    historyLoading.value = false
  }
}

/**
 * 发送通知
 */
const handleSendNotify = async () => {
  try {
    await notifyFormRef.value.validate()
  } catch {
    return
  }
  
  // 确认发送
  const targetText = targetTypes.find(t => t.value === notifyForm.targetType)?.label || ''
  const countText = notifyForm.targetType === 'selected' 
    ? `${notifyForm.userIds.length}个用户` 
    : targetText
  
  try {
    await ElMessageBox.confirm(
      `确定要向【${countText}】发送推送通知吗？`,
      '发送确认',
      {
        confirmButtonText: '确定发送',
        cancelButtonText: '取消',
        type: 'warning'
      }
    )
  } catch {
    return
  }
  
  sendingNotify.value = true
  try {
    const userIds =
      notifyForm.targetType === 'selected'
        ? notifyForm.userIds
        : notifyForm.targetType === 'users'
          ? userOptions.value.map(u => u.id)
          : notifyForm.targetType === 'nurses'
            ? nurseOptions.value.map(n => n.id)
            : undefined

    const content =
      notifyForm.title && notifyForm.title.trim()
        ? `【${notifyForm.title.trim()}】\n${notifyForm.content}`
        : notifyForm.content

    await sendNotification({
      type: notifyForm.type,
      content,
      userIds
    })
    
    ElNotification({
      title: '发送成功',
      message: `通知已通过阿里云移动推送发送给${countText}`,
      type: 'success',
      duration: 3000
    })
    
    // 重置表单
    handleResetNotifyForm()
    // 刷新历史
    loadNotifyHistory()
  } catch (error) {
    if (!error?.__handled) {
      ElMessage.error(error?.message || '发送失败，请检查推送配置')
    }
  } finally {
    sendingNotify.value = false
  }
}

/**
 * 重置通知表单
 */
const handleResetNotifyForm = () => {
  notifyForm.targetType = 'all'
  notifyForm.type = 3
  notifyForm.title = ''
  notifyForm.content = ''
  notifyForm.userIds = []
  notifyFormRef.value?.resetFields()
}

/**
 * 切换Tab
 */
const handleTabChange = (tab) => {
  if (tab === 'notify') {
    loadUserOptions()
    loadNotifyHistory()
  }
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

const goNotifyTemplates = () => {
  router.push('/system/notify-templates')
}

// ==================== 生命周期 ====================

onMounted(() => {
  loadConfig()
})
</script>

<template>
  <div class="config-container">
    <el-tabs v-model="activeTab" @tab-change="handleTabChange">
      <!-- 系统配置Tab -->
      <el-tab-pane label="系统配置" name="config">
        <el-card shadow="never" v-loading="loading">
          <template #header>
            <div class="card-header">
              <span class="title">系统配置管理</span>
              <div class="header-actions">
                <el-button :size="buttonSize" :loading="healthChecking" @click="handleAliyunHealthCheck">
                  <el-icon><Monitor /></el-icon>阿里云健康检查
                </el-button>
                <el-button :size="buttonSize" @click="handleResetConfig">
                  <el-icon><Refresh /></el-icon>重置
                </el-button>
                <el-button :size="buttonSize" type="primary" :loading="saving" @click="handleSave">
                  <el-icon><Check /></el-icon>保存配置
                </el-button>
              </div>
            </div>
          </template>
          
          <el-alert
            title="配置说明"
            type="warning"
            :closable="false"
            show-icon
            style="margin-bottom: 24px;"
          >
            <template #default>
              <p style="margin: 0;">修改配置后请点击保存按钮。敏感信息（如AccessKey Secret）请妥善保管，切勿泄露。部分配置修改后可能需要重启服务才能生效。</p>
            </template>
          </el-alert>
          
          <div v-for="group in configGroups" :key="group.title" class="config-group">
            <div class="group-header">
              <div class="group-icon" :style="{ backgroundColor: group.color }">
                <el-icon :size="18"><component :is="group.icon" /></el-icon>
              </div>
              <h3 class="group-title">{{ group.title }}</h3>
            </div>
            
            <el-form
              :label-width="formLabelWidth"
              :label-position="isMobile ? 'top' : 'right'"
              class="config-form"
            >
              <el-form-item
                v-for="key in group.keys"
                :key="key"
                :label="getConfigDescription(key, group)"
              >
                <el-input
                  :model-value="getConfigValue(key)"
                  @input="setConfigValue(key, $event)"
                  :placeholder="`请输入${getConfigDescription(key, group)}`"
                  :type="isSensitiveConfig(key) ? 'password' : 'text'"
                  :show-password="isSensitiveConfig(key)"
                  class="config-input"
                >
                  <template #suffix v-if="isSensitiveConfig(key)">
                    <el-icon class="sensitive-icon"><Lock /></el-icon>
                  </template>
                </el-input>
                <div class="config-key">
                  <el-tag size="small" type="info">{{ key }}</el-tag>
                </div>
              </el-form-item>
            </el-form>
          </div>
        </el-card>
      </el-tab-pane>
      
      <!-- 通知管理Tab -->
      <el-tab-pane label="通知管理" name="notify">
        <el-row :gutter="16">
          <!-- 发送通知 -->
          <el-col :xs="24" :lg="12">
            <el-card shadow="never">
              <template #header>
                <div class="card-header">
                  <span class="title">发送推送通知</span>
                  <el-tag type="info" size="small">阿里云移动推送</el-tag>
                </div>
              </template>
              
              <!-- 快速模板 -->
              <div class="quick-templates">
                <span class="template-label">通知模板：</span>
                <span class="template-tip">已迁移到独立页面统一维护（含新增、编辑、排序和启停）。</span>
                <el-button :size="buttonSize" class="template-button" type="primary" plain @click="goNotifyTemplates">
                  前往模板管理
                </el-button>
              </div>
              
              <el-form
                ref="notifyFormRef"
                :model="notifyForm"
                :rules="notifyRules"
                :label-width="formLabelWidth"
                :label-position="isMobile ? 'top' : 'right'"
                class="notify-form"
              >
                <el-form-item label="推送目标" prop="targetType">
                  <el-radio-group v-model="notifyForm.targetType" class="target-radio">
                    <el-radio-button 
                      v-for="target in targetTypes" 
                      :key="target.value" 
                      :value="target.value"
                    >
                      {{ target.label }}
                    </el-radio-button>
                  </el-radio-group>
                </el-form-item>
                
                <el-form-item 
                  v-if="showUserSelector" 
                  label="选择用户" 
                  prop="userIds"
                >
                  <el-select
                    v-model="notifyForm.userIds"
                    multiple
                    filterable
                    placeholder="请选择接收用户"
                    :loading="loadingUsers"
                    style="width: 100%;"
                  >
                    <el-option-group label="普通用户">
                      <el-option
                        v-for="user in userOptions"
                        :key="user.id"
                        :label="user.label"
                        :value="user.id"
                      />
                    </el-option-group>
                    <el-option-group label="护士">
                      <el-option
                        v-for="nurse in nurseOptions"
                        :key="nurse.id"
                        :label="nurse.label"
                        :value="nurse.id"
                      />
                    </el-option-group>
                  </el-select>
                </el-form-item>
                
                <el-form-item label="通知类型" prop="type">
                  <el-select v-model="notifyForm.type" class="notify-select">
                    <el-option
                      v-for="type in notificationTypes"
                      :key="type.value"
                      :label="type.label"
                      :value="type.value"
                    >
                      <el-icon :style="{ color: type.color }">
                        <component :is="type.icon" />
                      </el-icon>
                      <span style="margin-left: 8px;">{{ type.label }}</span>
                    </el-option>
                  </el-select>
                </el-form-item>
                
                <el-form-item label="通知标题" prop="title">
                  <el-input
                    v-model="notifyForm.title"
                    placeholder="请输入通知标题"
                    maxlength="50"
                    show-word-limit
                  />
                </el-form-item>
                
                <el-form-item label="通知内容" prop="content">
                  <el-input
                    v-model="notifyForm.content"
                    type="textarea"
                    :rows="4"
                    placeholder="请输入通知内容"
                    maxlength="500"
                    show-word-limit
                  />
                </el-form-item>
                
                <el-form-item>
                  <el-button :size="buttonSize" @click="handleResetNotifyForm">
                    <el-icon><Refresh /></el-icon>重置
                  </el-button>
                  <el-button 
                    :size="buttonSize"
                    type="primary" 
                    :loading="sendingNotify"
                    @click="handleSendNotify"
                  >
                    <el-icon><Promotion /></el-icon>
                    {{ sendingNotify ? '发送中...' : '发送通知' }}
                  </el-button>
                </el-form-item>
              </el-form>
            </el-card>
          </el-col>
          
          <!-- 推送历史 -->
          <el-col :xs="24" :lg="12">
            <el-card shadow="never">
              <template #header>
                <div class="card-header">
                  <span class="title">推送历史</span>
                  <el-button :size="buttonSize" text @click="loadNotifyHistory">
                    <el-icon><Refresh /></el-icon>刷新
                  </el-button>
                </div>
              </template>
              
              <el-table 
                :data="notifyHistory" 
                v-loading="historyLoading"
                :size="isMobile ? 'small' : 'default'"
                max-height="400"
              >
                <el-table-column prop="type" label="类型" width="90">
                  <template #default="{ row }">
                    <el-tag 
                      :type="row.type === 1 ? 'primary' : row.type === 2 ? 'success' : 'warning'"
                      size="small"
                    >
                      {{ notificationTypes.find(t => t.value === row.type)?.label || '未知' }}
                    </el-tag>
                  </template>
                </el-table-column>
                <el-table-column prop="content" label="内容" show-overflow-tooltip />
                <el-table-column prop="createdAt" label="发送时间" width="150">
                  <template #default="{ row }">
                    {{ formatTime(row.createdAt) }}
                  </template>
                </el-table-column>
              </el-table>
              
              <div v-if="historyTotal > 10" class="history-pagination">
                <el-pagination
                  v-model:current-page="historyPage"
                  :page-size="10"
                  :total="historyTotal"
                  layout="prev, pager, next"
                  small
                  @current-change="loadNotifyHistory"
                />
              </div>
              
              <el-empty 
                v-if="notifyHistory.length === 0 && !historyLoading" 
                description="暂无推送记录"
                :image-size="80"
              />
            </el-card>
            
            <!-- 推送说明 -->
            <el-card shadow="never" class="tips-card">
              <template #header>
                <span class="title">推送说明</span>
              </template>
              
              <div class="tips-content">
                <el-alert type="info" :closable="false" show-icon>
                  <template #title>阿里云移动推送集成</template>
                  <template #default>
                    <ul class="tips-list">
                      <li>推送通知通过阿里云EMAS移动推送服务发送</li>
                      <li>请确保已在"系统配置"中正确配置AppKey和AppSecret</li>
                      <li>用户需要在APP端授予通知权限才能收到推送</li>
                      <li>支持自有通道和厂商通道（华为、小米、OPPO、vivo）</li>
                    </ul>
                  </template>
                </el-alert>
              </div>
            </el-card>
          </el-col>
        </el-row>
      </el-tab-pane>
    </el-tabs>

    <el-dialog
      v-model="aliyunHealthDialogVisible"
      title="阿里云配置健康检查"
      width="720px"
      destroy-on-close
    >
      <template v-if="aliyunHealth">
        <div class="health-summary">
          <el-alert
            :title="(aliyunHealth?.summary?.smsConfiguredButNotEnabled || aliyunHealth?.summary?.pushConfiguredButNotEnabled)
              ? '检测到已配置但未启用项（当前符合降级策略）'
              : '未检测到已配置但未启用项'"
            :type="(aliyunHealth?.summary?.smsConfiguredButNotEnabled || aliyunHealth?.summary?.pushConfiguredButNotEnabled) ? 'warning' : 'success'"
            :closable="false"
            show-icon
          />
        </div>

        <el-row :gutter="16" class="health-cards">
          <el-col :xs="24" :md="12">
            <el-card shadow="never" class="health-card">
              <template #header>
                <div class="health-card-header">
                  <span>短信 SMS</span>
                  <el-tag :type="aliyunHealth?.sms?.configured ? 'success' : 'danger'" size="small">
                    {{ aliyunHealth?.sms?.configured ? '配置完整' : '配置缺失' }}
                  </el-tag>
                </div>
              </template>

              <div class="health-line">
                <span>固定验证码模式</span>
                <el-tag :type="aliyunHealth?.sms?.fixedCodeEnabled ? 'warning' : 'info'" size="small">
                  {{ aliyunHealth?.sms?.fixedCodeEnabled ? '开启' : '关闭' }}
                </el-tag>
              </div>
              <div class="health-line">
                <span>真实发送启用</span>
                <el-tag :type="aliyunHealth?.sms?.realSendEnabled ? 'success' : 'info'" size="small">
                  {{ aliyunHealth?.sms?.realSendEnabled ? '是' : '否' }}
                </el-tag>
              </div>
              <div class="health-line">
                <span>已配置但未启用</span>
                <el-tag :type="aliyunHealth?.sms?.configuredButNotEnabled ? 'warning' : 'success'" size="small">
                  {{ aliyunHealth?.sms?.configuredButNotEnabled ? '是' : '否' }}
                </el-tag>
              </div>

              <el-divider />
              <div class="health-missing">
                <span class="health-missing-title">缺失项</span>
                <el-space wrap>
                  <el-tag :type="aliyunHealth?.sms?.missing?.accessKeyId ? 'danger' : 'success'" size="small">accessKeyId</el-tag>
                  <el-tag :type="aliyunHealth?.sms?.missing?.accessKeySecret ? 'danger' : 'success'" size="small">accessKeySecret</el-tag>
                  <el-tag :type="aliyunHealth?.sms?.missing?.signName ? 'danger' : 'success'" size="small">signName</el-tag>
                  <el-tag :type="aliyunHealth?.sms?.missing?.templateCode ? 'danger' : 'success'" size="small">templateCode</el-tag>
                </el-space>
              </div>
            </el-card>
          </el-col>

          <el-col :xs="24" :md="12">
            <el-card shadow="never" class="health-card">
              <template #header>
                <div class="health-card-header">
                  <span>移动推送 Push</span>
                  <el-tag :type="aliyunHealth?.push?.configured ? 'success' : 'danger'" size="small">
                    {{ aliyunHealth?.push?.configured ? '配置完整' : '配置缺失' }}
                  </el-tag>
                </div>
              </template>

              <div class="health-line">
                <span>推送开关</span>
                <el-tag :type="aliyunHealth?.push?.pushEnabled ? 'success' : 'warning'" size="small">
                  {{ aliyunHealth?.push?.pushEnabled ? '开启' : '关闭' }}
                </el-tag>
              </div>
              <div class="health-line">
                <span>真实发送启用</span>
                <el-tag :type="aliyunHealth?.push?.realSendEnabled ? 'success' : 'info'" size="small">
                  {{ aliyunHealth?.push?.realSendEnabled ? '是' : '否' }}
                </el-tag>
              </div>
              <div class="health-line">
                <span>已配置但未启用</span>
                <el-tag :type="aliyunHealth?.push?.configuredButNotEnabled ? 'warning' : 'success'" size="small">
                  {{ aliyunHealth?.push?.configuredButNotEnabled ? '是' : '否' }}
                </el-tag>
              </div>

              <el-divider />
              <div class="health-missing">
                <span class="health-missing-title">缺失项</span>
                <el-space wrap>
                  <el-tag :type="aliyunHealth?.push?.missing?.appKey ? 'danger' : 'success'" size="small">appKey</el-tag>
                  <el-tag :type="aliyunHealth?.push?.missing?.accessKeyId ? 'danger' : 'success'" size="small">accessKeyId</el-tag>
                  <el-tag :type="aliyunHealth?.push?.missing?.accessKeySecret ? 'danger' : 'success'" size="small">accessKeySecret</el-tag>
                </el-space>
              </div>
            </el-card>
          </el-col>
        </el-row>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.config-container {
  padding: 0;
}

/* 卡片头部 */
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.card-header .title {
  font-size: 16px;
  font-weight: 600;
}

.header-actions {
  display: flex;
  gap: 8px;
}

/* 配置分组 */
.config-group {
  margin-bottom: 32px;
  padding-bottom: 24px;
  border-bottom: 1px dashed #ebeef5;
}

.config-group:last-child {
  margin-bottom: 0;
  padding-bottom: 0;
  border-bottom: none;
}

.group-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}

.group-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #fff;
}

.group-title {
  font-size: 16px;
  color: #303133;
  margin: 0;
  font-weight: 600;
}

/* 配置表单 */
.config-form {
  padding-left: 48px;
}

.config-input {
  max-width: 400px;
  width: 100%;
}

.config-form :deep(.el-form-item__label),
.notify-form :deep(.el-form-item__label) {
  white-space: normal;
  word-break: break-word;
  line-height: 1.4;
  height: auto;
  align-self: flex-start;
}

.config-form :deep(.el-form-item__content),
.notify-form :deep(.el-form-item__content) {
  min-width: 0;
}

.config-key {
  margin-top: 4px;
}

.sensitive-icon {
  color: #e6a23c;
}

/* 快速模板 */
.quick-templates {
  margin-bottom: 20px;
  padding: 12px;
  background-color: #f5f7fa;
  border-radius: 8px;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.template-button {
  min-width: 90px;
}

.template-label {
  color: #606266;
  font-size: 13px;
}

.template-tip {
  color: #909399;
  font-size: 13px;
}

/* 通知表单 */
.notify-form {
  margin-top: 16px;
}

.target-radio {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.notify-select {
  width: 200px;
}

/* 历史分页 */
.history-pagination {
  margin-top: 16px;
  display: flex;
  justify-content: center;
}

/* 提示卡片 */
.tips-card {
  margin-top: 16px;
}

.tips-content {
  padding: 0;
}

.tips-list {
  margin: 8px 0 0;
  padding-left: 20px;
  line-height: 1.8;
}

.health-summary {
  margin-bottom: 16px;
}

.health-cards {
  margin-top: 8px;
}

.health-card {
  height: 100%;
}

.health-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.health-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
  color: #606266;
}

.health-missing {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.health-missing-title {
  font-size: 12px;
  color: #909399;
}

.tips-list li {
  color: #606266;
  font-size: 13px;
}

/* 响应式 */
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
  
  .config-form {
    padding-left: 0;
  }
  
  .config-input {
    max-width: none;
    width: 100%;
  }
  
  .template-button {
    width: 100%;
  }
  
  .notify-form :deep(.el-form-item:last-child .el-form-item__content) {
    display: flex;
    gap: 8px;
  }
  
  .notify-form :deep(.el-form-item:last-child .el-button) {
    flex: 1;
  }
  
  .notify-select {
    width: 100%;
  }
  
  .quick-templates {
    flex-direction: column;
    align-items: flex-start;
  }
}
</style>
