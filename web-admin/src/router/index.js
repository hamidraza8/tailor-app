import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/LoginView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/',
    component: () => import('@/components/AppLayout.vue'),
    meta: { requiresAuth: true },
    children: [
      { path: '', name: 'Dashboard', component: () => import('@/views/DashboardView.vue') },
      { path: 'approvals', name: 'Approvals', component: () => import('@/views/ApprovalsView.vue') },
      { path: 'partners', name: 'Partners', component: () => import('@/views/PartnersView.vue') },
      { path: 'assets', name: 'Assets', component: () => import('@/views/AssetsView.vue') },
      { path: 'inventory', name: 'Inventory', component: () => import('@/views/InventoryView.vue') },
      { path: 'customers', name: 'Customers', component: () => import('@/views/CustomersView.vue') },
      { path: 'orders', name: 'Orders', component: () => import('@/views/OrdersView.vue') },
      { path: 'invoices', name: 'Invoices', component: () => import('@/views/InvoicesView.vue') },
      { path: 'payments', name: 'Payments', component: () => import('@/views/PaymentsView.vue') },
      { path: 'expenses', name: 'Expenses', component: () => import('@/views/ExpensesView.vue') },
      { path: 'reports/profit', name: 'ProfitReport', component: () => import('@/views/ProfitReportView.vue') },
      { path: 'reports/labour', name: 'LabourReport', component: () => import('@/views/LabourReportView.vue') },
      { path: 'capital', name: 'capital-dashboard', component: () => import('@/views/CapitalDashboardView.vue') },
      { path: 'capital/add', name: 'add-capital', component: () => import('@/views/AddCapitalView.vue') },
      { path: 'spendings', name: 'spendings', component: () => import('@/views/SpendingsView.vue') },
      { path: 'spendings/add', name: 'add-spending', component: () => import('@/views/AddSpendingView.vue') },
      { path: 'reports/funding-splits', name: 'funding-splits', component: () => import('@/views/FundingSplitReportView.vue') },
      { path: 'reports/partner-ledger', name: 'partner-ledger', component: () => import('@/views/PartnerLedgerView.vue') },
      { path: 'settings', name: 'Settings', component: () => import('@/views/SettingsView.vue') },
      { path: 'audit-logs', name: 'AuditLogs', component: () => import('@/views/AuditLogsView.vue') },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach((to) => {
  const token = localStorage.getItem('token')
  if (to.meta.requiresAuth !== false && !token) {
    return '/login'
  }
  if (to.path === '/login' && token) {
    return '/'
  }
})

export default router
