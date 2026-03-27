<script setup>
/**
 * 护理服务管理后台 - 根组件
 */
import { onMounted } from 'vue'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()

onMounted(() => {
  // 初始化主题
  const theme = localStorage.getItem('theme') || 'light'
  document.documentElement.setAttribute('data-theme', theme)
})
</script>

<template>
  <el-config-provider>
    <router-view />
  </el-config-provider>
</template>

<style>
/* 全局样式重置 */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html, body, #app {
  width: 100%;
  height: 100%;
  max-width: 100vw;
  overflow-x: hidden;
  font-family: 'Helvetica Neue', Helvetica, 'PingFang SC', 'Hiragino Sans GB',
    'Microsoft YaHei', '微软雅黑', Arial, sans-serif;
}

/* 滚动条样式 */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}

::-webkit-scrollbar-thumb {
  background-color: #dcdfe6;
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background-color: #c0c4cc;
}

::-webkit-scrollbar-track {
  background-color: #f5f7fa;
}

/* Element Plus 全局样式调整 */
.el-message-box {
  max-width: 420px;
  width: 90% !important;
}

/* 移动端表格隐藏列 */
@media (max-width: 768px) {
  .hidden-mobile {
    display: none !important;
  }

  .el-dialog {
    margin: 5vh auto !important;
  }

  .el-pagination {
    flex-wrap: wrap;
    justify-content: center;
  }

  .el-pagination .el-pagination__sizes {
    display: none;
  }
}

@media (max-width: 480px) {
  .el-message-box {
    width: 95% !important;
  }

  .el-button + .el-button {
    margin-left: 4px;
  }
}
</style>
