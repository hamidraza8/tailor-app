<template>
  <div>
    <div class="d-flex align-center justify-space-between mb-6">
      <h1 class="text-h5 font-weight-bold">Capital Dashboard</h1>
      <v-btn color="primary" prepend-icon="mdi-plus" to="/capital/add">
        Add Capital Contribution
      </v-btn>
    </div>

    <v-row class="mb-4">
      <v-col v-for="card in summaryCards" :key="card.label" cols="12" sm="6" md="3">
        <v-card class="rounded-lg">
          <v-card-text class="d-flex align-center pa-5">
            <v-avatar :color="card.color" size="52" class="mr-4" rounded="lg">
              <v-icon :icon="card.icon" color="white" size="28" />
            </v-avatar>
            <div>
              <div class="text-caption text-medium-emphasis">{{ card.label }}</div>
              <div class="text-h6 font-weight-bold" :class="card.textClass">
                {{ formatPKR(card.value) }}
              </div>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <div v-if="loading" class="d-flex justify-center py-12">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <v-row v-else>
      <v-col
        v-for="partner in summary.partnerBalances"
        :key="partner.partnerId"
        cols="12"
        md="6"
      >
        <v-card class="rounded-lg" :class="partner.isDeficit ? 'border-error' : 'border-success'">
          <v-card-title class="pa-4 pb-2 d-flex align-center justify-space-between">
            <div class="d-flex align-center gap-2">
              <v-icon
                :color="partner.isDeficit ? 'error' : 'success'"
                size="20"
                class="mr-2"
              >
                {{ partner.isDeficit ? 'mdi-alert-circle' : 'mdi-check-circle' }}
              </v-icon>
              <span class="text-subtitle-1 font-weight-bold">{{ partner.partnerName }}</span>
            </div>
            <v-chip
              :color="partner.isDeficit ? 'error' : 'success'"
              size="small"
              variant="tonal"
            >
              {{ partner.isDeficit ? 'Deficit' : 'Positive' }}
            </v-chip>
          </v-card-title>

          <v-divider />

          <v-card-text class="pa-4">
            <div class="text-center mb-4">
              <div class="text-caption text-medium-emphasis mb-1">Remaining Balance</div>
              <div
                class="text-h5 font-weight-bold"
                :class="partner.isDeficit ? 'text-error' : 'text-success'"
              >
                {{ formatPKR(partner.remainingBalance) }}
              </div>
            </div>

            <v-row dense>
              <v-col cols="6">
                <div class="text-caption text-medium-emphasis">Capital Added</div>
                <div class="text-body-2 font-weight-medium">{{ formatPKR(partner.totalCapitalAdded) }}</div>
              </v-col>
              <v-col cols="6">
                <div class="text-caption text-medium-emphasis">Funded Spendings</div>
                <div class="text-body-2 font-weight-medium">{{ formatPKR(partner.totalFundedSpendings) }}</div>
              </v-col>
              <v-col cols="6" class="mt-2">
                <div class="text-caption text-medium-emphasis">Withdrawals</div>
                <div class="text-body-2 font-weight-medium">{{ formatPKR(partner.totalWithdrawals) }}</div>
              </v-col>
              <v-col cols="6" class="mt-2">
                <div class="text-caption text-medium-emphasis">Asset Ownership Value</div>
                <div class="text-body-2 font-weight-medium">{{ formatPKR(partner.assetOwnershipValue) }}</div>
              </v-col>
              <v-col cols="6" class="mt-2">
                <div class="text-caption text-medium-emphasis">Inventory Funding</div>
                <div class="text-body-2 font-weight-medium">{{ formatPKR(partner.inventoryFundingTotal) }}</div>
              </v-col>
              <v-col cols="6" class="mt-2">
                <div class="text-caption text-medium-emphasis">Expense Funding</div>
                <div class="text-body-2 font-weight-medium">{{ formatPKR(partner.expenseFundingTotal) }}</div>
              </v-col>
            </v-row>

            <v-alert
              v-if="partner.isDeficit"
              type="error"
              variant="tonal"
              density="compact"
              class="mt-3"
              icon="mdi-alert"
            >
              <strong>Deficit / Payable:</strong> {{ formatPKR(partner.deficitAmount) }}
            </v-alert>
          </v-card-text>

          <v-expansion-panels variant="accordion">
            <v-expansion-panel>
              <v-expansion-panel-title class="text-caption font-weight-medium text-medium-emphasis">
                <v-icon size="16" class="mr-2">mdi-history</v-icon>
                Capital Transaction History
              </v-expansion-panel-title>
              <v-expansion-panel-text>
                <v-table density="compact">
                  <thead>
                    <tr>
                      <th>Date</th>
                      <th>Type</th>
                      <th>Amount</th>
                      <th>Notes</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      v-for="tx in partnerTransactions(partner.partnerId)"
                      :key="tx.id"
                    >
                      <td>{{ formatDate(tx.transactionDate) }}</td>
                      <td>
                        <v-chip size="x-small" :color="txTypeColor(tx.transactionType)" variant="tonal">
                          {{ tx.transactionType }}
                        </v-chip>
                      </td>
                      <td :class="tx.isDebit ? 'text-error' : 'text-success'">
                        {{ tx.isDebit ? '-' : '+' }}{{ formatPKR(tx.amount) }}
                      </td>
                      <td class="text-caption text-medium-emphasis">{{ tx.notes || '—' }}</td>
                    </tr>
                    <tr v-if="!partnerTransactions(partner.partnerId).length">
                      <td colspan="4" class="text-center text-medium-emphasis text-caption py-2">
                        No transactions found
                      </td>
                    </tr>
                  </tbody>
                </v-table>
              </v-expansion-panel-text>
            </v-expansion-panel>
          </v-expansion-panels>
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
const loading = ref(true)
const summary = ref({ totalBusinessCapital: 0, totalApprovedSpendings: 0, totalRemainingCapital: 0, totalDeficits: 0, partnerBalances: [] })
const transactions = ref([])

