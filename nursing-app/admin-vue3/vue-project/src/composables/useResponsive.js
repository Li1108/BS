/**
 * 响应式设计 Composable
 * 基于VueUse实现的响应式工具函数
 */
import { useBreakpoints, breakpointsTailwind, useWindowSize } from '@vueuse/core'
import { computed } from 'vue'

export function useResponsive() {
  // 使用Tailwind断点
  const breakpoints = useBreakpoints(breakpointsTailwind)
  const { width, height } = useWindowSize()

  // 设备类型检测
  const isMobile = breakpoints.smaller('md') // < 768px
  const isTablet = breakpoints.between('md', 'lg') // 768px - 1024px
  const isDesktop = breakpoints.greater('lg') // > 1024px
  const isSmallMobile = breakpoints.smaller('sm') // < 640px

  // 屏幕尺寸范围
  const screenWidth = computed(() => width.value)
  const screenHeight = computed(() => height.value)

  // 响应式列数（用于Grid布局）
  const gridCols = computed(() => {
    if (isSmallMobile.value) return 1
    if (isMobile.value) return 2
    if (isTablet.value) return 3
    return 4
  })

  // 响应式Gutter（栅格间距）
  const gutter = computed(() => {
    if (isSmallMobile.value) return 8
    if (isMobile.value) return 12
    return 16
  })

  // 卡片列配置（用于el-row），始终返回固定对象供 v-bind 绑定
  const cardColSpan = { xs: 24, sm: 12, md: 12, lg: 6, xl: 6 }

  // 表格配置
  const tableConfig = computed(() => ({
    // 移动端隐藏部分列
    hiddenColumns: isMobile.value ? ['description', 'remark', 'updatedAt'] : [],
    // 分页大小选项
    pageSizes: isMobile.value ? [10, 20, 50] : [10, 20, 50, 100],
    // 默认每页条数
    defaultPageSize: isMobile.value ? 10 : 20,
    // 是否显示边框
    border: !isMobile.value,
    // 分页布局
    paginationLayout: isMobile.value
      ? 'total, prev, pager, next'
      : 'total, sizes, prev, pager, next, jumper'
  }))

  // 对话框宽度
  const dialogWidth = computed(() => {
    if (isSmallMobile.value) return '95%'
    if (isMobile.value) return '90%'
    if (isTablet.value) return '70%'
    return '650px'
  })

  // 抽屉宽度
  const drawerWidth = computed(() => {
    if (isSmallMobile.value) return '90%'
    if (isMobile.value) return '80%'
    if (isTablet.value) return '60%'
    return '500px'
  })

  // 表单标签宽度
  const formLabelWidth = computed(() => {
    if (isMobile.value) return '80px'
    return '100px'
  })

  // el-descriptions 列数（详情弹窗内）
  const descColumn = computed(() => {
    if (isMobile.value) return 1
    return 2
  })

  // 搜索表单布局
  const searchFormInline = computed(() => !isMobile.value)

  // 按钮尺寸
  const buttonSize = computed(() => {
    if (isSmallMobile.value) return 'small'
    return 'default'
  })

  return {
    // 设备检测
    isMobile,
    isTablet,
    isDesktop,
    isSmallMobile,
    
    // 屏幕尺寸
    screenWidth,
    screenHeight,
    
    // 布局配置
    gridCols,
    gutter,
    cardColSpan,
    
    // 组件配置
    tableConfig,
    dialogWidth,
    drawerWidth,
    formLabelWidth,
    descColumn,
    searchFormInline,
    buttonSize,
    
    // 原始breakpoints
    breakpoints
  }
}
