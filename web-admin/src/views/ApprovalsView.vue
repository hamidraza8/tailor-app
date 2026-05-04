<template>
  <div>
    <h1 class="text-h5 font-weight-bold mb-6">Pending Approvals</h1>

    <v-tabs v-model="activeTab" color="primary" class="mb-4">
      <v-tab value="assets">Assets</v-tab>
      <v-tab value="inventory">Inventory Purchases</v-tab>
      <v-tab value="expenses">Expenses</v-tab>
    </v-tabs>

    <v-window v-model="activeTab">
      <!-- Assets Approvals -->
      <v-window-item value="assets">
        <v-card v-if="!pendingAssets.length" class="pa-8 text-center rounded-lg">
          <v-icon size="64" color="success">mdi-check-circle</v-icon>
          <div class="text-h6 mt-3">No pending asset approvals</div>
        </v-card>
        <v-row v-else>
          <v-col v-for="item in pendingAssets" :key="item.id" cols="12" md="6" lg="4">
            <v-card class="rounded-lg">
              <v-img
                v-if="item.photoUrl"
                :src="item.photoUrl"
                height="200"
                cover
                class="bg-grey-lighten-3"
              >
                <template #placeholder>
                  <v-row class="fill-height ma-0" align="center" justify="center">
                    <v-icon size="48" color="grey">mdi-image</v-icon>
                  </v-row>
                </template>
              </v-img>
              <v-card-title class="text-subtitle-1">{{ item.name }}</v-card-title>
              <v-card-subtitle>Rs {{ formatNumber(item.purchasePrice) }} - {{ item.category }}</v-card-subtitle>
              <v-card-text class="text-body-2">
                <div>Purchased: {{ formatDate(item.purchaseDate) }}</div>
                <div>Added by: {{ item.addedBy?.name || 'N/A' }}</div>
                <div v-if="item.description" class="mt-1 text-medium-emphasis">{{ item.description }}</div>
              </v-card-text>
              <v-card-actions>
                <v-btn color="success" variant="flat" @click="openApprovalDialog(item, 'asset', 'approve')">
                  <v-icon start>mdi-check</v-icon> Approve
                </v-btn>
                <v-btn color="error" variant="flat" @click="openApprovalDialog(item, 'asset', 'reject')">
                  <v-icon start>mdi-close</v-icon> Reject
                </v-btn>
              </v-card-actions>
            </v-card>
          </v-col>
        </v-row>
      </v-window-item>

      <!-- Inventory Approvals -->
      <v-window-item value="inventory">
        <v-card v-if="!pendingInventory.length" class="pa-8 text-center rounded-lg">
          <v-icon size="64" color="success">mdi-check-circle</v-icon>
          <div class="text-h6 mt-3">No pending inventory approvals</div>
        </v-card>
        <v-row v-else>
          <v-col v-for="item in pendingInventory" :key="item.id" cols="12" md="6" lg="4">
            <v-card class="rounded-lg">
              <v-img
                v-if="item.receiptUrl"
                :src="item.receiptUrl"
                height="200"
                cover
                class="bg-grey-lighten-3"
              />
              <v-card-title class="text-subtitle-1">{{ item.itemName }}</v-card-title>
              <v-card-subtitle>Rs {{ formatNumber(item.totalCost) }} - {{ item.type }}</v-card-subtitle>
              <v-card-text class="text-body-2">
                <div>Quantity: {{ item.quantity }} {{ item.unit }}</div>
                <div>Date: {{ formatDate(item.date) }}</div>
                <div>Added by: {{ item.addedBy?.name || 'N/A' }}</div>
              </v-card-text>
              <v-card-actions>
                <v-btn color="success" variant="flat" @click="openApprovalDialog(item, 'inventory', 'approve')">
                  <v-icon start>mdi-check</v-icon> Approve
                </v-btn>
                <v-btn color="error" variant="flat" @click="openApprovalDialog(item, 'inventory', 'reject')">
                  <v-icon start>mdi-close</v-icon> Reject
                </v-btn>
              </v-card-actions>
            </v-card>
          </v-col>
        </v-row>
      </v-window-item>

      <!-- Expenses Approvals -->
      <v-window-item value="expenses">
        <v-card v-if="!pendingExpenses.length" class="pa-8 text-center rounded-lg">
          <v-icon size="64" color="success">mdi-check-circle</v-icon>
          <div class="text-h6 mt-3">No pending expense approvals</div>
        </v-card>
        <v-row v-else>
          <v-col v-for="item in pendingExpenses" :key="item.id" cols="12" md="6" lg="4">
            <v-card class="rounded-lg">
              <v-img
                v-if="item.receiptUrl"
                :src="item.receiptUrl"
                height="200"
                cover
                class="bg-grey-lighten-3"
              />
              <v-card-title class="text-subtitle-1">{{ item.description }}</v-card-title>
              <v-card-subtitle>Rs {{ formatNumber(item.amount) }} - {{ item.category }}</v-card-subtitle>
              <v-card-text class="text-body-2">
                <div>Date: {{ formatDate(item.date) }}</div>
                <div>Added by: {{ item.addedBy?.name || 'N/A' }}</div>
              </v-card-text>
              <v-card-actions>
                <v-btn color="success" variant="flat" @click="openApprovalDialog(item, 'expense', 'approve')">
                  <v-icon start>mdi-check</v-icon> Approve
                </v-btn>
                <v-btn color="error" variant="flat" @click="openApprovalDialog(item, 'expense', 'reject')">
                  <v-icon start>mdi-close</v-icon> Reject
                </v-btn>
              </v-card-actions>
            </v-card>
          </v-col>
        </v-row>
      </v-window-item>
    </v-window>

    <!-- Approval/Rejection Dialog -->
    <v-dialog v-model="dialog.show" max-width="500">
      <v-card class="rounded-lg">
        <v-card-title class="text-h6">
          {{ dialog.action === 'approve' ? 'Approve' : 'Reject' }} {{ dialog.type }}
        </v-card-title>
        <v-card-text>
          <p class="mb-3">
            Are you sure you want to <strong>{{ dialog.action }}</strong> this {{ dialog.type }}?
          </p>
          <v-textarea
            v-model="dialog.comment"
            label="Comment (optional)"
            variant="outlined"
            rows="3"
          />
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog.show = false">Cancel</v-btn>
          <v-btn
            :color="dialog.action === 'approve' ? 'success' : 'error'"
            variant="flat"
            :loading="dialog.loading"
            @click="submitApproval"
          >
            {{ dialog.action === 'approve' ? 'Approve' : 'Reject' }}
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
import { format } from 'date-fns'

