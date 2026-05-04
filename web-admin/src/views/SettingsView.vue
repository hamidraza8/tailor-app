<template>
  <div>
    <h1 class="text-h5 font-weight-bold mb-6">Settings</h1>

    <v-card class="rounded-lg" max-width="800">
      <v-card-title class="text-subtitle-1 font-weight-bold pa-4 pb-0">
        <v-icon class="mr-2" color="primary">mdi-store</v-icon>
        Business Profile
      </v-card-title>
      <v-card-text class="pa-4">
        <v-form ref="formRef">
          <v-text-field
            v-model="form.businessName"
            label="Business Name"
            :rules="[v => !!v || 'Required']"
          />
          <v-text-field v-model="form.tagline" label="Tagline / Slogan" />
          <v-text-field
            v-model="form.phone"
            label="Phone Number"
            :rules="[v => !!v || 'Required']"
          />
          <v-text-field v-model="form.email" label="Email" />
          <v-textarea v-model="form.address" label="Address" rows="2" />
          <v-text-field v-model="form.city" label="City" />
          <v-text-field v-model="form.ntn" label="NTN (Tax Number)" />

          <v-divider class="my-4" />
          <h3 class="text-subtitle-2 font-weight-bold mb-3">Invoice Settings</h3>

          <v-text-field v-model="form.invoicePrefix" label="Invoice Number Prefix" placeholder="INV-" />
          <v-textarea v-model="form.invoiceFooter" label="Invoice Footer Text" rows="2" />
          <v-textarea v-model="form.termsAndConditions" label="Terms & Conditions" rows="3" />
        </v-form>
      </v-card-text>
      <v-card-actions class="pa-4 pt-0">
        <v-spacer />
        <v-btn color="primary" variant="flat" size="large" :loading="saving" @click="saveProfile">
          <v-icon start>mdi-content-save</v-icon> Save Changes
        </v-btn>
      </v-card-actions>
    </v-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const formRef = ref(null)
const saving = ref(false)
const form = ref({
  businessName: '',
  tagline: '',
  phone: '',
  email: '',
  address: '',
  city: '',
  ntn: '',
  invoicePrefix: '',
  invoiceFooter: '',
  termsAndConditions: '',
})

async function saveProfile() {
  const { valid } = await formRef.value.validate()
  if (!valid) return
  saving.value = true
  try {
    await api.put('/settings/business-profile', form.value)
    appStore.showSuccess('Business profile updated successfully')
  } catch {
    appStore.showError('Failed to update business profile')
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  try {
    const { data } = await api.get('/settings/business-profile')
    const profile = data.data || data || {}
    Object.keys(form.value).forEach(key => {
      if (profile[key] != null) form.value[key] = profile[key]
    })
  } catch {
    appStore.showError('Failed to load business profile')
  }
})
</script>
