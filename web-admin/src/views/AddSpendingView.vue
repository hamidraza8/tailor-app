<template>
  <div>
    <div class="d-flex align-center mb-6">
      <v-btn icon="mdi-arrow-left" variant="text" class="mr-2" to="/spendings" />
      <h1 class="text-h5 font-weight-bold">New Spending</h1>
    </div>

    <v-stepper v-model="step" :items="stepTitles" alt-labels>
      <!-- Step 1: Spending Type -->
      <template #item.1>
        <v-card flat>
          <v-card-text>
            <div class="text-subtitle-1 font-weight-medium mb-4">Select Spending Category</div>
            <v-row>
              <v-col
                v-for="cat in categories"
                :key="cat.value"
                cols="6"
                sm="4"
                md="3"
              >
                <v-card
                  class="rounded-lg cursor-pointer"
                  :class="form.category === cat.value ? 'border-primary bg-primary-lighten' : ''"
                  :variant="form.category === cat.value ? 'tonal' : 'outlined'"
                  :color="form.category === cat.value ? 'primary' : undefined"
                  @click="form.category = cat.value"
                >
                  <v-card-text class="d-flex flex-column align-center pa-4">
                    <v-icon :icon="cat.icon" size="36" class="mb-2" :color="form.category === cat.value ? 'primary' : 'medium-emphasis'" />
                    <div class="text-body-2 text-center">{{ cat.label }}</div>
                  </v-card-text>
                </v-card>
              </v-col>
            </v-row>
            <v-alert v-if="step1Error" type="error" variant="tonal" density="compact" class="mt-4">
              Please select a spending category.
            </v-alert>
          </v-card-text>
          <v-card-actions class="pa-4 justify-end">
            <v-btn color="primary" @click="nextStep(1)">Continue</v-btn>
          </v-card-actions>
        </v-card>
      </template>

      <!-- Step 2: Spending Details -->
      <template #item.2>
        <v-card flat>
          <v-card-text>
            <v-form ref="step2FormRef" v-model="step2Valid">
              <v-text-field
                v-model="form.description"
                label="Description *"
                variant="outlined"
                :rules="[v => !!v || 'Description is required']"
                class="mb-4"
              />
              <v-text-field
                v-model.number="form.totalAmount"
                label="Total Amount (PKR) *"
                type="number"
                variant="outlined"
                prefix="PKR"
                :rules="[v => !!v || 'Amount is required', v => v > 0 || 'Must be > 0']"
                class="mb-4"
              />
              <v-text-field
                v-model="form.spendingDate"
                label="Spending Date *"
                type="date"
                variant="outlined"
                :rules="[v => !!v || 'Date is required']"
                class="mb-4"
              />
              <v-textarea
                v-model="form.notes"
                label="Notes"
                variant="outlined"
                rows="3"
                class="mb-4"
              />
              <v-text-field
                v-model="form.receiptFileUrl"
                label="Receipt File URL (optional)"
                variant="outlined"
                class="mb-4"
              />
            </v-form>
          </v-card-text>
          <v-card-actions class="pa-4 justify-space-between">
            <v-btn variant="tonal" @click="step--">Back</v-btn>
            <v-btn color="primary" @click="nextStep(2)">Continue</v-btn>
          </v-card-actions>
        </v-card>
      </template>

      <!-- Step 3: Funding Split -->
      <template #item.3>
        <v-card flat>
          <v-card-text>
            <div class="text-subtitle-1 font-weight-medium mb-1">Funding Split</div>
            <div class="text-caption text-medium-emphasis mb-4">
              Allocate the total amount of {{ formatPKR(form.totalAmount) }} across partners.
            </div>

            <v-table>
              <thead>
                <tr>
                  <th>Partner</th>
                  <th>Current Balance</th>
                  <th>Amount (PKR)</th>
                  <th>Balance After</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="partner in partners" :key="partner.id">
                  <td>{{ partner.name }}</td>
                  <td>{{ formatPKR(partnerBalance(partner.id)) }}</td>
                  <td>
                    <v-text-field
                      v-model.number="fundingSplits[partner.id]"
                      type="number"
                      variant="outlined"
                      density="compact"
                      hide-details
                      style="min-width: 130px"
                      :min="0"
                    />
                  </td>
                  <td :class="balanceAfter(partner.id) < 0 ? 'text-error font-weight-bold' : 'text-success'">
                    {{ formatPKR(balanceAfter(partner.id)) }}
                    <v-icon v-if="balanceAfter(partner.id) < 0" color="error" size="16">mdi-alert</v-icon>
                  </td>
                </tr>
              </tbody>
            </v-table>

            <div class="mt-4 d-flex align-center gap-3">
              <v-chip
                :color="splitTotalColor"
                variant="tonal"
                size="small"
              >
                Split Total: {{ formatPKR(splitTotal) }} / Required: {{ formatPKR(form.totalAmount) }}
              </v-chip>
              <span v-if="splitTotal !== form.totalAmount" class="text-caption text-error">
                Difference: {{ formatPKR(Math.abs(splitTotal - (form.totalAmount || 0))) }}
              </span>
            </div>

            <v-alert v-if="hasNegativeBalances" type="warning" variant="tonal" density="compact" class="mt-3">
              One or more partners would have a negative balance after this spending.
            </v-alert>
            <v-alert v-if="step3Error" type="error" variant="tonal" density="compact" class="mt-3">
              Split total must equal the spending amount.
            </v-alert>
          </v-card-text>
          <v-card-actions class="pa-4 justify-space-between">
            <v-btn variant="tonal" @click="step--">Back</v-btn>
            <v-btn color="primary" @click="nextStep(3)">Continue</v-btn>
          </v-card-actions>
        </v-card>
      </template>

      <!-- Step 4: Result Details -->
      <template #item.4>
        <v-card flat>
          <v-card-text>
            <div class="text-subtitle-1 font-weight-medium mb-4">Result Details</div>

            <!-- Asset -->
            <template v-if="resultType === 'Asset'">
              <v-text-field v-model="assetDetail.name" label="Asset Name *" variant="outlined" class="mb-4" />
              <v-text-field v-model="assetDetail.assetType" label="Asset Type" variant="outlined" class="mb-4" />
              <v-row>
                <v-col cols="6">
                  <v-text-field v-model.number="assetDetail.quantity" label="Quantity" type="number" variant="outlined" />
                </v-col>
                <v-col cols="6">
                  <v-text-field v-model.number="assetDetail.unitValue" label="Unit Value (PKR)" type="number" variant="outlined" prefix="PKR" />
                </v-col>
              </v-row>
              <div class="text-body-2 font-weight-medium mb-2 mt-2">Ownership Type</div>
              <v-radio-group v-model="assetDetail.ownershipType" inline class="mb-4">
                <v-radio label="Partner Owned" value="PartnerOwned" />
                <v-radio label="Company Owned" value="CompanyOwned" />
                <v-radio label="Split Owned" value="SplitOwned" />
              </v-radio-group>
              <template v-if="assetDetail.ownershipType === 'SplitOwned'">
                <div class="text-body-2 font-weight-medium mb-2">Ownership Split (per partner)</div>
                <v-table density="compact">
                  <thead>
                    <tr>
                      <th>Partner</th>
                      <th>Ownership %</th>
                      <th>Value</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="partner in partners" :key="partner.id">
                      <td>{{ partner.name }}</td>
                      <td>
                        <v-text-field
                          v-model.number="ownershipSplits[partner.id]"
                          type="number"
                          variant="outlined"
                          density="compact"
                          hide-details
                          suffix="%"
                          style="min-width: 100px"
                          :min="0"
                          :max="100"
                        />
                      </td>
                      <td class="text-caption">
                        {{ formatPKR(((ownershipSplits[partner.id] || 0) / 100) * (assetDetail.unitValue * assetDetail.quantity || 0)) }}
                      </td>
                    </tr>
                  </tbody>
                </v-table>
              </template>
            </template>

            <!-- Inventory -->
            <template v-else-if="resultType === 'Inventory'">
              <div class="d-flex align-center justify-space-between mb-3">
                <div class="text-body-2 font-weight-medium">Inventory Items</div>
                <v-btn size="small" variant="tonal" color="primary" prepend-icon="mdi-plus" @click="addInventoryLine">
                  Add Item
                </v-btn>
              </div>
              <v-card v-for="(item, idx) in inventoryLines" :key="idx" variant="outlined" class="mb-3 pa-3 rounded">
                <v-row dense>
                  <v-col cols="12" sm="4">
                    <v-select
                      v-model="item.itemId"
                      :items="inventoryItems"
                      item-title="name"
                      item-value="id"
                      label="Item"
                      variant="outlined"
                      density="compact"
                      hide-details
                    />
                  </v-col>
                  <v-col cols="6" sm="2">
                    <v-text-field v-model.number="item.quantity" label="Qty" type="number" variant="outlined" density="compact" hide-details />
                  </v-col>
                  <v-col cols="6" sm="2">
                    <v-text-field v-model.number="item.unitCost" label="Unit Cost" type="number" variant="outlined" density="compact" hide-details prefix="PKR" />
                  </v-col>
                  <v-col cols="10" sm="3">
                    <v-text-field v-model="item.supplierName" label="Supplier" variant="outlined" density="compact" hide-details />
                  </v-col>
                  <v-col cols="2" sm="1" class="d-flex align-center justify-center">
                    <v-btn icon="mdi-delete" size="x-small" variant="text" color="error" @click="removeInventoryLine(idx)" />
                  </v-col>
                </v-row>
              </v-card>
            </template>

            <!-- Expense -->
            <template v-else>
              <v-alert type="info" variant="tonal" density="compact" class="mb-4">
                Category: <strong>{{ form.category }}</strong> — No additional details needed.
              </v-alert>
              <v-textarea v-model="expenseNotes" label="Additional Notes" variant="outlined" rows="3" />
            </template>
          </v-card-text>
          <v-card-actions class="pa-4 justify-space-between">
            <v-btn variant="tonal" @click="step--">Back</v-btn>
            <v-btn color="primary" @click="nextStep(4)">Continue</v-btn>
          </v-card-actions>
        </v-card>
      </template>

      <!-- Step 5: Review & Submit -->
      <template #item.5>
        <v-card flat>
          <v-card-text>
            <div class="text-subtitle-1 font-weight-medium mb-4">Review & Confirm</div>

            <v-row class="mb-4">
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis">Category</div>
                <div class="text-body-2 font-weight-medium">{{ form.category }}</div>
              </v-col>
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis">Total Amount</div>
                <div class="text-body-1 font-weight-bold">{{ formatPKR(form.totalAmount) }}</div>
              </v-col>
              <v-col cols="6" sm="4">
                <div class="text-caption text-medium-emphasis">Date</div>
                <div class="text-body-2">{{ form.spendingDate }}</div>
              </v-col>
              <v-col cols="12">
                <div class="text-caption text-medium-emphasis">Description</div>
                <div class="text-body-2">{{ form.description }}</div>
              </v-col>
            </v-row>

            <div class="text-subtitle-2 font-weight-bold mb-2">Balance Impact</div>
            <v-table density="compact" class="mb-4">
              <thead>
                <tr>
                  <th>Partner</th>
                  <th>Balance Before</th>
                  <th>Funded</th>
                  <th>Balance After</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="partner in partners" :key="partner.id">
                  <td>{{ partner.name }}</td>
                  <td>{{ formatPKR(partnerBalance(partner.id)) }}</td>
                  <td>{{ formatPKR(fundingSplits[partner.id] || 0) }}</td>
                  <td>
                    <span :class="balanceAfter(partner.id) < 0 ? 'text-error font-weight-bold' : 'text-success'">
                      {{ formatPKR(balanceAfter(partner.id)) }}
                    </span>
                    <v-icon v-if="balanceAfter(partner.id) < 0" color="error" size="14" class="ml-1">mdi-alert</v-icon>
                  </td>
                </tr>
              </tbody>
            </v-table>

            <v-alert v-if="hasNegativeBalances" type="warning" variant="tonal" density="compact" class="mb-4">
              Warning: one or more partners will have a negative balance after this spending.
            </v-alert>
          </v-card-text>
          <v-card-actions class="pa-4 justify-space-between">
            <v-btn variant="tonal" @click="step--">Back</v-btn>
            <v-btn color="primary" :loading="submitting" @click="submit">Submit Spending</v-btn>
          </v-card-actions>
        </v-card>
      </template>
    </v-stepper>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import api from '@/services/api'
