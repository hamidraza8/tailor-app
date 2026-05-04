<template>
  <div>
    <div class="d-flex align-center justify-space-between mb-6">
      <h1 class="text-h5 font-weight-bold">Spendings</h1>
      <v-btn color="primary" prepend-icon="mdi-plus" to="/spendings/add">
        New Spending
      </v-btn>
    </div>

    <!-- Filters -->
    <v-card class="rounded-lg mb-4">
      <v-card-text>
        <v-row dense align="center">
          <v-col cols="12" sm="6" md="2">
            <v-select
              v-model="filters.status"
              :items="statusOptions"
              label="Status"
              variant="outlined"
              density="compact"
              clearable
              hide-details
            />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-select
              v-model="filters.category"
              :items="categoryOptions"
              label="Category"
              variant="outlined"
              density="compact"
              clearable
              hide-details
            />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-select
              v-model="filters.resultType"
              :items="resultTypeOptions"
              label="Result Type"
              variant="outlined"
              density="compact"
              clearable
              hide-details
            />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-text-field
              v-model="filters.from"
              label="From Date"
              type="date"
              variant="outlined"
              density="compact"
              hide-details
            />
          </v-col>
          <v-col cols="12" sm="6" md="2">
            <v-text-field
              v-model="filters.to"
              label="To Date"
              type="date"
              variant="outlined"
              density="compact"
              hide-details
            />
          </v-col>
          <v-col cols="12" sm="6" md="2" class="d-flex gap-2">
            <v-btn color="primary" variant="tonal" @click="loadSpendings" :loading="loading">
              Search
            </v-btn>
            <v-btn variant="text" @click="resetFilters">Reset</v-btn>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>

    <!-- Table -->
    <v-card class="rounded-lg">
      <v-data-table
        :headers="headers"
        :items="spendings"
        :loading="loading"
        :items-per-page="15"
        class="rounded-lg"
      >
        <template #item.spendingDate="{ item }">
          {{ formatDate(item.spendingDate) }}
        </template>
        <template #item.totalAmount="{ item }">
          {{ formatPKR(item.totalAmount) }}
        </template>
        <template #item.approvalStatus="{ item }">
          <v-chip
            :color="statusColor(item.approvalStatus)"
            size="small"
            variant="tonal"
          >
            {{ item.approvalStatus }}
          </v-chip>
        </template>
        <template #item.actions="{ item }">
          <div class="d-flex gap-1">
            <v-btn
              icon="mdi-eye"
              size="x-small"
              variant="text"
              color="primary"
              @click="openDetail(item)"
            />
            <template v-if="item.approvalStatus === 'Pending'">
              <v-btn
                icon="mdi-check"
                size="x-small"
                variant="text"
                color="success"
                @click="openApproval(item, 'approve')"
              />
              <v-btn
                icon="mdi-close"
                size="x-small"
                variant="text"
                color="error"
                @click="openApproval(item, 'reject')"
              />
            </template>
          </div>
        </template>
      </v-data-table>
    </v-card>

    <!-- Detail Dialog -->
    <v-dialog v-model="detailDialog" max-width="720" scrollable>
      <v-card v-if="selectedSpending" class="rounded-lg">
        <v-card-title class="pa-4 d-flex align-center justify-space-between">
          <span>Spending Details — {{ selectedSpending.spendingNo }}</span>
          <v-btn icon="mdi-close" variant="text" @click="detailDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-row>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Date</div>
              <div class="text-body-2">{{ formatDate(selectedSpending.spendingDate) }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Category</div>
              <div class="text-body-2">{{ selectedSpending.category }}</div>
            </v-col>
            <v-col cols="12">
              <div class="text-caption text-medium-emphasis">Description</div>
              <div class="text-body-2">{{ selectedSpending.description }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Total Amount</div>
              <div class="text-body-1 font-weight-bold">{{ formatPKR(selectedSpending.totalAmount) }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Result Type</div>
              <div class="text-body-2">{{ selectedSpending.resultType }}</div>
            </v-col>
            <v-col cols="6">
              <div class="text-caption text-medium-emphasis">Status</div>
              <v-chip :color="statusColor(selectedSpending.approvalStatus)" size="small" variant="tonal">
                {{ selectedSpending.approvalStatus }}
              </v-chip>
            </v-col>
            <v-col cols="6" v-if="selectedSpending.approvedAt">
              <div class="text-caption text-medium-emphasis">Approved At</div>
              <div class="text-body-2">{{ formatDate(selectedSpending.approvedAt) }}</div>
            </v-col>
            <v-col cols="12" v-if="selectedSpending.approvalComment">
              <div class="text-caption text-medium-emphasis">Approval Comment</div>
              <div class="text-body-2">{{ selectedSpending.approvalComment }}</div>
            </v-col>
            <v-col cols="12" v-if="selectedSpending.notes">
              <div class="text-caption text-medium-emphasis">Notes</div>
              <div class="text-body-2">{{ selectedSpending.notes }}</div>
            </v-col>
          </v-row>

          <div class="mt-4">
            <div class="text-subtitle-2 font-weight-bold mb-2">Funding Splits</div>
            <v-table density="compact">
              <thead>
                <tr>
                  <th>Partner</th>
                  <th>Amount</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="split in selectedSpending.fundingSplits" :key="split.id">
                  <td>{{ split.partnerName }}</td>
                  <td>{{ formatPKR(split.amount) }}</td>
                  <td class="text-caption text-medium-emphasis">{{ split.notes || '—' }}</td>
                </tr>
              </tbody>
            </v-table>
          </div>
        </v-card-text>
      </v-card>
    </v-dialog>

    <!-- Approve/Reject Dialog -->
    <v-dialog v-model="approvalDialog" max-width="480">
      <v-card class="rounded-lg">
        <v-card-title class="pa-4">
          {{ approvalAction === 'approve' ? 'Approve Spending' : 'Reject Spending' }}
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-textarea
            v-model="approvalComment"
            label="Comment (optional)"
            variant="outlined"
            rows="3"
          />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0 justify-end gap-2">
          <v-btn variant="tonal" @click="approvalDialog = false">Cancel</v-btn>
          <v-btn
            :color="approvalAction === 'approve' ? 'success' : 'error'"
            :loading="approving"
            @click="submitApproval"
          >
            {{ approvalAction === 'approve' ? 'Approve' : 'Reject' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const loading = ref(false)
const spendings = ref([])

const filters = ref({ status: null, category: null, resultType: null, from: '', to: '' })

const statusOptions = ['Pending', 'Approved', 'Rejected']
const categoryOptions = ['AssetPurchase', 'InventoryPurchase', 'Rent', 'Utility', 'Salary', 'Labour', 'Marketing', 'Misc']
const resultTypeOptions = ['Asset', 'Inventory', 'Expense']

const headers = [
  { title: 'Spending No', key: 'spendingNo', sortable: true },
  { title: 'Date', key: 'spendingDate', sortable: true },
  { title: 'Category', key: 'category', sortable: true },
  { title: 'Description', key: 'description', sortable: false },
  { title: 'Amount', key: 'totalAmount', sortable: true },
  { title: 'Result Type', key: 'resultType', sortable: true },
  { title: 'Status', key: 'approvalStatus', sortable: true },
  { title: 'Actions', key: 'actions', sortable: false, align: 'center' },
]

const detailDialog = ref(false)
const selectedSpending = ref(null)

const approvalDialog = ref(false)
const approvalAction = ref('approve')
const approvalComment = ref('')
const approvalTarget = ref(null)
const approving = ref(false)

function formatPKR(amount) {
  if (amount == null) return 'PKR 0'
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

function openDetail(item) {
  selectedSpending.value = item
  detailDialog.value = true
}

function openApproval(item, action) {
  approvalTarget.value = item
  approvalAction.value = action
  approvalComment.value = ''
  approvalDialog.value = true
}

async function submitApproval() {
  if (!approvalTarget.value) return
  approving.value = true
  try {
    const endpoint = approvalAction.value === 'approve'
      ? `/spendings/${approvalTarget.value.id}/approve`
      : `/spendings/${approvalTarget.value.id}/reject`
    await api.post(endpoint, { comment: approvalComment.value || null })
    appStore.showSuccess(`Spending ${approvalAction.value === 'approve' ? 'approved' : 'rejected'} successfully`)
    approvalDialog.value = false
    await loadSpendings()
  } catch {
    appStore.showError('Failed to update spending status')
  } finally {
    approving.value = false
  }
}

function resetFilters() {
  filters.value = { status: null, category: null, resultType: null, from: '', to: '' }
  loadSpendings()
}

async function loadSpendings() {
  loading.value = true
  try {
    const params = {}
    if (filters.value.status) params.status = filters.value.status
    if (filters.value.category) params.category = filters.value.category
    if (filters.value.resultType) params.resultType = filters.value.resultType
    if (filters.value.from) params.from = filters.value.from
    if (filters.value.to) params.to = filters.value.to

    const { data } = await api.get('/spendings', { params })
    spendings.value = data
  } catch {
    appStore.showError('Failed to load spendings')
  } finally {
    loading.value = false
  }
}

onMounted(loadSpendings)
</script>
