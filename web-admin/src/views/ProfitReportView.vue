<template>
  <div>
    <h1 class="text-h5 font-weight-bold mb-6">Profit Report</h1>

    <!-- Date Range Filter -->
    <v-card class="rounded-lg mb-6 pa-4">
      <v-row align="center">
        <v-col cols="12" sm="4">
          <v-text-field v-model="dateFrom" label="From Date" type="date" hide-details />
        </v-col>
        <v-col cols="12" sm="4">
          <v-text-field v-model="dateTo" label="To Date" type="date" hide-details />
        </v-col>
        <v-col cols="12" sm="4">
          <v-btn color="primary" block @click="loadReport" :loading="loading">
            <v-icon start>mdi-chart-line</v-icon> Generate Report
          </v-btn>
        </v-col>
      </v-row>
    </v-card>

    <!-- Profit Formula Card -->
    <v-card class="rounded-lg mb-6">
      <v-card-title class="text-subtitle-1 font-weight-bold pa-4 pb-0">
        Profit Calculation
      </v-card-title>
      <v-card-text class="pa-4">
        <v-table density="comfortable">
          <tbody>
            <tr>
              <td class="text-body-1">
                <v-icon color="success" class="mr-2">mdi-plus-circle</v-icon>
                Total Revenue
              </td>
              <td class="text-right text-h6 font-weight-bold text-success">
                Rs {{ formatNumber(report.totalRevenue) }}
              </td>
            </tr>
            <tr>
              <td class="text-body-1">
                <v-icon color="error" class="mr-2">mdi-minus-circle</v-icon>
                Labour Cost
              </td>
              <td class="text-right text-h6 font-weight-bold text-error">
                Rs {{ formatNumber(report.labourCost) }}
              </td>
            </tr>
            <tr>
              <td class="text-body-1">
                <v-icon color="error" class="mr-2">mdi-minus-circle</v-icon>
                Inventory Cost (Materials Used)
              </td>
              <td class="text-right text-h6 font-weight-bold text-error">
                Rs {{ formatNumber(report.inventoryCost) }}
              </td>
            </tr>
            <tr>
              <td class="text-body-1">
                <v-icon color="error" class="mr-2">mdi-minus-circle</v-icon>
                Expenses
              </td>
              <td class="text-right text-h6 font-weight-bold text-error">
                Rs {{ formatNumber(report.totalExpenses) }}
              </td>
            </tr>
            <tr class="bg-grey-lighten-4">
              <td class="text-body-1 font-weight-bold">
                <v-icon color="primary" class="mr-2">mdi-equal</v-icon>
                Net Profit
              </td>
              <td class="text-right text-h5 font-weight-black" :class="netProfit >= 0 ? 'text-success' : 'text-error'">
                Rs {{ formatNumber(netProfit) }}
              </td>
            </tr>
          </tbody>
        </v-table>

        <div class="text-center mt-4 pa-3 bg-grey-lighten-4 rounded-lg">
          <code class="text-body-2">
            Revenue (Rs {{ formatNumber(report.totalRevenue) }})
            - Labour (Rs {{ formatNumber(report.labourCost) }})
            - Inventory (Rs {{ formatNumber(report.inventoryCost) }})
            - Expenses (Rs {{ formatNumber(report.totalExpenses) }})
            = <strong>Net Profit (Rs {{ formatNumber(netProfit) }})</strong>
          </code>
        </div>
      </v-card-text>
    </v-card>

    <!-- Partner Profit Split -->
    <v-card v-if="report.partnerSplit && report.partnerSplit.length" class="rounded-lg">
      <v-card-title class="text-subtitle-1 font-weight-bold pa-4 pb-2">
        <v-icon class="mr-2" color="secondary">mdi-account-group</v-icon>
        Partner Profit Split
      </v-card-title>
      <v-card-text>
        <v-row>
          <v-col v-for="p in report.partnerSplit" :key="p.partnerId" cols="12" sm="6" md="4">
            <v-card variant="outlined" class="rounded-lg pa-4 text-center">
              <v-avatar size="48" color="primary" class="mb-2">
                <v-icon color="white">mdi-account</v-icon>
              </v-avatar>
              <div class="text-subtitle-1 font-weight-bold">{{ p.name }}</div>
              <div class="text-caption text-medium-emphasis">{{ p.ownershipPercentage }}% ownership</div>
              <v-divider class="my-3" />
              <div class="text-h6 font-weight-bold" :class="p.share >= 0 ? 'text-success' : 'text-error'">
                Rs {{ formatNumber(p.share) }}
              </div>
            </v-card>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'
import { format, subMonths } from 'date-fns'

const appStore = useAppStore()
const loading = ref(false)
const report = ref({})
const dateFrom = ref(format(subMonths(new Date(), 1), 'yyyy-MM-dd'))
const dateTo = ref(format(new Date(), 'yyyy-MM-dd'))

const netProfit = computed(() => {
  return (report.value.totalRevenue || 0)
    - (report.value.labourCost || 0)
    - (report.value.inventoryCost || 0)
    - (report.value.totalExpenses || 0)
})

function formatNumber(val) {
  if (val == null) return '0'
  return Number(val).toLocaleString('en-PK')
}

async function loadReport() {
  loading.value = true
  try {
    const { data } = await api.get('/reports/profit-summary', {
      params: { from: dateFrom.value, to: dateTo.value },
    })
    report.value = data.data || data || {}
  } catch {
    appStore.showError('Failed to load profit report')
  } finally {
    loading.value = false
  }
}

onMounted(loadReport)
</script>