import { useAppStore } from '@/stores/app'

const router = useRouter()
const appStore = useAppStore()

const step = ref(1)
const stepTitles = ['Spending Type', 'Details', 'Funding Split', 'Result Details', 'Review']

const step2FormRef = ref(null)
const step2Valid = ref(false)
const step1Error = ref(false)
const step3Error = ref(false)

const partners = ref([])
const partnerBalances = ref({})
const inventoryItems = ref([])
const submitting = ref(false)

const fundingSplits = ref({})
const ownershipSplits = ref({})
const inventoryLines = ref([])
const assetDetail = ref({ name: '', assetType: '', quantity: 1, unitValue: 0, ownershipType: 'CompanyOwned' })
const expenseNotes = ref('')

const form = ref({
  category: null,
  description: '',
  totalAmount: null,
  spendingDate: new Date().toISOString().split('T')[0],
  notes: '',
  receiptFileUrl: '',
})

const categories = [
  { value: 'AssetPurchase', label: 'Asset Purchase', icon: 'mdi-package-variant' },
  { value: 'InventoryPurchase', label: 'Inventory', icon: 'mdi-warehouse' },
  { value: 'Rent', label: 'Rent', icon: 'mdi-home-city' },
  { value: 'Utility', label: 'Utility', icon: 'mdi-lightning-bolt' },
  { value: 'Salary', label: 'Salary', icon: 'mdi-account-cash' },
  { value: 'Labour', label: 'Labour', icon: 'mdi-account-hard-hat' },
  { value: 'Marketing', label: 'Marketing', icon: 'mdi-bullhorn' },
  { value: 'Misc', label: 'Misc', icon: 'mdi-dots-horizontal' },
]

