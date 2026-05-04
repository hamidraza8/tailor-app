<template>
  <div>
    <div class="d-flex align-center mb-6">
      <h1 class="text-h5 font-weight-bold">Expenses</h1>
      <v-spacer />
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        label="Search expenses..."
        single-line
        hide-details
        density="compact"
        style="max-width: 300px"
        class="mr-3"
      />
      <v-btn color="primary" @click="openDialog()">
        <v-icon start>mdi-plus</v-icon> Add Expense
      </v-btn>
    </div>

    <v-card class="rounded-lg">
      <v-data-table
        :headers="headers"
        :items="expenses"
        :search="search"
        :loading="loading"
        items-per-page="15"
      >
        <template #item.amount="{ item }">
          <span class="font-weight-medium text-error">Rs {{ formatNumber(item.amount) }}</span>
        </template>
        <template #item.status="{ item }">
          <v-chip :color="statusColor(item.status || item.approvalStatus)" size="small" variant="flat">
            {{ item.status || item.approvalStatus || 'N/A' }}
          </v-chip>
        </template>
        <template #item.category="{ item }">
          <v-chip size="small" variant="tonal">{{ item.category }}</v-chip>
        </template>
        <template #item.date="{ item }">
          {{ formatDate(item.date || item.createdAt) }}
        </template>
        <template #item.receiptUrl="{ item }">
          <v-btn
            v-if="item.receiptUrl"
            icon="mdi-image"
            size="small"
            variant="text"
            @click="previewImage = item.receiptUrl; previewDialog = true"
          />
        </template>
      </v-data-table>
    </v-card>

    <!-- Add Expense Dialog -->
    <v-dialog v-model="dialog" max-width="600">
      <v-card class="rounded-lg">
        <v-card-title class="text-h6 pa-4">Add New Expense</v-card-title>
        <v-card-text>
          <v-form ref="formRef">
            <v-text-field v-model="form.description" label="Description" :rules="[v => !!v || 'Required']" />
            <v-text-field v-model.number="form.amount" label="Amount (Rs)" type="number" :rules="[v => v > 0 || 'Required']" />
            <v-select
              v-model="form.category"
              label="Category"
              :items="['Rent', 'Utilities', 'Transport', 'Maintenance', 'Supplies', 'Food', 'Marketing', 'Other']"
              :rules="[v => !!v || 'Required']"
            />
            <v-text-field v-model="form.date" label="Date" type="date" :rules="[v => !!v || 'Required']" />
            <v-file-input v-model="form.receipt" label="Receipt Photo" accept="image/*" prepend-icon="mdi-camera" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="saveExpense">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Image Preview Dialog -->
    <v-dialog v-model="previewDialog" max-width="600">
      <v-card class="rounded-lg">
        <v-img :src="previewImage" max-height="500" contain />
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="previewDialog = false">Close</v-btn>
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
const expenses = ref([])
const loading = ref(false)
const search = ref('')
const dialog = ref(false)
const saving = ref(false)
const formRef = ref(null)
const form = ref({ description: '', amount: 0, category: '', date: '', receipt: null })
const previewDialog = ref(false)
const previewImage = ref('')

const headers = [
  { title: 'Description', key: 'description' },
  { title: 'Amount', key: 'amount' },
  { title: 'Category', key: 'category' },
  { title: 'Status', key: 'status' },
  { title: 'Date', key: 'date' },
  { title: 'Receipt', key: 'receiptUrl', sortable: false, width: 60 },
]

function formatNumber(val) {
  return val != null ? Number(val).toLocaleString('en-PK') : '0'
}
function formatDate(d) {
  return d ? format(new Date(d), 'dd MMM yyyy') : 'N/A'
}
function statusColor(s) {
  return { approved: 'success', pending: 'warning', rejected: 'error' }[s] || 'grey'
}

function openDialog() {
  form.value = { description: '', amount: 0, category: '', date: '', receipt: null }
  dialog.value = true
}

async function saveExpense() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    const fd = new FormData()
    fd.append('description', form.value.description)
    fd.append('amount', form.value.amount)
    fd.append('category', form.value.category)
    fd.append('date', form.value.date)
    if (form.value.receipt) fd.append('receipt', form.value.receipt)
    await api.post('/expenses', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
    appStore.showSuccess('Expense added successfully')
    dialog.value = false
    await loadExpenses()
  } catch {
    appStore.showError('Failed to add expense')
  } finally {
    saving.value = false
  }
}

async function loadExpenses() {
  loading.value = true
  try {
    const { data } = await api.get('/expenses')
    expenses.value = data.data || data || []
  } catch {
    appStore.showError('Failed to load expenses')
  } finally {
    loading.value = false
  }
}

onMounted(loadExpenses)
</script>
