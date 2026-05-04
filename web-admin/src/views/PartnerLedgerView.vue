<template>
  <div>
    <h1 class="text-h5 font-weight-bold mb-6">Partner Ledger</h1>

    <!-- Partner Selector -->
    <v-card class="rounded-lg mb-4">
      <v-card-text>
        <v-row dense align="center">
          <v-col cols="12" sm="4" md="3">
            <v-select
              v-model="selectedPartnerId"
              :items="partners"
              item-title="name"
              item-value="id"
              label="Select Partner"
              variant="outlined"
              density="compact"
              hide-details
              :loading="loadingPartners"
              @update:model-value="loadLedger"
            />
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <div v-if="loading" class="d-flex justify-center py-12">
      <v-progress-circular indeterminate color="primary" size="48" />
    </div>

    <template v-else-if="selectedPartnerId && partnerReport">
      <!-- Balance Summary -->
      <v-row class="mb-4">
        <v-col cols="6" sm="3">
          <v-card class="rounded-lg">
            <v-card-text class="pa-4 text-center">
              <div class="text-caption text-medium-emphasis">Capital Added</div>
              <div class="text-h6 font-weight-bold text-success">{{ formatPKR(partnerReport.totalCapitalAdded) }}</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" sm="3">
          <v-card class="rounded-lg">
            <v-card-text class="pa-4 text-center">
              <div class="text-caption text-medium-emphasis">Funded Spendings</div>
              <div class="text-h6 font-weight-bold text-warning">{{ formatPKR(partnerReport.totalFundedSpendings) }}</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" sm="3">
          <v-card class="rounded-lg">
            <v-card-text class="pa-4 text-center">
              <div class="text-caption text-medium-emphasis">Withdrawals</div>
              <div class="text-h6 font-weight-bold text-error">{{ formatPKR(partnerReport.totalWithdrawals) }}</div>
            </v-card-text>
          </v-card>
        </v-col>
        <v-col cols="6" sm="3">
          <v-card class="rounded-lg">
            <v-card-text class="pa-4 text-center">
              <div class="text-caption text-medium-emphasis">Remaining Balance</div>
              <div
                class="text-h6 font-weight-bold"
                :class="partnerReport.isDeficit ? 'text-error' : 'text-success'"
              >
                {{ formatPKR(partnerReport.remainingBalance) }}
              </div>
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>

      <v-alert
        v-if="partnerReport.isDeficit"
        type="error"
        variant="tonal"
        density="compact"
        class="mb-4"
        icon="mdi-alert"
      >
        This partner is in deficit of <strong>{{ formatPKR(partnerReport.deficitAmount) }}</strong>.
      </v-alert>

      <!-- Ledger Table -->
      <v-card class="rounded-lg mb-4">
        <v-card-title class="pa-4 pb-2 text-subtitle-1 font-weight-bold">
          <v-icon class="mr-2">mdi-book-open-page-variant</v-icon>
          Ledger
        </v-card-title>
        <v-divider />
        <v-table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Description</th>
              <th>Type</th>
              <th class="text-success">Credits</th>
              <th class="text-error">Debits</th>
              <th>Running Balance</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="(entry, idx) in ledgerEntries" :key="idx">
              <td class="text-no-wrap">{{ formatDate(entry.date) }}</td>
              <td>{{ entry.description }}</td>
              <td>
                <v-chip size="x-small" :color="entry.isCredit ? 'success' : 'error'" variant="tonal">
                  {{ entry.isCredit ? 'Credit' : 'Debit' }}
                </v-chip>
              </td>
              <td class="text-success">
                {{ entry.isCredit ? formatPKR(entry.amount) : '—' }}
              </td>
              <td class="text-error">
                {{ !entry.isCredit ? formatPKR(entry.amount) : '—' }}
              </td>
              <td :class="entry.runningBalance < 0 ? 'text-error font-weight-bold' : 'text-success font-weight-bold'">
                {{ formatPKR(entry.runningBalance) }}
                <v-icon v-if="entry.runningBalance < 0" size="14" color="error" class="ml-1">mdi-alert</v-icon>
              </td>
            </tr>
            <tr v-if="!ledgerEntries.length">
              <td colspan="6" class="text-center text-medium-emphasis pa-6">No entries found</td>
            </tr>
          </tbody>
        </v-table>
      </v-card>

      <!-- Asset Ownership Section -->
      <v-card class="rounded-lg" v-if="assetOwnership.length">
        <v-card-title class="pa-4 pb-2 text-subtitle-1 font-weight-bold">
          <v-icon class="mr-2" color="primary">mdi-package-variant</v-icon>
          Asset Ownership
        </v-card-title>
        <v-divider />
        <v-table>
          <thead>
            <tr>
              <th>Asset</th>
              <th>Type</th>
              <th>Ownership %</th>
              <th>Value</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="asset in assetOwnership" :key="asset.assetId">
              <td>{{ asset.assetName }}</td>
              <td>{{ asset.assetType }}</td>
              <td>{{ asset.ownershipPercentage }}%</td>
              <td class="font-weight-medium">{{ formatPKR(asset.ownershipValue) }}</td>
            </tr>
          </tbody>
          <tfoot>
            <tr class="font-weight-bold bg-grey-lighten-4">
              <td colspan="3">Total Asset Ownership Value</td>
              <td>{{ formatPKR(partnerReport.assetOwnershipValue) }}</td>
            </tr>
          </tfoot>
        </v-table>
      </v-card>
    </template>

    <div v-else-if="!selectedPartnerId" class="text-center text-medium-emphasis pa-12">
      <v-icon size="64" class="mb-4">mdi-account-search</v-icon>
      <div>Select a partner to view their ledger</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const loadingPartners = ref(true)
