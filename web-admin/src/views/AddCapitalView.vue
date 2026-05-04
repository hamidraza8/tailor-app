<template>
  <div>
    <div class="d-flex align-center mb-6">
      <v-btn icon="mdi-arrow-left" variant="text" class="mr-2" to="/capital" />
      <h1 class="text-h5 font-weight-bold">Add Capital Contribution</h1>
    </div>

    <v-row justify="center">
      <v-col cols="12" md="6">
        <v-card class="rounded-lg pa-4">
          <v-card-text>
            <v-form ref="formRef" v-model="formValid" @submit.prevent="submit">
              <v-select
                v-model="form.partnerId"
                :items="partners"
                item-title="name"
                item-value="id"
                label="Partner *"
                :rules="[v => !!v || 'Partner is required']"
                :loading="loadingPartners"
                variant="outlined"
                class="mb-4"
              />

              <v-select
                v-model="form.transactionType"
                :items="transactionTypes"
                label="Transaction Type *"
                :rules="[v => !!v || 'Transaction type is required']"
                variant="outlined"
                class="mb-4"
              />

              <v-text-field
                v-model.number="form.amount"
                label="Amount (PKR) *"
                type="number"
                :rules="[
                  v => !!v || 'Amount is required',
                  v => v > 0 || 'Amount must be greater than 0',
                ]"
                variant="outlined"
                prefix="PKR"
                class="mb-4"
              />

              <v-text-field
                v-model="form.transactionDate"
                label="Transaction Date *"
                type="date"
                :rules="[v => !!v || 'Date is required']"
                variant="outlined"
                class="mb-4"
              />

              <v-textarea
                v-model="form.notes"
                label="Notes"
                variant="outlined"
                rows="3"
                class="mb-4"
              />

              <div class="d-flex gap-3 justify-end">
                <v-btn variant="tonal" to="/capital">Cancel</v-btn>
                <v-btn
                  color="primary"
                  type="submit"
                  :loading="submitting"
                  :disabled="!formValid"
                >
                  Submit
                </v-btn>
              </div>
            </v-form>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" timeout="3000">
      {{ snackbar.text }}
    </v-snackbar>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const router = useRouter()
const appStore = useAppStore()

const formRef = ref(null)
const formValid = ref(false)
const loadingPartners = ref(true)
const submitting = ref(false)
const partners = ref([])

const snackbar = ref({ show: false, text: '', color: 'success' })

const transactionTypes = ['CapitalAdvance', 'AdditionalCapital', 'Withdrawal', 'Adjustment']

const form = ref({
  partnerId: null,
  transactionType: null,
  amount: null,
  transactionDate: new Date().toISOString().split('T')[0],
  notes: '',
})

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return

  submitting.value = true
  try {
    await api.post(`/capital-transactions/partner/${form.value.partnerId}`, {
      transactionType: form.value.transactionType,
      amount: form.value.amount,
      transactionDate: form.value.transactionDate,
      notes: form.value.notes || null,
    })
    snackbar.value = { show: true, text: 'Capital contribution added successfully', color: 'success' }
    setTimeout(() => router.push('/capital'), 1200)
  } catch {
    appStore.showError('Failed to add capital contribution')
  } finally {
    submitting.value = false
  }
}

onMounted(async () => {
  try {
    const { data } = await api.get('/partners')
    partners.value = data
  } catch {
    appStore.showError('Failed to load partners')
  } finally {
    loadingPartners.value = false
  }
})
</script>
