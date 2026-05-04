<template>
  <v-container class="fill-height" fluid>
    <v-row align="center" justify="center">
      <v-col cols="12" sm="8" md="4">
        <v-card class="pa-6 rounded-xl" elevation="8">
          <v-card-text class="text-center mb-4">
            <v-icon size="64" color="primary" class="mb-3">mdi-scissors-cutting</v-icon>
            <h1 class="text-h5 font-weight-bold text-primary">Tailor Admin</h1>
            <p class="text-body-2 text-medium-emphasis mt-1">Sign in to manage your business</p>
          </v-card-text>

          <v-form @submit.prevent="handleLogin" ref="formRef">
            <v-text-field
              v-model="email"
              label="Email"
              type="email"
              prepend-inner-icon="mdi-email"
              :rules="[v => !!v || 'Email is required', v => /.+@.+/.test(v) || 'Enter a valid email']"
              class="mb-2"
            />
            <v-text-field
              v-model="password"
              label="Password"
              :type="showPassword ? 'text' : 'password'"
              prepend-inner-icon="mdi-lock"
              :append-inner-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
              @click:append-inner="showPassword = !showPassword"
              :rules="[v => !!v || 'Password is required']"
              class="mb-2"
            />
            <v-alert v-if="errorMsg" type="error" variant="tonal" density="compact" class="mb-4">
              {{ errorMsg }}
            </v-alert>
            <v-btn
              type="submit"
              color="primary"
              block
              size="large"
              :loading="loading"
            >
              Sign In
            </v-btn>
          </v-form>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()
const formRef = ref(null)
const email = ref('')
const password = ref('')
const showPassword = ref(false)
const loading = ref(false)
const errorMsg = ref('')

async function handleLogin() {
  const { valid } = await formRef.value.validate()
  if (!valid) return

  loading.value = true
  errorMsg.value = ''
  try {
    await authStore.login(email.value, password.value)
  } catch (err) {
    errorMsg.value = err.response?.data?.message || 'Login failed. Please check your credentials.'
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.fill-height {
  min-height: 100vh;
  background: linear-gradient(135deg, #1A3A5C 0%, #00897B 100%);
}
</style>
