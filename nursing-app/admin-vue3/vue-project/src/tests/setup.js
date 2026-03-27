/**
 * Vitest 全局配置
 * 在所有测试运行前执行
 */
import { vi } from 'vitest'
import { config } from '@vue/test-utils'
import ElementPlus from 'element-plus'

// 配置 Vue Test Utils
config.global.plugins = [ElementPlus]

// Mock localStorage with actual storage behavior
const createStorageMock = () => {
  let store = {}
  return {
    getItem: (key) => store[key] || null,
    setItem: (key, value) => { store[key] = value.toString() },
    removeItem: (key) => { delete store[key] },
    clear: () => { store = {} },
  }
}

global.localStorage = createStorageMock()
global.sessionStorage = createStorageMock()

// Mock window.matchMedia (for responsive design)
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
})

// Mock IntersectionObserver
global.IntersectionObserver = class IntersectionObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  takeRecords() {
    return []
  }
  unobserve() {}
}

// Mock ResizeObserver
global.ResizeObserver = class ResizeObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
}

// 设置测试环境变量
process.env.VITE_API_BASE_URL = 'http://localhost:8081/api/v1'
