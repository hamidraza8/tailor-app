<template>
  <div>
    <div class="d-flex align-center mb-6">
      <h1 class="text-h5 font-weight-bold">Customers</h1>
      <v-spacer />
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        label="Search customers..."
        single-line
        hide-details
        density="compact"
        style="max-width: 300px"
        class="mr-3"
      />
      <v-btn color="primary" @click="openDialog()">
        <v-icon start>mdi-plus</v-icon> Add Customer
      </v-btn>
    </div>

    <v-card class="rounded-lg">
      <v-data-table
        :headers="headers"
        :items="customers"
        :search="search"
        :loading="loading"
        items-per-page="15"
      >
        <template #item.phone="{ item }">
          <a :href="'tel:' + item.phone" class="text-decoration-none">{{ item.phone }}</a>
        </template>
        <template #item.totalOrders="{ item }">
          <v-chip size="small" color="primary" variant="tonal">{{ item.totalOrders || 0 }}</v-chip>
        </template>
        <template #item.createdAt="{ item }">
          {{ formatDate(item.createdAt) }}
        </template>
      </v-data-table>
    </v-card>

    <!-- Add Customer Dialog -->
    <v-dialog v-model="dialog" max-width="500">
      <v-card class="rounded-lg">
        <v-card-title class="text-h6 pa-4">Add New Customer</v-card-title>
        <v-card-text>
          <v-form ref="formRef">
            <v-text-field v-model="form.name" label="Full Name" :rules="[v => !!v || 'Required']" />
            <v-text-field v-model="form.phone" label="Phone Number" :rules="[v => !!v || 'Required']" />
            <v-text-field v-model="form.email" label="Email (optional)" />
            <v-textarea v-model="form.address" label="Address" rows="2" />
            <v-textarea v-model="form.notes" label="Notes" rows="2" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="saveCustomer">Save</v-btn>
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
const customers = ref([])
const loading = ref(false)
const search = ref('')
const dialog = ref(false)
const saving = ref(false)
const formRef = ref(null)
const form = ref({ name: '', phone: '', email: '', address: '', notes: '' })

const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Phone', key: 'phone' },
  { title: 'Email', key: 'email' },
  { title: 'Address', key: 'address' },
  { title: 'Orders', key: 'totalOrders' },
  { title: 'Joined', key: 'createdAt' },
]

function formatDate(d) {
  return d ? format(new Date(d), 'dd MMM yyyy') : 'N/A'
}

function openDialog() {
  form.value = { name: '', phone: '', email: '', address: '', notes: '' }
  dialog.value = true
}

async function saveCustomer() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    await api.post('/customers', form.value)
    appStore.showSuccess('Customer added successfully')
    dialog.value = false
    await loadCustomers()
  } catch {
    appStore.showError('Failed to add customer')
  } finally {
    saving.value = false
  }
}

async function loadCustomers() {
  loading.value = true
  try {
    const { data } = await api.get('/customers')
    customers.value = data.data || data || []
  } catch {
    appStore.showError('Failed to load customers')
  } finally {
    loading.value = false
  }
}

onMounted(loadCustomers)
</script>
