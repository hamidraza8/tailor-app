<template>
  <div>
    <div class="d-flex align-center mb-6">
      <h1 class="text-h5 font-weight-bold">Assets</h1>
      <v-spacer />
      <v-btn color="primary" @click="openDialog()">
        <v-icon start>mdi-plus</v-icon> Add Asset
      </v-btn>
    </div>

    <v-row>
      <v-col v-for="asset in assets" :key="asset._id" cols="12" sm="6" md="4" lg="3">
        <v-card class="rounded-lg">
          <v-img
            :src="asset.photoUrl || ''"
            height="180"
            cover
            class="bg-grey-lighten-3"
          >
            <template #placeholder>
              <v-row class="fill-height ma-0" align="center" justify="center">
                <v-icon size="48" color="grey">mdi-image</v-icon>
              </v-row>
            </template>
            <v-chip
              :color="statusColor(asset.approvalStatus)"
              size="small"
              class="ma-2"
              variant="flat"
            >
              {{ asset.approvalStatus }}
            </v-chip>
          </v-img>
          <v-card-title class="text-subtitle-1">{{ asset.name }}</v-card-title>
          <v-card-subtitle>{{ asset.category }}</v-card-subtitle>
          <v-card-text class="text-body-2">
            <div class="d-flex justify-space-between mb-1">
              <span>Purchase Price</span>
              <strong>Rs {{ formatNumber(asset.purchasePrice) }}</strong>
            </div>
            <div class="d-flex justify-space-between mb-1">
              <span>Current Value</span>
              <strong>Rs {{ formatNumber(asset.currentValue) }}</strong>
            </div>
            <div class="d-flex justify-space-between">
              <span>Purchased</span>
              <span>{{ formatDate(asset.purchaseDate) }}</span>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-card v-if="assets.length === 0 && !loading" class="pa-8 text-center rounded-lg">
      <v-icon size="64" color="grey">mdi-package-variant</v-icon>
      <div class="text-h6 mt-3 text-medium-emphasis">No assets found</div>
    </v-card>

    <!-- Add Asset Dialog -->
    <v-dialog v-model="dialog" max-width="600">
      <v-card class="rounded-lg">
        <v-card-title class="text-h6 pa-4">Add New Asset</v-card-title>
        <v-card-text>
          <v-form ref="formRef">
            <v-text-field v-model="form.name" label="Asset Name" :rules="[v => !!v || 'Required']" />
            <v-select
              v-model="form.category"
              label="Category"
              :items="['Machinery', 'Furniture', 'Electronics', 'Vehicle', 'Other']"
              :rules="[v => !!v || 'Required']"
            />
            <v-text-field v-model.number="form.purchasePrice" label="Purchase Price (Rs)" type="number" :rules="[v => v > 0 || 'Required']" />
            <v-text-field v-model="form.purchaseDate" label="Purchase Date" type="date" :rules="[v => !!v || 'Required']" />
            <v-textarea v-model="form.description" label="Description" rows="2" />
            <v-file-input v-model="form.photo" label="Photo" accept="image/*" prepend-icon="mdi-camera" />
          </v-form>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="dialog = false">Cancel</v-btn>
          <v-btn color="primary" variant="flat" :loading="saving" @click="saveAsset">Save</v-btn>
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
const assets = ref([])
const loading = ref(false)
const dialog = ref(false)
const saving = ref(false)
const formRef = ref(null)
const form = ref({ name: '', category: '', purchasePrice: 0, purchaseDate: '', description: '', photo: null })

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
  form.value = { name: '', category: '', purchasePrice: 0, purchaseDate: '', description: '', photo: null }
  dialog.value = true
}

async function saveAsset() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    const fd = new FormData()
    fd.append('name', form.value.name)
    fd.append('category', form.value.category)
    fd.append('purchasePrice', form.value.purchasePrice)
    fd.append('purchaseDate', form.value.purchaseDate)
    fd.append('description', form.value.description)
    if (form.value.photo) fd.append('photo', form.value.photo)
    await api.post('/assets', fd, { headers: { 'Content-Type': 'multipart/form-data' } })
    appStore.showSuccess('Asset added successfully')
    dialog.value = false
    await loadAssets()
  } catch {
    appStore.showError('Failed to add asset')
  } finally {
    saving.value = false
  }
}

async function loadAssets() {
  loading.value = true
  try {
    const { data } = await api.get('/assets')
    assets.value = data.data || data || []
  } catch {
    appStore.showError('Failed to load assets')
  } finally {
    loading.value = false
  }
}

onMounted(loadAssets)
</script>
