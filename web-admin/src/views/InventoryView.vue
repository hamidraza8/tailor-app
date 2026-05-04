<template>
  <div>
    <div class="d-flex align-center mb-6">
      <h1 class="text-h5 font-weight-bold">Inventory</h1>
      <v-spacer />
      <v-text-field
        v-model="search"
        prepend-inner-icon="mdi-magnify"
        label="Search inventory..."
        single-line
        hide-details
        density="compact"
        style="max-width: 300px"
        class="mr-3"
      />
    </div>

    <v-card class="rounded-lg">
      <v-data-table
        :headers="headers"
        :items="items"
        :search="search"
        :loading="loading"
        items-per-page="15"
        class="elevation-0"
      >
        <template #item.photoUrl="{ item }">
          <v-avatar size="40" rounded class="my-1">
            <v-img v-if="item.photoUrl" :src="item.photoUrl" />
            <v-icon v-else color="grey">mdi-image</v-icon>
          </v-avatar>
        </template>
        <template #item.currentStock="{ item }">
          <v-chip
            :color="item.currentStock <= (item.reorderLevel || 5) ? 'error' : 'success'"
            size="small"
            variant="flat"
          >
            {{ item.currentStock }} {{ item.unit }}
          </v-chip>
        </template>
        <template #item.unitCost="{ item }">
          Rs {{ formatNumber(item.unitCost) }}
        </template>
        <template #item.totalValue="{ item }">
          Rs {{ formatNumber((item.currentStock || 0) * (item.unitCost || 0)) }}
        </template>
      </v-data-table>
    </v-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const items = ref([])
const loading = ref(false)
const search = ref('')

const headers = [
  { title: 'Photo', key: 'photoUrl', sortable: false, width: 60 },
  { title: 'Item Name', key: 'name' },
  { title: 'Category', key: 'category' },
  { title: 'Stock', key: 'currentStock' },
  { title: 'Unit Cost', key: 'unitCost' },
  { title: 'Total Value', key: 'totalValue', sortable: false },
]

function formatNumber(val) {
  return val != null ? Number(val).toLocaleString('en-PK') : '0'
}

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await api.get('/inventory/items')
    items.value = data.data || data || []
  } catch {
    appStore.showError('Failed to load inventory')
  } finally {
    loading.value = false
  }
})
</script>
