<template>
  <div>
    <h1 class="text-h5 font-weight-bold mb-6">Dashboard</h1>

    <v-row>
      <v-col v-for="card in dashboardCards" :key="card.label" cols="12" sm="6" md="3">
        <v-card class="rounded-lg">
          <v-card-text class="d-flex align-center pa-5">
            <v-avatar :color="card.color" size="52" class="mr-4" rounded="lg">
              <v-icon :icon="card.icon" color="white" size="28" />
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">{{ card.label }}</div>
              <div class="text-h6 font-weight-bold">{{ card.prefix }}{{ formatNumber(card.value) }}</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-4">
      <v-col cols="12" md="6">
        <v-card class="rounded-lg">
          <v-card-title class="text-subtitle-1 font-weight-bold pa-4 pb-2">
            <v-icon class="mr-2" color="warning">mdi-clock-alert</v-icon>
            Pending Orders
          </v-card-title>
          <v-card-text>
            <div class="text-h3 font-weight-bold text-center py-6 text-warning">
              {{ stats.pendingOrders || 0 }}
            </div>
            <v-btn color="primary" variant="tonal" block to="/orders">View All Orders</v-btn>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="12" md="6">
        <v-card class="rounded-lg">
          <v-card-title class="text-subtitle-1 font-weight-bold pa-4 pb-2">
            <v-icon class="mr-2" color="error">mdi-check-decagram</v-icon>
            Pending Approvals
          </v-card-title>
          <v-card-text>
            <div class="text-h3 font-weight-bold text-center py-6 text-error">
              {{ stats.pendingApprovals || 0 }}
            </div>
            <v-btn color="primary" variant="tonal" block to="/approvals">Review Approvals</v-btn>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const stats = ref({})

const dashboardCards = computed(() => [
  { label: "Today's Sales", value: stats.value.todaySales, icon: 'mdi-cash-register', color: 'success', prefix: 'Rs ' },
  { label: 'Cash Received', value: stats.value.cashReceived, icon: 'mdi-cash-check', color: 'info', prefix: 'Rs ' },
  { label: 'Inventory Value', value: stats.value.inventoryValue, icon: 'mdi-warehouse', color: 'secondary', prefix: 'Rs ' },
  { label: 'Asset Value', value: stats.value.assetValue, icon: 'mdi-package-variant', color: 'primary', prefix: 'Rs ' },
  { label: 'Labour Payable', value: stats.value.labourPayable, icon: 'mdi-account-hard-hat', color: 'warning', prefix: 'Rs ' },
  { label: 'Net Profit (Est.)', value: stats.value.netProfitEstimate, icon: 'mdi-chart-line', color: 'accent', prefix: 'Rs ' },
  { label: 'Pending Orders', value: stats.value.pendingOrders, icon: 'mdi-clipboard-clock', color: 'orange', prefix: '' },
  { label: 'Pending Approvals', value: stats.value.pendingApprovals, icon: 'mdi-check-decagram', color: 'error', prefix: '' },
])

function formatNumber(val) {
  if (val == null) return '0'
  return Number(val).toLocaleString('en-PK')
}

onMounted(async () => {
  try {
    const { data } = await api.get('/reports/dashboard')
    stats.value = data
  } catch {
    appStore.showError('Failed to load dashboard data')
  }
})
</script>
