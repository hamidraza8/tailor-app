<template>
  <div>
    <div class="d-flex align-center justify-space-between mb-6">
      <h1 class="text-h5 font-weight-bold">Funding Split Report</h1>
      <v-btn
        variant="tonal"
        prepend-icon="mdi-printer"
        @click="window.print()"
      >
        Print
      </v-btn>
    </div>

    <!-- Filters -->
    <v-card class="rounded-lg mb-4">
      <v-card-text>
        <v-row dense align="center">
          <v-col cols="12" sm="4" md="3">
            <v-text-field
              v-model="filters.from"
              label="From Date"
              type="date"
              variant="outlined"
              density="compact"
              hide-details
            />
          </v-col>
          <v-col cols="12" sm="4" md="3">
            <v-text-field
              v-model="filters.to"
              label="To Date"
              type="date"
              variant="outlined"
              density="compact"
              hide-details
            />
          </v-col>
          <v-col cols="12" sm="4" md="2" class="d-flex gap-2">
            <v-btn color="primary" variant="tonal" @click="loadReport" :loading="loading">
              Search
            </v-btn>
            <v-btn variant="text" @click="resetFilters">Reset</v-btn>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- Table -->
    <v-card class="rounded-lg">
      <div v-if="loading" class="d-flex justify-center py-12">
        <v-progress-circular indeterminate color="primary" />
      </div>

      <div v-else-if="!report.length" class="text-center text-medium-emphasis pa-12">
        No spendings found for the selected period.
      </div>

      <div v-else class="table-scroll">
        <v-table>
          <thead>
            <tr>
              <th>Spending No</th>
              <th>Date</th>
              <th>Category</th>
              <th>Description</th>
              <th>Total Amount</th>
              <th>Status</th>
              <th v-for="partner in partnerColumns" :key="partner.partnerId">
                {{ partner.partnerName }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in report" :key="row.id">
              <td class="text-no-wrap">{{ row.spendingNo }}</td>
              <td class="text-no-wrap">{{ formatDate(row.spendingDate) }}</td>
              <td>{{ row.category }}</td>
              <td style="max-width: 200px; white-space: normal;">{{ row.description }}</td>
              <td class="text-no-wrap font-weight-medium">{{ formatPKR(row.totalAmount) }}</td>
              <td>
                <v-chip :color="statusColor(row.approvalStatus)" size="x-small" variant="tonal">
                  {{ row.approvalStatus }}
                </v-chip>
              </td>
              <td
                v-for="partner in partnerColumns"
                :key="partner.partnerId"
                class="text-no-wrap"
              >
                {{ formatPKR(splitAmount(row, partner.partnerId)) }}
              </td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="font-weight-bold bg-grey-lighten-4">
              <td colspan="4">Totals</td>
              <td>{{ formatPKR(grandTotal) }}</td>
              <td></td>
              <td v-for="partner in partnerColumns" :key="partner.partnerId">
                {{ formatPKR(partnerTotal(partner.partnerId)) }}
              </td>
            </tr>
          </tfoot>
        </v-table>
      </div>
    </v-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const loading = ref(false)
const report = ref([])

const filters = ref({ from: '', to: '' })

const partnerColumns = computed(() => {
  const map = {}
  report.value.forEach((row) => {
    if (row.fundingSplits) {
      row.fundingSplits.forEach((s) => {
        if (!map[s.partnerId]) map[s.partnerId] = { partnerId: s.partnerId, partnerName: s.partnerName }
      })
    }
  })
  return Object.values(map)
})

const grandTotal = computed(() => report.value.reduce((sum, r) => sum + (r.totalAmount || 0), 0))

function partnerTotal(partnerId) {
  return report.value.reduce((sum, row) => {
    const split = row.fundingSplits?.find((s) => s.partnerId === partnerId)
    return sum + (split?.amount || 0)
  }, 0)
}

function splitAmount(row, partnerId) {
  const split = row.fundingSplits?.find((s) => s.partnerId === partnerId)
  return split?.amount || 0
}

function formatPKR(amount) {
  if (amount == null || amount === 0) return '—'
  return new Intl.NumberFormat('en-PK', { style: 'currency', currency: 'PKR' }).format(amount)
}

function formatDate(dateStr) {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('en-PK')
}

function statusColor(status) {
  const map = { Pending: 'warning', Approved: 'success', Rejected: 'error' }
  return map[status] || 'secondary'
}

function resetFilters() {
  filters.value = { from: '', to: '' }
  loadReport()
}

async function loadReport() {
  loading.value = true
  try {
    const params = {}
    if (filters.value.from) params.from = filters.value.from
    if (filters.value.to) params.to = filters.value.to
    const { data } = await api.get('/reports/funding-splits', { params })
    report.value = Array.isArray(data) ? data : []
  } catch {
    appStore.showError('Failed to load funding split report')
  } finally {
    loading.value = false
  }
}

onMounted(loadReport)
</script>

<style scoped>
.table-scroll {
  overflow-x: auto;
}
@media print {
  .v-btn {
    display: none !important;
  }
}
</style>
