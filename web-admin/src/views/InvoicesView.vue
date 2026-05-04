<template>
  <div>
    <div class="d-flex align-center mb-6">
      <h1 class="text-h5 font-weight-bold">Invoices</h1>
      <v-spacer />
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        label="Search invoices..."
        single-line
        hide-details
        density="compact"
        style="max-width: 300px"
        class="mr-3"
      />
      <v-btn color="primary" @click="generateDialog = true">
        <v-icon start>mdi-plus</v-icon> Generate Invoice
      </v-btn>
    </div>

    <v-card class="rounded-lg">
      <v-data-table
        :headers="headers"
        :items="invoices"
        :search="search"
        :loading="loading"
        items-per-page="15"
      >
        <template #item.invoiceNumber="{ item }">
          <span class="font-weight-medium">#{{ item.invoiceNumber }}</span>
        </template>
        <template #item.customerName="{ item }">
          {{ item.customer?.name || item.customerName || 'N/A' }}
        </template>
        <template #item.totalAmount="{ item }">
          Rs {{ formatNumber(item.totalAmount) }}
        </template>
        <template #item.paidAmount="{ item }">
          <span :class="item.paidAmount >= item.totalAmount ? 'text-success' : 'text-warning'">
            Rs {{ formatNumber(item.paidAmount) }}
          </span>
        </template>
        <template #item.status="{ item }">
          <v-chip :color="invoiceStatusColor(item.status)" size="small" variant="flat">
            {{ item.status }}
          </v-chip>
        </template>
        <template #item.date="{ item }">
          {{ formatDate(item.date || item.createdAt) }}
        </template>
        <template #item.actions="{ item }">
          <v-btn icon="mdi-file-pdf-box" size="small" variant="text" color="error" @click="downloadPdf(item._id)">
            <v-icon>mdi-file-pdf-box</v-icon>
            <v-tooltip activator="parent" location="top">Download PDF</v-tooltip>
          </v-btn>
        </template>
      </v-data-table>
    </v-card>

    <!-- Generate Invoice Dialog -->
    <v-dialog v-model="generateDialog" max-width="500">
      <v-card class="rounded-lg">
        <v-card-title class="text-h6 pa-4">Generate Invoice</v-card-title>
        <v-card-text>
          <v-form ref="formRef">
            <v-text-field v-model="genForm.orderId" label="Order ID" :rules="[v => !!v || 'Required']" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="generateDialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="generating" @click="generateInvoice">Generate</v-btn>
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
const invoices = ref([])
const loading = ref(false)
const search = ref('')
const generateDialog = ref(false)
const generating = ref(false)
const formRef = ref(null)
const genForm = ref({ orderId: '' })

const headers = [
  { title: 'Invoice #', key: 'invoiceNumber' },
  { title: 'Customer', key: 'customerName' },
  { title: 'Total', key: 'totalAmount' },
  { title: 'Paid', key: 'paidAmount' },
  { title: 'Status', key: 'status' },
  { title: 'Date', key: 'date' },
  { title: 'PDF', key: 'actions', sortable: false, width: 60 },
]

function formatNumber(val) {
  return val != null ? Number(val).toLocaleString('en-PK') : '0'
}
function formatDate(d) {
  return d ? format(new Date(d), 'dd MMM yyyy') : 'N/A'
}
function invoiceStatusColor(s) {
  return { paid: 'success', partial: 'warning', unpaid: 'error', cancelled: 'grey' }[s] || 'info'
}

async function downloadPdf(id) {
  try {
    const response = await api.get(`/invoices/${id}/pdf`, { responseType: 'blob' })
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', `invoice-${id}.pdf`)
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.URL.revokeObjectURL(url)
  } catch {
    appStore.showError('Failed to download PDF')
  }
}

async function generateInvoice() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  generating.value = true
  try {
    await api.post('/invoices/generate', { orderId: genForm.value.orderId })
    appStore.showSuccess('Invoice generated successfully')
    generateDialog.value = false
    await loadInvoices()
  } catch {
    appStore.showError('Failed to generate invoice')
  } finally {
    generating.value = false
  }
}

async function loadInvoices() {
  loading.value = true
  try {
    const { data } = await api.get('/invoices')
    invoices.value = data.data || data || []
  } catch {
    appStore.showError('Failed to load invoices')
  } finally {
    loading.value = false
  }
}

onMounted(loadInvoices)
</script>