const resultType = computed(() => {
  if (form.value.category === 'AssetPurchase') return 'Asset'
  if (form.value.category === 'InventoryPurchase') return 'Inventory'
  return 'Expense'
})

const splitTotal = computed(() => {
  return Object.values(fundingSplits.value).reduce((sum, v) => sum + (Number(v) || 0), 0)
})

const splitTotalColor = computed(() => {
  return splitTotal.value === (form.value.totalAmount || 0) ? 'success' : 'error'
})

const hasNegativeBalances = computed(() => {
  return partners.value.some((p) => balanceAfter(p.id) < 0)
})

function partnerBalance(partnerId) {
  return partnerBalances.value[partnerId] ?? 0
}

function balanceAfter(partnerId) {
  return partnerBalance(partnerId) - (Number(fundingSplits.value[partnerId]) || 0)
}

function formatPKR(amount) {
  if (amount == null) return 'PKR 0'
  return new Intl.NumberFormat('en-PK', { style: 'currency', currency: 'PKR' }).format(amount)
}

function addInventoryLine() {
  inventoryLines.value.push({ itemId: null, quantity: 1, unitCost: 0, supplierName: '' })
}

function removeInventoryLine(idx) {
  inventoryLines.value.splice(idx, 1)
}

async function nextStep(current) {
  if (current === 1) {
    if (!form.value.category) { step1Error.value = true; return }
    step1Error.value = false
  }
  if (current === 2) {
    const { valid } = await step2FormRef.value.validate()
    if (!valid) return
  }
  if (current === 3) {
    if (Math.abs(splitTotal.value - (form.value.totalAmount || 0)) > 0.01) {
      step3Error.value = true
      return
    }
    step3Error.value = false
  }
  step.value++
}

