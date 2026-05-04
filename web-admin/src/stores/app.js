import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useAppStore = defineStore('app', () => {
  const sidebarOpen = ref(true)
  const loading = ref(false)
  const snackbar = ref({ show: false, text: '', color: 'success' })

  function toggleSidebar() {
    sidebarOpen.value = !sidebarOpen.value
  }

  function showSnackbar(text, color = 'success') {
    snackbar.value = { show: true, text, color }
  }

  function showError(text) {
    showSnackbar(text, 'error')
  }

  function showSuccess(text) {
    showSnackbar(text, 'success')
  }

  return { sidebarOpen, loading, snackbar, toggleSidebar, showSnackbar, showError, showSuccess }
})
