<template>
  <div>
    <div class="d-flex align-center mb-6">
      <h1 class="text-h5 font-weight-bold">Orders</h1>
      <v-spacer />
      <v-select
        v-model="statusFilter"
        label="Filter by Status"
        :items="['All', 'pending', 'in_progress', 'ready', 'delivered', 'cancelled']"
        density="compact"
        style="max-width: 200px"
        hide-details
        class="mr-3"
      />
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        label="Search..."
        single-line
        hide-details
        density="compact"
        style="max-width: 250px"
      />
    </div>

    <v-card class="rounded-lg">
      <v-data-table
        :headers="headers"
        :items="filteredOrders"
        :search="search"
        :loading="loading"
        items-per-page="15"
      >
        <template #item.orderNumber="{ item }">
          <span class="font-weight-medium">#{{ item.orderNumber }}</span>
        </template>
        <template #item.customerName="{ item }">
          {{ item.customer?.name || item.customerName || 'N/A' }}
        </template>
        <template #item.totalAmount="{ item }">
          Rs {{ formatNumber(item.totalAmount) }}
        </template>
        <template #item.status="{ item }">
          <v-chip :color="orderStatusColor(item.status)" size="small" variant="flat">
            {{ formatStatus(item.status) }}
          </v-chip>
        </template>
        <template #item.dueDate="{ item }">
          {{ formatDate(item.dueDate) }}
        </template>
        <template #item.actions="{ item }">
          <v-menu>
            <template #activator="{ props }">
              <v-btn icon="mdi-dots-vertical" size="small" variant="text" v-bind="props" />
            </template>
            <v-list density="compact">
              <v-list-item
                v-for="s in availableStatuses(item.status)"
                :key="s"
                @click="updateStatus(item._id, s)"
              >
                <v-list-item-title>Mark as {{ formatStatus(s) }}</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
        </template>
      </v-data-table>
    </v-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'
import { format } from 'date-fns'

const appStore = useAppStore()
const orders = ref([])
const loading = ref(false)
const search = ref('')
const statusFilter = ref('All')

const headers = [
  { title: 'Order #', key: 'orderNumber' },
  { title: 'Customer', key: 'customerName' },
  { title: 'Items', key: 'itemCount' },
  { title: 'Total', key: 'totalAmount' },
  { title: 'Status', key: 'status' },
  { title: 'Due Date', key: 'dueDate' },
  { title: '', key: 'actions', sortable: false, width: 50 },
]

const filteredOrders = computed(() => {
  if (statusFilter.value === 'All') return orders.value
  return orders.value.filter(o => o.status === statusFilter.value)
})

function formatNumber(val) {
  return val != null ? Number(val).toLocaleString('en-PK') : '0'
}
function formatDate(d) {
  return d ? format(new Date(d), 'dd MMM yyyy') : 'N/A'
}
function formatStatus(s) {
  return (s || '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}
function orderStatusColor(s) {
  return { pending: 'warning', in_progress: 'info', ready: 'success', delivered: 'primary', cancelled: 'error' }[s] || 'grey'
}
function availableStatuses(current) {
  const flow = ['pending', 'in_progress', 'ready', 'delivered']
  const idx = flow.indexOf(current)
  if (idx === -1) return []
  return [...flow.slice(idx + 1), 'cancelled']
}

async function updateStatus(id, status) {
  try {
    await api.post(`/orders/${id}/status`, { status })
    appStore.showSuccess('Order status updated')
    await loadOrders()
  } catch {
    appStore.showError('Failed to update order status')
  }
}

async function loadOrders() {
  loading.value = true
  try {
    const { data } = await api.get('/orders')
    orders.value = data.data || data || []
  } catch {
    appStore.showError('Failed to load orders')
  } finally {
    loading.value = false
  }
}

onMounted(loadOrders)
</script>
