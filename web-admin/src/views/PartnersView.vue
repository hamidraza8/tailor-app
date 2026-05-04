<template>
  <div>
    <h1 class="text-h5 font-weight-bold mb-6">Partners & Ownership</h1>

    <v-row>
      <v-col v-for="partner in partners" :key="partner._id" cols="12" md="6" lg="4">
        <v-card class="rounded-lg">
          <v-card-text class="text-center pa-6">
            <v-avatar size="80" color="primary" class="mb-3">
              <v-icon size="40" color="white">mdi-account</v-icon>
            </v-avatar>
            <h3 class="text-h6">{{ partner.name }}</h3>
            <p class="text-medium-emphasis">{{ partner.email }}</p>
            <v-chip color="secondary" class="mt-2" size="large">
              {{ partner.ownershipPercentage }}% Ownership
            </v-chip>
            <div class="mt-3">
              <v-chip :color="partner.role === 'admin' ? 'primary' : 'info'" size="small" variant="flat">
                {{ partner.role }}
              </v-chip>
            </div>
          </v-card-text>
          <v-divider />
          <v-card-text>
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span class="text-medium-emphasis">Investment</span>
              <span class="font-weight-medium">Rs {{ formatNumber(partner.investmentAmount) }}</span>
            </div>
            <div class="d-flex justify-space-between text-body-2 mb-1">
              <span class="text-medium-emphasis">Profit Share</span>
              <span class="font-weight-medium">{{ partner.ownershipPercentage }}%</span>
            </div>
            <div class="d-flex justify-space-between text-body-2">
              <span class="text-medium-emphasis">Joined</span>
              <span class="font-weight-medium">{{ formatDate(partner.createdAt) }}</span>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-card v-if="partners.length === 0 && !loading" class="pa-8 text-center rounded-lg">
      <v-icon size="64" color="grey">mdi-account-group</v-icon>
      <div class="text-h6 mt-3 text-medium-emphasis">No partners found</div>
    </v-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'
import { format } from 'date-fns'

const appStore = useAppStore()
const partners = ref([])
const loading = ref(false)

function formatNumber(val) {
  if (val == null) return '0'
  return Number(val).toLocaleString('en-PK')
}

function formatDate(d) {
  if (!d) return 'N/A'
  return format(new Date(d), 'dd MMM yyyy')
}

onMounted(async () => {
  loading.value = true
  try {
    const { data } = await api.get('/partners')
    partners.value = data.data || data || []
  } catch {
    appStore.showError('Failed to load partners')
  } finally {
    loading.value = false
  }
})
</script>