const loading = ref(false)
const partners = ref([])
const selectedPartnerId = ref(null)
const partnerReport = ref(null)
const transactions = ref([])
const assetOwnership = ref([])

const ledgerEntries = computed(() => {
  if (!partnerReport.value) return []

  const entries = []

  const capitalLines = partnerReport.value.capitalLines || []
  capitalLines.forEach((line) => {
    entries.push({
      date: line.transactionDate,
      description: `${line.transactionType}${line.notes ? ' — ' + line.notes : ''}`,
      isCredit: !line.isDebit,
      amount: line.amount,
    })
  })

  const spendingLines = partnerReport.value.spendingLines || []
  spendingLines.forEach((line) => {
    entries.push({
      date: line.spendingDate,
      description: `Spending: ${line.spendingNo} — ${line.category}`,
      isCredit: false,
      amount: line.amount,
    })
  })

  entries.sort((a, b) => new Date(a.date) - new Date(b.date))

  let runningBalance = 0
  entries.forEach((entry) => {
    if (entry.isCredit) {
      runningBalance += entry.amount
    } else {
      runningBalance -= entry.amount
    }
    entry.runningBalance = runningBalance
  })

  return entries
})

function formatPKR(amount) {
  if (amount == null) return 'PKR 0'
  return new Intl.NumberFormat('en-PK', { style: 'currency', currency: 'PKR' }).format(amount)
}

function formatDate(dateStr) {
  if (!dateStr) return '—'
  return new Date(dateStr).toLocaleDateString('en-PK')
}

async function loadLedger() {
  if (!selectedPartnerId.value) return
  loading.value = true
  try {
    const [reportRes, assetsRes] = await Promise.all([
      api.get(`/reports/partner-balances/${selectedPartnerId.value}`),
      api.get('/reports/asset-ownership').catch(() => ({ data: [] })),
    ])
    partnerReport.value = reportRes.data
    const allAssets = Array.isArray(assetsRes.data) ? assetsRes.data : []
    assetOwnership.value = allAssets.filter((a) =>
      a.ownershipSplits?.some((s) => s.partnerId === selectedPartnerId.value)
    ).map((a) => {
      const split = a.ownershipSplits.find((s) => s.partnerId === selectedPartnerId.value)
      return {
        assetId: a.assetId,
        assetName: a.assetName,
        assetType: a.assetType,
        ownershipPercentage: split?.ownershipPercentage || 0,
        ownershipValue: split?.ownershipValue || 0,
      }
    })
  } catch {
    appStore.showError('Failed to load partner ledger')
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  try {
    const { data } = await api.get('/partners')
    partners.value = data
  } catch {
    appStore.showError('Failed to load partners')
  } finally {
    loadingPartners.value = false
  }
})
</script>
