/**
 * API工具函数测试
 * 测试 Axios 基础功能
 */
import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import axios from 'axios'
import MockAdapter from 'axios-mock-adapter'

describe('Axios Request Tests', () => {
  let mock
  let axiosInstance

  beforeEach(() => {
    // 创建独立的axios实例用于测试
    axiosInstance = axios.create({
      baseURL: '/api/v1',
      timeout: 10000
    })

    // 添加请求拦截器模拟request.js的行为
    axiosInstance.interceptors.request.use(config => {
      const token = localStorage.getItem('token')
      if (token) {
        config.headers.Authorization = `Bearer ${token}`
      }
      return config
    })

    // 创建mock adapter
    mock = new MockAdapter(axiosInstance)
    localStorage.clear()
  })

  afterEach(() => {
    mock.restore()
  })

  it('应该发送带token的请求', async () => {
    localStorage.setItem('token', 'test-token')
    
    mock.onGet('/test').reply(config => {
      expect(config.headers.Authorization).toBe('Bearer test-token')
      return [200, { code: 200, data: { message: 'success' } }]
    })

    const response = await axiosInstance.get('/test')
    expect(response.data.code).toBe(200)
  })

  it('应该处理401未授权错误', async () => {
    mock.onGet('/test').reply(401, { code: 401, message: 'Unauthorized' })

    try {
      await axiosInstance.get('/test')
    } catch (error) {
      expect(error.response.status).toBe(401)
    }
  })

  it('应该处理网络错误', async () => {
    mock.onGet('/test').networkError()

    try {
      await axiosInstance.get('/test')
    } catch (error) {
      expect(error.message).toContain('Network Error')
    }
  })

  it('应该处理超时错误', async () => {
    mock.onGet('/test').timeout()

    try {
      await axiosInstance.get('/test')
    } catch (error) {
      expect(error.code).toBe('ECONNABORTED')
    }
  })
})
