/**
 * Vue Router 配置
 * 包含路由守卫、权限校验
 */
import { createRouter, createWebHistory } from 'vue-router'
import { ElMessage } from 'element-plus'
import { useUserStore } from '@/stores/user'

// 路由配置
const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/login/index.vue'),
    meta: {
      title: '登录',
      requiresAuth: false
    }
  },
  {
    path: '/',
    component: () => import('@/layouts/MainLayout.vue'),
    redirect: '/dashboard',
    meta: {
      requiresAuth: true,
      roles: ['ADMIN_SUPER']
    },
    children: [
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/dashboard/index.vue'),
        meta: {
          title: '控制台',
          icon: 'Odometer'
        }
      },
      {
        path: 'data-dashboard',
        name: 'DataDashboard',
        component: () => import('@/views/data-dashboard.vue'),
        meta: {
          title: '数据看板',
          icon: 'DataAnalysis'
        }
      },
      // 订单管理
      {
        path: 'orders',
        name: 'Orders',
        component: () => import('@/views/orders/index.vue'),
        meta: {
          title: '订单管理',
          icon: 'List'
        }
      },
      // 护士管理
      {
        path: 'nurses',
        name: 'Nurses',
        redirect: '/nurses/list',
        meta: {
          title: '护士管理',
          icon: 'UserFilled'
        },
        children: [
          {
            path: 'list',
            name: 'NurseList',
            component: () => import('@/views/nurses/list.vue'),
            meta: {
              title: '护士列表'
            }
          },
          {
            path: 'audit',
            name: 'NurseAudit',
            component: () => import('@/views/nurses/audit.vue'),
            meta: {
              title: '资质审核'
            }
          },
          {
            path: 'hospital-change',
            name: 'NurseHospitalChangeAudit',
            component: () => import('@/views/nurses/hospital-change.vue'),
            meta: {
              title: '医院变更审核'
            }
          }
        ]
      },
      // 用户管理
      {
        path: 'users',
        name: 'Users',
        component: () => import('@/views/users/index.vue'),
        meta: {
          title: '用户管理',
          icon: 'User'
        }
      },
      // 服务管理
      {
        path: 'services',
        name: 'Services',
        component: () => import('@/views/services/index.vue'),
        meta: {
          title: '服务管理',
          icon: 'FirstAidKit'
        }
      },
      // 评价管理
      {
        path: 'evaluations',
        name: 'Evaluations',
        component: () => import('@/views/evaluations/index.vue'),
        meta: {
          title: '评价管理',
          icon: 'Star'
        }
      },
      // 提现管理
      {
        path: 'withdrawals',
        name: 'Withdrawals',
        component: () => import('@/views/withdrawals/index.vue'),
        meta: {
          title: '提现管理',
          icon: 'Wallet'
        }
      },
      // 通知管理
      {
        path: 'notifications',
        name: 'Notifications',
        component: () => import('@/views/notifications/index.vue'),
        meta: {
          title: '通知管理',
          icon: 'Bell'
        }
      },
      {
        path: 'sos',
        name: 'Sos',
        component: () => import('@/views/sos/index.vue'),
        meta: {
          title: 'SOS事件',
          icon: 'WarningFilled'
        }
      },
      // 系统设置
      {
        path: 'system',
        name: 'System',
        redirect: '/system/config',
        meta: {
          title: '系统设置',
          icon: 'Setting'
        },
        children: [
          {
            path: 'config',
            name: 'SystemConfig',
            component: () => import('@/views/system/config.vue'),
            meta: {
              title: '系统配置'
            }
          },
          {
            path: 'logs',
            name: 'OperationLogs',
            component: () => import('@/views/system/logs.vue'),
            meta: {
              title: '操作日志'
            }
          },
          {
            path: 'sms',
            name: 'SmsRecords',
            component: () => import('@/views/system/sms.vue'),
            meta: {
              title: '短信记录'
            }
          },
          {
            path: 'notify-templates',
            name: 'NotifyTemplates',
            component: () => import('@/views/system/notify-templates.vue'),
            meta: {
              title: '通知模板'
            }
          },
          {
            path: 'risk-orders',
            name: 'RiskOrders',
            component: () => import('@/views/system/risk-orders.vue'),
            meta: {
              title: '异常订单预警'
            }
          }
        ]
      },
      // 地图视图
      {
        path: 'map',
        name: 'MapView',
        component: () => import('@/views/map/index.vue'),
        meta: {
          title: '地图视图',
          icon: 'Location'
        }
      }
    ]
  },
  // 404页面
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('@/views/error/404.vue'),
    meta: {
      title: '页面不存在',
      requiresAuth: false
    }
  }
]

// 创建路由实例
const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    } else {
      return { top: 0 }
    }
  }
})

// 白名单路由（不需要登录）
const whiteList = ['/login']

// 路由守卫 - 前置守卫
router.beforeEach(async (to, from, next) => {
  // 设置页面标题
  document.title = to.meta.title ? `${to.meta.title} - 护理服务管理后台` : '护理服务管理后台'
  
  const userStore = useUserStore()
  const token = userStore.token
  
  // 有token
  if (token) {
    if (to.path === '/login') {
      // 已登录，访问登录页则跳转到首页
      next({ path: '/' })
    } else {
      // 校验用户信息
      if (userStore.userInfo) {
        // 校验ADMIN角色权限
        if (to.meta.roles && to.meta.roles.length > 0) {
          const hasPermission = to.meta.roles.includes(userStore.userInfo.role)
          if (hasPermission) {
            next()
          } else {
            ElMessage.error('您没有权限访问该页面')
            next({ path: '/login' })
          }
        } else {
          next()
        }
      } else {
        try {
          // 获取用户信息
          await userStore.fetchUserInfo()
          
          // 再次校验是否为ADMIN
          if (userStore.isAdmin) {
            next({ ...to, replace: true })
          } else {
            ElMessage.error('此账号无管理后台访问权限')
            userStore.logout()
            next({ path: '/login' })
          }
        } catch (error) {
          // 获取用户信息失败，清除token并跳转登录
          userStore.logout()
          ElMessage.error('登录状态已过期，请重新登录')
          next({ path: '/login', query: { redirect: to.fullPath } })
        }
      }
    }
  } else {
    // 没有token
    if (whiteList.includes(to.path)) {
      // 在白名单中，直接进入
      next()
    } else {
      // 不在白名单，跳转到登录页
      next({ path: '/login', query: { redirect: to.fullPath } })
    }
  }
})

// 路由守卫 - 后置守卫
router.afterEach((to) => {
  // 可以在这里添加页面加载完成后的逻辑
  // 例如：关闭loading、记录访问日志等
})

export default router