const appStore = useAppStore()
const activeTab = ref('assets')
const pendingAssets = ref([])
const pendingInventory = ref([])
const pendingExpenses = ref([])

const dialog = ref({
  show: false,
  action: 'approve',
  type: '',
  item: null,
  comment: '',
  loading: false,
})

function formatNumber(val) {
  if (val == null) return '0'
  return Number(val).toLocaleString('en-PK')
}

function formatDate(d) {
  if (!d) return 'N/A'
  return format(new Date(d), 'dd MMM yyyy')
}

function openApprovalDialog(item, type, action) {
  dialog.value = { show: true, action, type, item, comment: '', loading: false }
}

async function submitApproval() {
  dialog.value.loading = true
  const { item, type, action, comment } = dialog.value
  try {
    let url = ''
    if (type === 'asset') url = `/assets/${item.id}/${action}`
    else if (type === 'inventory') url = `/inventory/transactions/${item.id}/${action}`
    else if (type === 'expense') url = `/expenses/${item.id}/${action}`

    await api.post(url, { comment })
    appStore.showSuccess(`Successfully ${action}d ${type}`)
    dialog.value.show = false
    await loadAll()
  } catch {
    appStore.showError(`Failed to ${action} ${type}`)
  } finally {
    dialog.value.loading = false
  }
}

async function loadAll() {
  try {
    const [assets, inventory, expenses] = await Promise.all([
      api.get('/assets', { params: { status: 'PendingApproval' } }),
      api.get('/inventory/items', { params: { approvalStatus: 'PendingApproval' } }),
      api.get('/expenses', { params: { status: 'PendingApproval' } }),
    ])
    pendingAssets.value = assets.data?.data || assets.data || []
    pendingInventory.value = inventory.data?.data || inventory.data || []
    pendingExpenses.value = expenses.data?.data || expenses.data || []
  } catch {
    appStore.showError('Failed to load pending approvals')
  }
}

onMounted(loadAll)
</script>
