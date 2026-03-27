/**
 * 组件单元测试示例
 * 测试 useResponsive composable
 */
import { describe, it, expect, beforeEach } from 'vitest'
import { useResponsive } from '@/composables/useResponsive'

describe('useResponsive Composable', () => {
  it('应该返回所有响应式属性', () => {
    const {
      isMobile,
      isTablet,
      isDesktop,
      isSmallMobile,
      screenWidth,
      screenHeight,
      gridCols,
      gutter,
      cardColSpan,
      tableConfig,
      dialogWidth,
      drawerWidth,
      formLabelWidth,
      searchFormInline,
      buttonSize
    } = useResponsive()

    // 验证所有属性都已定义
    expect(isMobile).toBeDefined()
    expect(isTablet).toBeDefined()
    expect(isDesktop).toBeDefined()
    expect(isSmallMobile).toBeDefined()
    expect(screenWidth).toBeDefined()
    expect(screenHeight).toBeDefined()
    expect(gridCols).toBeDefined()
    expect(gutter).toBeDefined()
    expect(cardColSpan).toBeDefined()
    expect(tableConfig).toBeDefined()
    expect(dialogWidth).toBeDefined()
    expect(drawerWidth).toBeDefined()
    expect(formLabelWidth).toBeDefined()
    expect(searchFormInline).toBeDefined()
    expect(buttonSize).toBeDefined()
  })

  it('表格配置应该包含必要属性', () => {
    const { tableConfig } = useResponsive()

    expect(tableConfig.value).toHaveProperty('hiddenColumns')
    expect(tableConfig.value).toHaveProperty('pageSizes')
    expect(tableConfig.value).toHaveProperty('defaultPageSize')
    expect(tableConfig.value).toHaveProperty('border')
    expect(tableConfig.value).toHaveProperty('paginationLayout')
  })

  it('cardColSpan应该是有效的Element Plus配置', () => {
    const { cardColSpan } = useResponsive()

    expect(cardColSpan).toHaveProperty('xs')
    expect(cardColSpan).toHaveProperty('sm')
    expect(cardColSpan).toHaveProperty('md')
    expect(cardColSpan).toHaveProperty('lg')
    expect(cardColSpan).toHaveProperty('xl')
  })
})
