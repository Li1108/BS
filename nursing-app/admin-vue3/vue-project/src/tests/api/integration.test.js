/**
 * API集成测试
 * 测试实际的API调用（需要后端服务运行）
 */
import { describe, it, expect, beforeAll } from 'vitest'
import { login } from '@/api/auth'
import { getOrderList, getOrderStats } from '@/api/order'
import { getNurseList } from '@/api/nurse'
import { getConfigList } from '@/api/system'

// 这些测试需要后端服务运行在 http://localhost:8081
// 可以通过环境变量 VITE_API_BASE_URL 配置

describe.skip('Auth API Integration Tests', () => {
  let token

  it('应该成功登录并返回token', async () => {
    const response = await login({
      phone: '13800000000',
      password: 'admin123'
    })

    expect(response.code).toBe(200)
    expect(response.data).toHaveProperty('token')
    expect(response.data).toHaveProperty('userInfo')
    
    token = response.data.token
    localStorage.setItem('token', token)
  })

  it('应该拒绝错误的登录凭证', async () => {
    try {
      await login({
        phone: '13800000000',
        password: 'wrong-password'
      })
    } catch (error) {
      expect(error.message).toContain('密码错误')
    }
  })
})

describe.skip('Order API Integration Tests', () => {
  beforeAll(() => {
    // 设置测试token
    localStorage.setItem('token', 'test-token')
  })

  it('应该获取订单列表', async () => {
    const response = await getOrderList({
      page: 1,
      pageSize: 10
    })

    expect(response.code).toBe(200)
    expect(response.data).toHaveProperty('records')
    expect(response.data).toHaveProperty('total')
    expect(Array.isArray(response.data.records)).toBe(true)
  })

  it('应该获取订单统计数据', async () => {
    const response = await getOrderStats()

    expect(response.code).toBe(200)
    expect(response.data).toHaveProperty('todayCount')
    expect(response.data).toHaveProperty('pendingCount')
    expect(response.data).toHaveProperty('totalAmount')
  })

  it('应该支持订单状态筛选', async () => {
    const response = await getOrderList({
      page: 1,
      pageSize: 10,
      status: 1 // 待接单
    })

    expect(response.code).toBe(200)
    if (response.data.records.length > 0) {
      expect(response.data.records[0].status).toBe(1)
    }
  })
})

describe.skip('Nurse API Integration Tests', () => {
  beforeAll(() => {
    localStorage.setItem('token', 'test-token')
  })

  it('应该获取护士列表', async () => {
    const response = await getNurseList({
      page: 1,
      pageSize: 10
    })

    expect(response.code).toBe(200)
    expect(response.data).toHaveProperty('records')
    expect(Array.isArray(response.data.records)).toBe(true)
  })

  it('应该支持护士审核状态筛选', async () => {
    const response = await getNurseList({
      page: 1,
      pageSize: 10,
      auditStatus: 0 // 待审核
    })

    expect(response.code).toBe(200)
    if (response.data.records.length > 0) {
      expect(response.data.records[0].auditStatus).toBe(0)
    }
  })
})

describe.skip('System API Integration Tests', () => {
  beforeAll(() => {
    localStorage.setItem('token', 'test-token')
  })

  it('应该获取系统配置列表', async () => {
    const response = await getConfigList()

    expect(response.code).toBe(200)
    expect(Array.isArray(response.data)).toBe(true)
    
    if (response.data.length > 0) {
      expect(response.data[0]).toHaveProperty('configKey')
      expect(response.data[0]).toHaveProperty('configValue')
    }
  })
})
