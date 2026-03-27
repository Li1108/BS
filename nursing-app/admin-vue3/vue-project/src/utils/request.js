/**
 * Axios 封装 - API请求工具
 * 统一处理请求拦截、响应拦截、错误处理
 */
import axios from 'axios'
import { ElMessage, ElMessageBox } from 'element-plus'
import { useUserStore } from '@/stores/user'
import router from '@/router'

// 创建axios实例
const service = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api/v1',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// 请求拦截器
service.interceptors.request.use(
  (config) => {
    // 从localStorage获取token
    const token = localStorage.getItem('token')
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    console.error('请求错误:', error)
    return Promise.reject(error)
  }
)

// 响应拦截器
service.interceptors.response.use(
  (response) => {
    if (response.config?.responseType === 'blob' || response.config?.responseType === 'arraybuffer') {
      return response.data
    }
    const res = response.data

    // 后端返回格式: { code: 0, msg: 'success', data: {} }（兼容 message）
    // code === 0 表示成功
    if (res.code !== 0) {
      let errorMsg = res.msg || res.message || '请求失败'

      if (!res.msg && !res.message) {
        if (res.code === 400 || res.code === 40001) {
          errorMsg = '请求参数错误'
        } else if (res.code === 401 || res.code === 40100) {
          errorMsg = '未授权，请重新登录'
        } else if (res.code === 403 || res.code === 40300) {
          errorMsg = '拒绝访问'
        } else if (res.code === 404 || res.code === 40400) {
          errorMsg = '请求资源不存在'
        } else if (res.code === 500 || res.code === 50000) {
          errorMsg = '服务器内部错误'
        }
      }

      if (!response.config?.silent) {
        ElMessage.error(errorMsg)
      }

      // 40100: Token过期或未授权
      if (res.code === 40100 || res.code === 401) {
        ElMessageBox.confirm(
          '登录状态已过期，请重新登录',
          '提示',
          {
            confirmButtonText: '重新登录',
            cancelButtonText: '取消',
            type: 'warning'
          }
        ).then(() => {
          const userStore = useUserStore()
          userStore.logout()
          router.push('/login')
        })
      }

      const businessError = new Error(errorMsg)
      businessError.code = Number(res.code)
      businessError.raw = res
      businessError.__handled = true
      return Promise.reject(businessError)
    }

    return res
  },
  (error) => {
    console.error('响应错误:', error)

    let message = '网络错误，请稍后重试'
    if (error.response) {
      switch (error.response.status) {
        case 400:
          message = '请求参数错误'
          break
        case 401:
          message = '未授权，请重新登录'
          {
            const userStore = useUserStore()
            userStore.logout()
            router.push('/login')
          }
          break
        case 403:
          message = '拒绝访问'
          break
        case 404:
          message = '请求资源不存在'
          break
        case 500:
          message = '服务器内部错误'
          break
        default:
            message = error.response.data?.msg || error.response.data?.message || '请求失败'
      }
    } else if (error.code === 'ECONNABORTED') {
      message = '请求超时，请重试'
    }

    if (!error.config?.silent) {
      ElMessage.error(message)
    }
    error.__handled = true
    return Promise.reject(error)
  }
)

// 封装请求方法
export const get = (url, params, config = {}) => {
  const normalizedParams = params ? { ...params } : {}
  if (normalizedParams.pageNo === undefined && normalizedParams.page !== undefined) {
    normalizedParams.pageNo = normalizedParams.page
  }
  if (normalizedParams.pageSize === undefined && normalizedParams.size !== undefined) {
    normalizedParams.pageSize = normalizedParams.size
  }
  return service.get(url, { params: normalizedParams, ...config })
}

export const post = (url, data, config = {}) => {
  return service.post(url, data, config)
}

export const put = (url, data, config = {}) => {
  return service.put(url, data, config)
}

export const del = (url, params, config = {}) => {
  return service.delete(url, { params, ...config })
}

// 文件上传
export const upload = (url, file, config = {}) => {
  const formData = new FormData()
  formData.append('file', file)
  return service.post(url, formData, {
    headers: {
      'Content-Type': 'multipart/form-data'
    },
    ...config
  })
}

export default service