async function submit() {
  submitting.value = true
  try {
    const splits = partners.value
      .filter((p) => fundingSplits.value[p.id] > 0)
      .map((p) => ({ partnerId: p.id, amount: Number(fundingSplits.value[p.id]) }))

    const payload = {
      category: form.value.category,
      description: form.value.description,
      totalAmount: form.value.totalAmount,
      spendingDate: form.value.spendingDate,
      notes: form.value.notes || null,
      receiptFileUrl: form.value.receiptFileUrl || null,
      resultType: resultType.value,
      fundingSplits: splits,
    }

    if (resultType.value === 'Asset') {
      payload.assetDetail = { ...assetDetail.value }
      if (assetDetail.value.ownershipType === 'SplitOwned') {
        payload.assetDetail.ownershipSplits = partners.value.map((p) => ({
          partnerId: p.id,
          percentage: Number(ownershipSplits.value[p.id] || 0),
        }))
      }
    } else if (resultType.value === 'Inventory') {
      payload.inventoryLines = inventoryLines.value
    } else {
      payload.expenseNotes = expenseNotes.value || null
    }

    await api.post('/spendings', payload)
    appStore.showSuccess('Spending created successfully')
    router.push('/spendings')
  } catch {
    appStore.showError('Failed to create spending')
  } finally {
    submitting.value = false
  }
}

onMounted(async () => {
  try {
    const [partnersRes, balancesRes, invRes] = await Promise.all([
      api.get('/partners'),
      api.get('/reports/partner-balances'),
      api.get('/inventory/items').catch(() => ({ data: [] })),
    ])
    partners.value = partnersRes.data
    const summary = balancesRes.data
    if (summary.partnerBalances) {
      summary.partnerBalances.forEach((pb) => {
        partnerBalances.value[pb.partnerId] = pb.remainingBalance
        fundingSplits.value[pb.partnerId] = 0
        ownershipSplits.value[pb.partnerId] = 0
      })
    }
    inventoryItems.value = invRes.data
  } catch {
    appStore.showError('Failed to load required data')
  }
})
</script>