const summaryCards = computed(() => [
  {
    label: 'Total Business Capital',
    value: summary.value.totalBusinessCapital,
    icon: 'mdi-bank',
    color: 'primary',
    textClass: '',
  },
  {
    label: 'Total Approved Spendings',
    value: summary.value.totalApprovedSpendings,
    icon: 'mdi-cash-minus',
    color: 'warning',
    textClass: '',
  },
  {
    label: 'Total Remaining Capital',
    value: summary.value.totalRemainingCapital,
    icon: 'mdi-wallet',
    color: 'success',
    textClass: '',
  },
  {
    label: 'Total Deficits',
    value: summary.value.totalDeficits,
    icon: 'mdi-alert-circle',
    color: summary.value.totalDeficits > 0 ? 'error' : 'secondary',
    textClass: summary.value.totalDeficits > 0 ? 'text-error' : '',
  },
])

function formatPKR(amount) {
  if (amount == null) return 'PKR 0'
  return new Intl.NumberFormat('en-PK', { style: 'currency', currency: 'PKR' }).format(amount)
}

function formatDate(dateStr) {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('en-PK')
}

function partnerTransactions(partnerId) {
  return transactions.value.filter((t) => t.partnerId === partnerId)
}

function txTypeColor(type) {
  const map = {
    CapitalAdvance: 'info',
    AdditionalCapital: 'success',
    Withdrawal: 'error',
    Adjustment: 'warning',
  }
  return map[type] || 'secondary'
}

onMounted(async () => {
  try {
    const [summaryRes, txRes] = await Promise.all([
      api.get('/reports/partner-balances'),
      api.get('/capital-transactions'),
    ])
    summary.value = summaryRes.data
    transactions.value = txRes.data
  } catch {
    appStore.showError('Failed to load capital data')
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.border-error {
  border-left: 4px solid rgb(var(--v-theme-error)) !important;
}
.border-success {
  border-left: 4px solid rgb(var(--v-theme-success)) !important;
}
</style>
