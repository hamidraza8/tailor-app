<template>
  <div>
    <div class="d-flex align-center mb-6">
      <h1 class="text-h5 font-weight-bold">Payments</h1>
      <v-spacer />
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        label="Search payments..."
        single-line
        hide-details
        density="compact"
        style="max-width: 300px"
        class="mr-3"
      />
      <v-btn color="primary" @click="openDialog()">
        <v-icon start>mdi-plus</v-icon> Record Payment
      </v-btn>
    </div>

    <v-card class="rounded-lg">
      <v-data-table
        :headers="headers"
        :items="payments"
        :search="search"
        :loading="loading"
        items-per-page="15"
      >
        <template #item.amount="{ item }">
          <span class="font-weight-medium text-success">Rs {{ formatNumber(item.amount) }}</span>
        </template>
        <template #item.customerName="{ item }">
          {{ item.customer?.name || item.customerName || 'N/A' }}
        </template>
        <template #item.method="{ item }">
          <v-chip size="small" variant="tonal" :color="methodColor(item.method)">
            {{ item.method }}
          </v-chip>
        </template>
        <template #item.date="{ item }">
          {{ formatDate(item.date || item.createdAt) }}
        </template>
      </v-data-table>
    </v-card>

    <!-- Record Payment Dialog -->
    <v-dialog v-model="dialog" max-width="500">
      <v-card class="rounded-lg">
        <v-card-title class="text-h6 pa-4">Record Payment</v-card-title>
        <v-card-text>
          <v-form ref="formRef">
            <v-text-field v-model="form.invoiceId" label="Invoice ID" :rules="[v => !!v || 'Required']" />
            <v-text-field v-model.number="form.amount" label="Amount (Rs)" type="number" :rules="[v => v > 0 || 'Required']" />
            <v-select
              v-model="form.method"
              label="Payment Method"
              :items="['cash', 'bank_transfer', 'easypaisa', 'jazzcash', 'cheque']"
              :rules="[v => !!v || 'Required']"
            />
            <v-text-field v-model="form.reference" label="Reference / Transaction ID" />
            <v-textarea v-model="form.notes" label="Notes" rows="2" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="savePayment">Save</v-btn>
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
const payments = ref([])
const loading = ref(false)
const search = ref('')
const dialog = ref(false)
const saving = ref(false)
const formRef = ref(null)
const form = ref({ invoiceId: '', amount: 0, method: '', reference: '', notes: '' })

const headers = [
  { title: 'Customer', key: 'customerName' },
  { title: 'Invoice', key: 'invoiceNumber' },
  { title: 'Amount', key: 'amount' },
  { title: 'Method', key: 'method' },
  { title: 'Reference', key: 'reference' },
  { title: 'Date', key: 'date' },
]

function formatNumber(val) {
  return val != null ? Number(val).toLocaleString('en-PK') : '0'
}
function formatDate(d) {
  return d ? format(new Date(d), 'dd MMM yyyy') : 'N/A'
}
function methodColor(m) {
  return { cash: 'success', bank_transfer: 'primary', easypaisa: 'teal', jazzcash: 'orange', cheque: 'info' }[m] || 'grey'
}

function openDialog() {
  form.value = { invoiceId: '', amount: 0, method: '', reference: '', notes: '' }
  dialog.value = true
}

async function savePayment() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    await api.post('/payments', form.value)
    appStore.showSuccess('Payment recorded successfully')
    dialog.value = false
    await loadPayments()
  } catch {
    appStore.showError('Failed to record payment')
  } finally {
    saving.value = false
  }
}

async function loadPayments() {
  loading.value = true
  try {
    const { data } = await api.get('/payments')
    payments.value = data.data || data || []
  } catch {
    appStore.showError('Failed to load payments')
  } finally {
    loading.value = false
  }
}

onMounted(loadPayments)
</script>
