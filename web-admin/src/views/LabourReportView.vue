<template>
  <div>
    <h1 class="text-h5 font-weight-bold mb-6">Labour Report</h1>

    <!-- Summary Cards -->
    <v-row class="mb-4">
      <v-col cols="12" sm="4">
        <v-card class="rounded-lg">
          <v-card-text class="d-flex align-center pa-5">
            <v-avatar color="warning" size="52" class="mr-4" rounded="lg">
              <v-icon color="white" size="28">mdi-account-hard-hat</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Total Workers</div>
              <div class="text-h6 font-weight-bold">{{ report.totalWorkers || 0 }}</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="12" sm="4">
        <v-card class="rounded-lg">
          <v-card-text class="d-flex align-center pa-5">
            <v-avatar color="error" size="52" class="mr-4" rounded="lg">
              <v-icon color="white" size="28">mdi-cash-clock</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Total Payable</div>
              <div class="text-h6 font-weight-bold">Rs {{ formatNumber(report.totalPayable) }}</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
      <v-col cols="12" sm="4">
        <v-card class="rounded-lg">
          <v-card-text class="d-flex align-center pa-5">
            <v-avatar color="success" size="52" class="mr-4" rounded="lg">
              <v-icon color="white" size="28">mdi-cash-check</v-icon>
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">Total Paid</div>
              <div class="text-h6 font-weight-bold">Rs {{ formatNumber(report.totalPaid) }}</div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- Workers Table -->
    <v-card class="rounded-lg">
      <v-card-title class="text-subtitle-1 font-weight-bold pa-4 pb-2">
        Worker-wise Breakdown
      </v-card-title>
      <v-data-table
        :headers="headers"
        :items="report.workers || []"
        :loading="loading"
        items-per-page="15"
      >
        <template #item.totalEarned="{ item }">
          Rs {{ formatNumber(item.totalEarned) }}
        </template>
        <template #item.totalPaid="{ item }">
          <span class="text-success">Rs {{ formatNumber(item.totalPaid) }}</span>
        </template>
        <template #item.balance="{ item }">
          <v-chip
            :color="(item.totalEarned - item.totalPaid) > 0 ? 'error' : 'success'"
            size="small"
            variant="flat"
          >
            Rs {{ formatNumber(item.totalEarned - item.totalPaid) }}
          </v-chip>
        </template>
        <template #item.ordersCompleted="{ item }">
          {{ item.ordersCompleted || 0 }}
        </template>
      </v-data-table>
    </v-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const loading = ref(false)
const report = ref({})

const headers = [
  { title: 'Worker Name', key: 'name' },
  { title: 'Role', key: 'role' },
  { title: 'Orders Done', key: 'ordersCompleted' },
  { title: 'Total Earned', key: 'totalEarned' },
  { title: 'Total Paid', key: 'totalPaid' },
  { title: 'Balance Due', key: 'balance', sortable: false },
]

function formatNumber(val) {
  return val != null ? Number(val).toLocaleString('en-PK') : '0'
}

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await api.get('/reports/labour-payable')
    report.value = data.data || data || {}
  } catch {
    appStore.showError('Failed to load labour report')
  } finally {
    loading.value = false
  }
})
</script>
