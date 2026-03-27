# 响应式设计使用指南

## 概述

本项目已集成 **@vueuse/core** 库实现完整的响应式设计，确保在桌面、平板和移动设备上都有良好的用户体验。

## 断点系统

使用 Tailwind CSS 断点标准：

| 断点 | 尺寸 | 设备 |
|------|------|------|
| `sm` | < 640px | 小屏手机 |
| `md` | < 768px | 移动设备 |
| `lg` | < 1024px | 平板设备 |
| `xl` | ≥ 1024px | 桌面设备 |

## 核心功能

### 1. useResponsive Composable

位置：`src/composables/useResponsive.js`

提供开箱即用的响应式配置：

```javascript
import { useResponsive } from '@/composables/useResponsive'

const { 
  isMobile,           // 是否移动端 (< 768px)
  isTablet,           // 是否平板 (768px - 1024px)
  isDesktop,          // 是否桌面 (> 1024px)
  isSmallMobile,      // 是否小屏手机 (< 640px)
  
  tableConfig,        // 表格配置
  dialogWidth,        // 弹窗宽度
  gutter,             // 栅格间距
  cardColSpan,        // 卡片列配置
  searchFormInline    // 搜索表单布局
} = useResponsive()
```

### 2. MainLayout 移动端适配

- **移动端菜单**：自动转换为抽屉模式
- **自动折叠**：根据屏幕尺寸自动调整
- **遮罩层**：移动端显示半透明遮罩

### 3. 表格响应式

```vue
<el-table 
  :border="tableConfig.border"
  ...
>
```

移动端特性：
- 自动移除边框
- 字体大小调整
- 隐藏次要列
- 紧凑布局

### 4. 分页响应式

```vue
<el-pagination
  :page-sizes="tableConfig.pageSizes"
  :layout="tableConfig.paginationLayout"
  ...
/>
```

移动端显示：`total, prev, pager, next`
桌面端显示：`total, sizes, prev, pager, next, jumper`

### 5. 表单响应式

```vue
<el-form :inline="searchFormInline" ...>
```

移动端自动切换为垂直布局。

### 6. 弹窗响应式

```vue
<el-dialog :width="dialogWidth" ...>
```

自动根据设备调整宽度：
- 小屏手机：95%
- 移动端：90%
- 平板：70%
- 桌面：固定宽度

### 7. 统计卡片响应式

```vue
<el-row :gutter="gutter" class="stats-row">
  <el-col v-bind="cardColSpan">
    ...
  </el-col>
</el-row>
```

自动调整列数和间距。

## 全局样式类

位置：`src/assets/responsive.css`

### 显示/隐藏工具类

```html
<!-- 仅桌面显示 -->
<div class="desktop-only">...</div>

<!-- 仅移动端显示 -->
<div class="mobile-only">...</div>

<!-- 移动端隐藏（表格列） -->
<el-table-column class="hidden-mobile">...</el-table-column>
```

### 移动端全宽

```html
<el-button class="mobile-full-width">提交</el-button>
```

## 已适配页面

✅ MainLayout（主布局）
✅ Orders（订单管理）
✅ Withdrawals（提现审核）
✅ Logs（操作日志）
✅ MapView（地图视图）
✅ NurseAudit（护士审核）
✅ Evaluations（评价管理）

## 开发指南

### 在新页面中使用

```vue
<script setup>
import { useResponsive } from '@/composables/useResponsive'

const { 
  isMobile, 
  tableConfig, 
  dialogWidth,
  gutter,
  cardColSpan,
  searchFormInline
} = useResponsive()
</script>

<template>
  <div class="page-container">
    <!-- 统计卡片 -->
    <el-row :gutter="gutter" class="stats-row">
      <el-col v-bind="cardColSpan">
        <el-card>...</el-card>
      </el-col>
    </el-row>

    <!-- 搜索表单 -->
    <el-form :inline="searchFormInline">
      ...
    </el-form>

    <!-- 表格 -->
    <el-table :border="tableConfig.border">
      <el-table-column label="ID" />
      <el-table-column label="名称" />
      <el-table-column label="备注" class="hidden-mobile" />
    </el-table>

    <!-- 分页 -->
    <el-pagination
      :page-sizes="tableConfig.pageSizes"
      :layout="tableConfig.paginationLayout"
    />

    <!-- 弹窗 -->
    <el-dialog :width="dialogWidth">
      ...
    </el-dialog>
  </div>
</template>
```

### 条件渲染

```vue
<template>
  <!-- 根据设备类型显示不同内容 -->
  <div v-if="isMobile">移动端视图</div>
  <div v-else>桌面端视图</div>

  <!-- 响应式按钮大小 -->
  <el-button :size="isMobile ? 'small' : 'default'">
    操作
  </el-button>
</template>
```

### 动态样式

```vue
<template>
  <div :class="{ 'mobile-layout': isMobile }">
    ...
  </div>
</template>

<style scoped>
.mobile-layout {
  padding: 8px;
}
</style>
```

## 测试指南

### 浏览器开发者工具

1. 打开 Chrome DevTools（F12）
2. 点击设备工具栏图标（Ctrl+Shift+M）
3. 选择不同设备预设：
   - iPhone SE (375px)
   - iPhone 12 Pro (390px)
   - iPad (768px)
   - iPad Pro (1024px)

### 推荐测试尺寸

- **320px**：超小屏手机
- **375px**：iPhone SE
- **768px**：平板竖屏
- **1024px**：平板横屏
- **1440px**：笔记本
- **1920px**：桌面显示器

## 性能优化

### 1. 防抖优化

窗口大小变化自动防抖，避免频繁重新渲染。

### 2. CSS优化

使用媒体查询而非JavaScript判断，提升性能。

### 3. 懒加载

移动端隐藏的组件不会渲染，减少DOM节点。

## 最佳实践

1. **优先使用 CSS**：能用CSS实现的尽量不用JS
2. **组件复用**：使用 `useResponsive` composable
3. **渐进增强**：确保移动端基础功能可用
4. **触摸优化**：移动端点击区域至少40px
5. **性能优先**：移动端减少动画和复杂交互

## 故障排查

### 问题：移动端布局错乱

检查是否使用了响应式配置：
```vue
<!-- ❌ 错误 -->
<el-row :gutter="16">

<!-- ✅ 正确 -->
<el-row :gutter="gutter">
```

### 问题：表格在移动端显示不全

添加隐藏次要列：
```vue
<el-table-column label="备注" class="hidden-mobile" />
```

### 问题：弹窗在移动端过宽

使用响应式宽度：
```vue
<!-- ❌ 错误 -->
<el-dialog width="800px">

<!-- ✅ 正确 -->
<el-dialog :width="dialogWidth">
```

## 浏览器支持

- Chrome >= 90
- Firefox >= 88
- Safari >= 14
- Edge >= 90
- 移动端：iOS Safari >= 14, Chrome Android >= 90

## 更新日志

### v1.0.0 (2026-01-25)

- ✅ 集成 @vueuse/core
- ✅ 实现 useResponsive composable
- ✅ MainLayout 移动端抽屉
- ✅ 全局响应式样式
- ✅ 适配所有主要页面
- ✅ 触摸优化
- ✅ 性能优化

## 参考资源

- [VueUse 官方文档](https://vueuse.org/)
- [Element Plus 响应式设计](https://element-plus.org/zh-CN/guide/design.html)
- [Tailwind CSS 断点](https://tailwindcss.com/docs/responsive-design)
